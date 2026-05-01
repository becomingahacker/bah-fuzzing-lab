---
title: "Part 4: Running AFL++ in QEMU Mode"
parent: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 4
---

# Part 4: Running AFL++ in QEMU Mode

## System setup

First we run this script included with AFL++ which preps your system for fuzzing without issues.
It suggests to change the arguments to our kernel, but we don't need to go that far for this workshop.

```bash
sudo afl-system-config
```

## Building seeds

AFL takes seed inputs and mutates them by flipping bits, splicing bytes, and watching for
new coverage after running with the mutated input. Through the evolutionary algorithm, it is
possible for AFL++ to generate valid inputs from an invalid starting input.  However, if you start
from inputs that *should* pass the parser's validation, you'll get more coverage and find bugs quicker.

Each seed should exercise a different code path to maximize coverage of the parsing code.

### Content-Type fuzzer seeds

For the `mime_content_type_new_from_string` fuzzer, we can maximize coverage by using inputs that have:

* different types (`text/plain`, `application/octet-stream`)
* parameter keywords (`charset`, `boundary`, `name`)
* quoted values (`multipart/mixed; boundary="----=_Part_123"`)
* backslash escapes (`text/html; boundary="test\"escaped"`)

You don't want to try to trigger bugs with your initial seeds, but rather just test more features of the parser.

### Qdecode fuzzer seeds

For this, the function seems to be taking `=XY` where `X` and `Y` are hex nibs, so we can create some variations of those such as:

* `Hello =41=42=43 World` (valid encoded bytes with non-encoded chars)
* `=48=65=6C=6C=6F` (valid encoded bytes)
* `No encoding here`
* `=4` (only 1 hex nib)
* `=GG=ZZ` (invalid hex nibs)
* `=00=01=FF=FE` (non-ASCII bytes)

### Dictionaries

AFL++ QEMU mode on its own has trouble generating long tokens used in comparisons in the program.
Dictionaries give AFL++ known tokens that it will insert as part of its mutations.

`Qdecode` hardly needs a dictionary, but we'll include some interesting values and values it should use more often in its mutations to steer it a bit.

`dict/qdecode.dict`:
```
"="
"=3D"
"=0D=0A"
"=00"
"=FF"
"=GG"
```

The Content-Type fuzzer benefits a lot more from dictionaries since it deals with large string tokens.  You can add more if you think of some, but this is a good start:

`dict/mime.dict`:
```
"charset"
"boundary"
"name"
"text/html"
"multipart/mixed"
";"
"="
```

## QEMU mode basics

AFL++ QEMU-mode is built in our lab for 32-bit i386 targets.  To do the same for your own computer at home, add `CPU_TARGET=i386` when you do `make distrib` as part of the AFL++ build process.

## Running AFL++ with QEMU-mode

```bash
AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
afl-fuzz -Q \
    -i corpus_qdecode \
    -o findings_qdecode \
    -x dict/qdecode.dict \
    -t 500 \
    -m none \
    -- ./harness_qdecode @@
```

That's a lot of arguments and a strange looking environment variable, so I'll explain:
* `AFL_QEMU_INST_RANGES` : Only instrument the mailscanner code (0x08048000 to 0x082da000). Excludes libc and the harness from the coverage map.
* `-Q` indicates to AFL++ to use QEMU mode
* `-i` should point to our seed corpus directory
* `-o` is our output directory, where the mutated corpus, crashes, stats, etc will be kept
* `-x` points to the (optional) dictionary file for the fuzzer
* `-t 500` sets a timeout for running against each mutated testcase.  It's a balance.  If you keep it too low you'll miss complex parsing, but if you keep it too high it may be very slow
* `-m none` tells AFL++ not to limit memory allocations.  There's usually no reason to change this.
* `@@` is a placeholder where AFL substitutes the input file path

Without `AFL_QEMU_INST_RANGES`, AFL adds its edge coverage instrumentation to everything including libc's code, filling the coverage map with noise.
To find the right range, look at the executable LOAD segment in the ELF program headers:

```bash
$ readelf -l $ROOT/bin/mailscanner | grep "LOAD.*R.E"
  LOAD           0x000000 0x08048000 0x08048000 0x291968 0x291968 R E 0x1000
```

The executable code loads at 0x08048000 with size 0x291968, so it ends at
`0x08048000 + 0x291968 = 0x082d9968`. To be safe we'll round up to the next page boundary.  To find the page boundary we take the rightmost value from `readelf`'s output, `0x1000`, which is the page size, and add it to our ending value, then apply an `AND` mask: `(0x82d9968 + 0x1000) & 0xFFFFF000 = 0x082da000`.
That gives us `AFL_QEMU_INST_RANGES=0x08048000-0x082da000`.

