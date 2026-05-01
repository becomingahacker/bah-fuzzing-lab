---
title: "Part 3: Writing the Fuzzing Harness"
parent: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 3
---

# Part 3: Writing the Fuzzing Harness

I mentioned before that `mailscanner` is an executable, not a shared library, meaning we can't `dlopen` it.

This part covers the process of converting it to a shared object with functions we can `dlsym` and call, and then building the harness itself.

## Step 1: Convert program to shared library with LIEF

[LIEF](https://lief.re) is a really useful tool that can patch the ELF header to change the file type from `EXEC`
(fixed load address, not relocatable) to `DYN` (shared object, `dlopen`-able).  It also lets us do things like
make some functions/symbols exported as well as remove library dependencies if they aren't used by the code we care about.

The code below is enough to change the executable into a loadable library.
```python
import lief

binary = lief.parse("mailscanner")
binary.header.file_type = lief.ELF.Header.FILE_TYPE.DYN
```

## Step 2: Strip unused dependencies

`mailscanner` links against over 20 shared libraries. Most seem to be related to infrastructure (database, IPC, licensing)
that the parsing functions never call.

You can confirm this by tracing the call graph with r2:

```bash
# What does Qdecode actually call?
$ r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; s sym.Qdecode; pdf' \
    $ROOT/bin/mailscanner 2>/dev/null | grep -o "call [^ ]*" | sort -u
call fcn.08062160
call fcn.080fe300
call sym.imp.__ctype_b_loc
call sym.imp.malloc
call sym.imp.strchr
call sym.imp.strtol
```

* `fcn.08062160` calls `__x86.get_pc_thunk.bx` (internal) and
* `fcn.080fe300` calls `__stack_chk_fail`. The actual library calls are `malloc`, `strchr`, `__ctype_b_loc`, and `strtol`. All of them are part of libc.

Same for `mime_content_type_new_from_string`: `strdup`, `strncasecmp`, `strndup`,
`free`, `realloc`, `memcpy`, `memset`, `index`. All part of libc.

The external libraries (`libsvc.so`, `libgarnerc.so`, `libpq.so.5`, etc.) are only
called from output and infrastructure functions. You can verify this with r2's `axt` command to find xrefs to the library functions.
For example, every call to `PQexec` (PostgreSQL query execution) comes from a database function:

```bash
$ r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; axt sym.imp.PQexec' $ROOT/bin/mailscanner
sym.commit_queries_to_db 0x8088834 [CALL:--x] call sym.imp.PQexec
sym.commit_queries_to_db 0x80888c0 [CALL:--x] call sym.imp.PQexec
sym.commit_queries_to_db 0x80889fc [CALL:--x] call sym.imp.PQexec
```

You can repeat this for any imported function (`ii` lists them all, `axt` shows
where each one is called). None of the MIME parsing functions call into the
external libraries, so we should be able to remove them as dependencies:

(from the same python session as the previous LIEF block)

```python
keep = {"libc.so.6", "ld-linux.so.2", "libdl.so.2", "libm.so.6",
        "libpthread.so.0", "libgcc_s.so.1", "libstdc++.so.6"}

for entry in list(binary.dynamic_entries):
    if entry.tag == lief.ELF.DynamicEntry.TAG.NEEDED:
        if entry.name not in keep:
            binary.remove_library(entry.name)
```

## Step 3: Remove version tables

The `.gnu.version` and `.gnu.version_r` sections reference the removed libraries.
The dynamic linker checks these sections at load time and fails since we removed the libraries. 
We have to remove the references from there as well to make it load:

```python
for entry in binary.dynamic_entries:
    if entry.tag in (lief.ELF.DynamicEntry.TAG.VERSYM,
                     lief.ELF.DynamicEntry.TAG.VERNEED,
                     lief.ELF.DynamicEntry.TAG.VERNEEDNUM):
        entry.tag = lief.ELF.DynamicEntry.TAG.NULL

binary.write("mailscanner.so")
```

## Step 4: Build stubs

After removing all those libraries, about 100 symbols remain unresolved. These are symbols
that `mailscanner` imported from those libraries and likely won't be used by the parsing code.
The dynamic linker needs them to exist, even though our target functions never call them.

Creating stubs for each would take a long time. The simplest way to fix this is to just export each symbol as a zero-initialized pointer.

You can even script that:

```bash
nm -D mailscanner.so | grep " U " | grep -v "@GLIBC\|@GCC\|@CXXABI\|@GLIBCXX" | \
    awk '{print $2}' | sed 's/@.*//' | sort -u | \
    while read sym; do echo "void *${sym} = (void*)0;"; done > stubs.c

clang -m32 -shared -o stubs.so stubs.c
```

Briefly, what this is doing is taking all the undefined symbols (that need to be filled in by the loader) from `mailscanner.so`, ignoring the ones related to the standard library, removing the `@LIBRARY_NAME` suffix from each symbol name, removing duplicates, and finally outputting a zero-initialized pointer to define each symbol.  Once that source file is created, we turn it into a library we can load to satisfy the missing symbols in our harness.

If any stub symbol is actually called, the program jumps to address 0 and crashes.
If that happens, use r2's `axt` to trace the call chain and figure out why the
parsing code reached the missing function. You might need to provide a stub that returns
a harmless value (0 or NULL), or adjust the harness to avoid triggering that code
path (e.g. by passing different flags to the target function).

## Step 5: The harness

The first part of our harness will be loading `mailscanner.so` and getting the addresses of the functions we need to call.

```c
static void load_lib(void) {
    /* Load stubs first with RTLD_GLOBAL so mailscanner.so finds them */
    dlopen("./stubs.so", RTLD_LAZY | RTLD_GLOBAL);

    /* Load mailscanner.so with RTLD_LAZY */
    void *h = dlopen("./mailscanner.so", RTLD_LAZY);

    /* Look up target functions */
    parse   = dlsym(h, "mime_content_type_new_from_string");
    destroy = dlsym(h, "mime_content_type_destroy");

    /* Suppress internal logging */
    int *log_level = dlsym(h, "log_level");
    if (log_level) *log_level = 0;
}
```

Using `RTLD_LAZY` is important because otherwise the linker would try to resolve all of the null pointer stubs we made and crash.
This way, we can defer resolution until actual call time, and our target functions should only call standard libc.

### Simple `Qdecode` harness

> full source is in `harness/harness_qdecode.c`

```c
int main(int argc, char **argv) {
    if (argc < 2) return 1;
    static int init;
    if (!init) { load_lib(); init = 1; }

    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    if (len < 0 || len > 64 * 1024) { fclose(f); return 1; }
    fseek(f, 0, SEEK_SET);
    char *buf = malloc(len + 1);
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);

    char *decoded = decode(buf, (int)len);
    if (decoded) free(decoded);

    free(buf);
    return 0;
}
```

Read file, pass to `Qdecode`, free result, exit. Nothing fancy. We limit 64 KB cap keeps
execution fast without limiting the bug (the overflow triggers with just 10 bytes).

### harness_ct.c

We use the same pattern for the Content-Type parser, calling `mime_content_type_new_from_string`
and then `mime_content_type_destroy` on the result to free it.

### Compiling

```bash
clang -m32 -g -O2 -o harness_qdecode harness_qdecode.c -ldl
clang -m32 -g -O2 -o harness_ct harness_ct.c -ldl
```

`-m32` is required because `mailscanner.so` is 32-bit i386 and only 32-bit programs can load it.

### Sanity check

```bash
echo -n 'Hello =41=42=43 World' > test_qd.txt
./harness_qdecode test_qd.txt
echo $?   # should be 0

echo -n 'text/html; charset=utf-8' > test_ct.txt
./harness_ct test_ct.txt
echo $?   # should be 0
```

If these segfault, check that `stubs.so` and `mailscanner.so` are in the current
directory and that the symbol names match.

## The setup script

The `harness/setup.sh` script automates all of this:

```bash
./setup.sh $ROOT
```

It copies `mailscanner` from the rootfs, runs the LIEF conversion, generates stubs,
compiles both harnesses, creates a starter seed corpus and dictionaries full of plausible inputs, and runs a sanity check to ensure it built correctly.

Next: [Part 4: Running AFL++ in QEMU Mode]({% link day-2/04_running_afl.md %})
