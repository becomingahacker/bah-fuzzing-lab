---
title: "Part 5: Exercise"
parent: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 5
---

# Part 5: Exercise -- Fuzz a Different Parser

In this exercise I suggest you target `mime_disposition_new` from `mailscanner` and go through the full process:
reverse-engineer it, fill in the harness skeleton, add some starter seeds, fuzz it, and analyze the results.

You're welcome to try a different function, but this one seems similar to the one we already fuzzed so it shouldn't be as difficult to get started with.

## Background

`mime_disposition_new` parses Content-Disposition headers such as:

```
attachment; filename="document.pdf"
inline; filename="image.png"
```

## Step 1: Find the symbols

```bash
nm -D mailscanner.so | grep mime_disposition
```

Note down the parse and destroy symbol names.

## Step 2: Figure out the function signature

Use the same technique from [Part 2]({% link day-2/02_reverse_engineering.md %}): find a call site with `axt`, then read the
push instructions before the call to determine the argument types.

```bash
r2 -a x86 -b 32 -qc 'aaa; axt sym.mime_disposition_new' mailscanner.so
```

Pick one of the call sites and disassemble the surrounding code to see what gets
pushed. How many arguments? What types?

Also confirm there's a `_destroy` function you'll need to call after each iteration.

## Step 3: Find the parameter keywords

Like we did for the Content-Type parser, grep for `strncasecmp` or similar functions to see what
keywords the parser matches. This tells you what seed inputs will exercise the
most code (you may need to adjust the `grep -B4` value):

```bash
r2 -e scr.color=0 -a x86 -b 32 -qc 'aaa; s sym.mime_disposition_new; pdf' mailscanner.so | \
    grep -B4 strncasecmp
```

What string constant is compared? What length? 

## Step 4: Fill in the harness

A fuzzer skeleton is at `exercise/harness_exercise.c` with four TODOs:

1. Function pointer type definitions (argument types)
2. `dlsym` symbol names
3. Call the parse function with the right arguments
4. Call destroy on the result

Refer to `harness/harness_ct.c` for the pattern.

## Step 5: Create seeds

Create some seeds in `exercise/corpus_exercise/`:

## Step 6: Create a dictionary

Similar to Step 5, you can probably look up some examples of Content-Disposition headers online and get some ideas of tokens that would be good to include.

## Step 7: Compile and test

```bash
cd exercise
./setup_exercise.sh        # links mailscanner.so and stubs.so from harness/
clang -m32 -g -O2 -o harness_exercise harness_exercise.c -ldl
./harness_exercise corpus_exercise/attachment.txt
echo $?                    # should be 0
```

## Step 8: Fuzz

```bash
./run_fuzz_exercise.sh
```

Or manually:

```bash
AFL_QEMU_INST_RANGES=0x08048000-0x082da000 \
afl-fuzz -Q -c 0 \
    -i corpus_exercise \
    -o findings_exercise \
    -x dict/disposition.dict \
    -t 500 -m none \
    -- ./harness_exercise @@
```

## Step 9: Analyze

After 2-5 minutes:

- How many corpus items did AFL find?
- What's the map coverage percentage?
- Any crashes?

If you found crashes, reproduce them:

```bash
./harness_exercise findings_exercise/default/crashes/id:000000,...
```

Also try reproducing them with GDB attached!

### Going further

- Try fuzzing with QASan (`AFL_PATH=... AFL_USE_QASAN=1`)
- Look through the AFL++ docs for QEMU mode and try some more documented features out.  Persistent mode will likely get you much more speed at the cost of a bit more complicated setup
- Try fuzzing another `mailscanner` function such as `encodedWordToUtf` (calls `Qdecode` and `Bdecode`, so it's a higher-level function)
