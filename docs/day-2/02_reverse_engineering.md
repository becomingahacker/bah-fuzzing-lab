---
title: "Part 2: Reverse-Engineering the API"
parent: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 2
---

# Part 2: Reverse-Engineering the API

We need to understand our two target functions well enough to be able to call them. We'll start with `QDecode` because it's smaller and
will be quicker to understand.

## Tools

We'll use radare2.  I don't like it most of the time because of the wacky syntax, but it is great for one-liners for guides like these.
You are encouraged to use Ghidra/IDA Pro instead if you're more comfortable in there.  Just pull the binaries from the lab with SCP.

## Aside: The i386 cdecl calling convention

> Since we're targeting a 32-bit x86 binary, I'll refresh your memory on how calls work in that architecture.

Arguments are pushed onto the stack before a `call`. After the prologue
(`push ebp; mov ebp, esp`), the stack layout at the beginning of the function is:

```
ebp+0x10 │  3rd argument    │
ebp+0x0c │  2nd argument    │
ebp+0x08 │  1st argument    │
ebp+0x04 │  return address  │
ebp+0x00 │  saved ebp       │
```

`[ebp+0x08]` = first arg, `[ebp+0x0c]` = second, and so on. The return value goes in `eax` before the function returns.

## Target function: Qdecode ([quoted-printable](https://dencode.com/en/string/quoted-printable) decoder)

```bash
$ r2 -a x86 -b 32 -qc 'aaa; s sym.Qdecode; pdf' $ROOT/bin/mailscanner
```

The function signature from r2's analysis, `sym.Qdecode (int32_t arg_8h, int32_t arg_ch)`, shows two arguments.

### Prologue and allocation

```asm
0x080f8acc      push ebp
0x080f8acd      mov ebp, esp
...
0x080f8ae0      mov eax, dword [arg_ch]      ; eax = arg2 (length)
0x080f8ae3      mov esi, dword [arg_8h]      ; esi = arg1 (input string)
0x080f8ae6      mov dword [size], eax        ; size = length
...
0x080f8af4      mov eax, dword [size]
0x080f8af7      inc eax                      ; size + 1
0x080f8af8      push eax
0x080f8af9      call malloc                  ; output = malloc(length + 1)
0x080f8b01      mov dword [var_40h], eax     ; var_40h = output buffer
0x080f8b04      mov dword [var_30h], 0       ; var_30h = write_offset = 0
```

`Qdecode(char *input, int length)` returns a `malloc`'d buffer, likely to be used as an output buffer.
For this buffer it allocates `length + 1` bytes. `var_30h` tracks how many bytes have been written, so
I refer to it as `write_offset`.

This might be just enough information to write an initial fuzzer to test it out.
First though, since we're in the mindset of doing reversing work, let's take a look at the next target function.


## Target function: mime_content_type_new_from_string

This is a more difficult function to understand than the last one.
It presumably parses [Content-Type](https://datatracker.ietf.org/doc/html/rfc2045#section-5.1) headers like:

```
text/html; charset=utf-8; boundary="----=_Part_123"; name="file.txt"
```

### Function prototype

```bash
$ r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; s sym.mime_content_type_new_from_string; pdf' \
    $ROOT/bin/mailscanner | head -5
            ; CALL XREF from fcn.0807d536 @ +0x302(x)
            ; CALL XREF from fcn.0807f8de @ 0x807fa0c(x)
┌ 2520: sym.mime_content_type_new_from_string (int32_t arg_60h, int32_t arg_64h, int32_t arg_68h);
│ `- args(sp[0x4..0xc]) vars(13:sp[0x10..0x5b])
│           0x08086093      55             push ebp
```

The signature line shows three pointer-size arguments: `arg_60h`, `arg_64h`, `arg_68h`.
We can learn how these arguments are used by looking at functions that call them.
The `CALL XREF` comments at the top list every function that calls this one. The
`+0x302(x)` means the call is 0x302 bytes past the start of `fcn.0807d536` (`0x0807d838`).

Here's the disassembly leading up to the first call site:

```bash
$ r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; s 0x0807d818; pd 13' $ROOT/bin/mailscanner
            ; CODE XREF from fcn.0807d536 @ +0x2a6(x)
            0x0807d818      8b542408       mov edx, dword [esp + 8]
            0x0807d81c      8b7a04         mov edi, dword [edx + 4]
            0x0807d81f      e889e8ffff     call fcn.0807c0ad
            0x0807d824      29c7           sub edi, eax
            0x0807d826      83ec04         sub esp, 4
            0x0807d829      8d57fe         lea edx, [edi - 2]
            0x0807d82c      52             push edx
            0x0807d82d      6a00           push 0
            0x0807d82f      8b54240c       mov edx, dword [esp + 0xc]
            0x0807d833      8d440202       lea eax, [edx + eax + 2]
            0x0807d837      50             push eax
            0x0807d838      e856880000     call sym.mime_content_type_new_from_string
            0x0807d83d      894618         mov dword [esi + 0x18], eax
```

Reading the three pushes bottom-to-top (remember cdecl pushes args in reverse order):

- 1st argument (`push eax`): `lea eax, [edx + eax + 2]` is pointer arithmetic, computing
  an address into a buffer. This is probably the `Content-Type` string to parse.
- 2nd argument (`push 0`): literal `0`. The other call site passes `1` here, so this is
  probably a flag or boolean field.
- 3rd argument (`push edx`): `lea edx, [edi - 2]` computes a small integer. Given that
  arg1 is a string, this is likely its length.

For our harness, the prototype we'll assume is:
`void *mime_content_type_new_from_string(const char *string, int flags, int length)`.
We'll pass the fuzz input as `arg1`, `0` as `arg2`, and `strlen(input)` as `arg3`.

### Cleanup

The target function name ends in `_new_from_string`, suggesting it allocates and returns
something. There's a matching `mime_content_type_destroy` in the exports:

```bash
$ nm -D $ROOT/bin/mailscanner | grep mime_content_type
08085f2b T mime_content_type_copy
08085e4c T mime_content_type_destroy
08085e14 T mime_content_type_get_boundary
08085ddc T mime_content_type_get_filename
08085a47 T mime_content_type_new
08086093 T mime_content_type_new_from_string
```

The `_new`/`_destroy` pair tells us that the parse function allocates something, and we
need to call the destroy function after each fuzz iteration to free it. Otherwise we
leak memory and the fuzzer (and host system) will slow to a crawl.

## Summary

* `char *Qdecode(const char *input, int len)` returns an allocated string after it has decoded it
* `void *mime_content_type_new_from_string(const char *s, int flags, int len)` returns an allocated structure of some type, which we'll free with...
* `void mime_content_type_destroy(void *ct)` frees the structure allocated by `mime_content_type_new_from_string`

Next: [Part 3: Writing the Fuzzing Harness]({% link day-2/03_writing_harness.md %})