(You could also use `readelf -S` to get the `.text` section range specifically, but
the full executable LOAD segment is simpler and catches any code in `.init` or
`.plt` too.)

## Sanity check

Before launching a full fuzzing campaign, verify that QEMU mode actually sees
coverage from your harness. `afl-showmap` runs a single input through the
instrumented binary and reports how many coverage tuples it found:

```bash
$ AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
  afl-showmap -Q -o /dev/null -t 2000 -m none \
    -- ./harness_ct corpus_ct/text_plain.txt
afl-showmap++4.41a by Michal Zalewski
[*] Executing './harness_ct'...
-- Program output begins --
-- Program output ends --
[+] Captured 182 tuples (map size 65536, highest value 5, total values 225) in '/dev/null'.
```

182 tuples means the fuzzer is seeing coverage inside `mailscanner.so`.
If this showed 0 tuples, the instrumentation range is likely wrong and the target code
doesn't fall within it. If it showed a very small number (say, under 10), the
harness might be failing early without reaching the parser.

## Optimizations

### CMPLOG mode

CMPLOG intercepts comparison instructions and learns the compared values. If the target checks
`strncasecmp(param, "boundary", 8)`, CMPLOG extracts `"boundary"` and tries injecting
it at every offset in the input. This solves multi-byte magic comparisons that random
mutation would take a long time to guess or that we'd have to create dictionary entries for.

```bash
AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
afl-fuzz -Q \
    -c 0 \
    -i corpus_ct \
    -o findings_ct \
    -t 500 \
    -m none \
    -- ./harness_ct @@
```

The `-c 0` flag tells AFL++ to use the target itself as the CMPLOG binary. It tested this and found that it
approximately doubled the corpus size in 30 seconds of running the `Content-Type` fuzzer vs running it without CMPLOG.

### CompareCoverage (libcompcov)

An older, lighter alternative to CMPLOG which preloads a library that hooks `strcmp`,
`memcmp`, and (at level 2) inline `cmp` instructions. It lets AFL++ see new coverage when a comparison partially matches,
so the fuzzer can eventually learn the value being compared against. It usually has a smaller performance impact than CMPLOG but it's often not as effective.

```bash
AFL_PRELOAD=/path/to/AFLplusplus/libcompcov.so \
AFL_COMPCOV_LEVEL=2 \
AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
afl-fuzz -Q -i corpus_ct -o findings_ct -t 500 -m none -- ./harness_ct @@
```

I tried this out on the Content-Type parser and it found 219 tuples vs 182
without COMPCOV. On the Qdecode fuzzer it found 145 tuples vs 114 without it.

Therefore I'd recommend that you use CMPLOG (`-c 0`) when it doesn't
make your fuzzer unreasonably slow, and in the rare case that it does, you should use COMPCOV.

### QASAN (AddressSanitizer in AFL++ QEMU mode)

This does its best to emulate the same LLVM ASAN feature to find things like:

- Heap buffer overflows (read or write)
- Use-after-frees
- Double-frees
- Heap out-of-bounds accesses

Enable it with `AFL_USE_QASAN=1`:

```bash
AFL_USE_QASAN=1 \
AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
afl-fuzz -Q -i corpus_qdecode -o findings_qdecode -t 2000 -m none \
    -- ./harness_qdecode @@
```

Outside of this lab, you might need to set `AFL_PATH` to the AFL++ build directory so the fuzzer finds `libqasan.so`:

QASAN creates a pretty noticable performance hit, but it's generally worth it for the increased bug-finding potential.

## Output structure

After you run `afl_fuzz`, it will have generated a bunch of files in your output directory.

```
findings_qdecode/
  default/
    queue/        # inputs that found new coverage
    crashes/      # inputs that crashed the target
    hangs/        # inputs that timed out
    fuzzer_stats  # performance statistics
```

## Run scripts

The `harness/` directory includes:

```bash
./run_fuzz_qdecode.sh       # Fuzz Qdecode with CMPLOG
./run_fuzz_ct.sh            # Fuzz Content-Type with CMPLOG
./run_fuzz_qdecode_qasan.sh  # Fuzz Qdecode with QASan
./run_fuzz_ct_qasan.sh      # Fuzz Content-Type with QASan
```

Go ahead and give these a try.  Your next step is to create your own fuzzer harness for another function in `mailscanner`.

Next: [Part 5: Exercise]({% link day-2/05_exercise.md %})
