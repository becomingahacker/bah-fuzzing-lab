---

## title: "Part 1: Picking a Fuzzing Target"
parent: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 1

# Part 1: Picking a Fuzzing Target

You've extracted a firmware image and you're staring at thousands of files. Where do
you start?

## What we're looking for

We want to find programs/libraries that:

- Parse untrusted input (network packets, file formats, protocol fields)
- Can be run/emulated without the full system running
- Are complex enough to have bugs (not a thin wrapper or simple tool)

## Surveying the firmware

> The lab should have already set the `ROOT` environment variable set to the rootfs of the extracted firmware image.
> If you're playing along at home instead, you'll want to set this for the remainder of these lessons. 

Let's take a poke at the Sophos Firewall OS root filesystem (`$ROOT`)

```bash
find $ROOT/bin $ROOT/lib -type f -executable 2>/dev/null
```

One directory catches the eye:

```bash
$ ls $ROOT/lib/garner/inputplugin/
libatp_gr.so    libfirewall.so  libhttp_gr.so   libidp.so     libtls_gr.so
libatpv_gr.so   libftp_gr.so    libhttpv_gr.so  libipsec.so   libwaf_gr.so
...
```

Shared libraries called "input plugins" inside something called "garner." The names
have protocol names in them which means they could be parsers: HTTP, TLS, firewall, IDP, FTP, IPsec, WAF.

## The garner trap

These look perfect for fuzzing. Each plugin exports three functions (`init`/`input`/`close`),
which sounds like a plugin initializing, taking input, and closing.
But if we look at what the function calls:

```bash
$ r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; s sym.http_gr_input; pdf' \
    $ROOT/lib/garner/inputplugin/libhttp_gr.so | grep "call "
│       │   0x000006d2      call reloc.__assert_fail
│       │   0x00000a77      call reloc.__stack_chk_fail
```

There are only two calls in the entire function, and they're added by FORTIFY, not the devs. No internal or library calls.  There doesn't seem to
be any string parsing or state machines. It's unlikely that these are protocol parsers, but instead could be logging or eventing utilities.
We could fuzz these, but we'd likely find nothing interesting. This is why it's important to really dig into a
potential target to make sure it's worth your effort before committing.

## Finding some better targets

We'll look for large binaries with lots of exported functions.  There are many ways to do this and the simplest way may be just
initially sorting by file size in reverse order so we can look at the biggest ones at the tail of the output:

```bash
find $ROOT/bin $ROOT/lib -type f -executable 2>/dev/null | xargs ls -lhSr
```

From there we can count exports of some selected binaries to compare, with:

```bash
nm -D $ROOT/path/to/binary | grep " T " | wc -l
```

You should also remove the `wc -l` after, to see what those exports look like.

Here are a few results that were considered:

- `mailscanner` likely does email processing.  It has symbols related to MIME parsing, SMTP, IMAP
- `awarrensmtp` seems to be an SMTP proxy with a state machine for parsing an SMTP conversation
- `ftpproxy` looks like it parses FTP commands

Out of these, we chose `mailscanner` partly because it had the most exports and was the largest of the three,
which in some cases indicates it has lots of code to test.

```bash
$ nm -D $ROOT/bin/mailscanner | grep " T " | wc -l
1676
$ nm -D $ROOT/bin/mailscanner | grep " T " | grep -iE "mime|decode|parse|smtp|header"
...
08086be6 T mime_disposition_new
08086a6b T mime_part_encoding_from_string
08086b6d T mime_part_encoding_to_string
080fba1d T new_parser_brace_delimited
080fba93 T new_parser_brace_delimited_parse_state
080fb772 T new_parser_char_parse_state
080fb948 T new_parser_delimited
...
```

`mailscanner` exports 1676 symbols, many with names like `mime_content_type_new_from_string`,
`Qdecode`, `mime_disposition_new`, `smtpparse`, `parse_headers`, `encodedWordToUtf`.
These are good indications that it contains real parsers that process email content.

## Architecture check

```bash
$ file $ROOT/bin/mailscanner
ELF 32-bit LSB executable, Intel i386, version 1 (SYSV),
dynamically linked, interpreter /lib/ld-linux.so.2, stripped
```

One complication is that it's an executable, not a shared library, so we can't just `dlopen` it. There are ways to fix that though,
which we'll cover in [Part 3]({% link day-2/03_writing_harness.md %}).

## Our targets

We'll fuzz two functions from `mailscanner`:

- `Qdecode`, which is a small function that parses [quoted-printable encoded text](https://dencode.com/en/string/quoted-printable)
- `mime_content_type_new_from_string`, a larger function which parses `Content-Type` header values

Both take a string buffer and its length as input (no complex structs or global
state), making them trivial to harness.

> **Note:** These walkthroughs take you through our journey of harnessing these functions.  The exercise
> at the end has you fuzz `mime_disposition_new` (`Content-Disposition` parser) on your own.

Next: [Part 2: Reverse-Engineering the API]({% link day-2/02_reverse_engineering.md %})