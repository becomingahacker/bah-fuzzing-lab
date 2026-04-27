---
title: "Lab 2 — libFuzzer + sanitizers"
permalink: /labs/lab-02-libfuzzer-sanitizers/
---

# Lab 2 — libFuzzer + sanitizers

> Placeholder content — fill in with the real lab steps.

## Goals

- Write a `LLVMFuzzerTestOneInput` harness for an in-process target.
- Build with `-fsanitize=fuzzer,address,undefined` to enable libFuzzer
  + ASan + UBSan.
- Distinguish heap-buffer-overflow vs. integer-overflow vs.
  use-after-free findings in the sanitizer output.
- Reduce a crashing input with `-minimize_crash=1`.

## Steps

1. Open `harness.cc` in the lab directory.
2. Implement the harness against the target API.
3. Compile: `clang++ -g -O1 -fsanitize=fuzzer,address,undefined harness.cc target.cc -o harness`.
4. Run: `./harness -max_total_time=120 corpus/`.
5. Read the sanitizer report on the first crash; classify the bug.
6. Minimize the crashing input: `./harness -minimize_crash=1 crash-<hash>`.

## Next

- [Back to lab index]({{ '/' | relative_url }}#lab-modules)
- [Previous: Lab 1 — AFL++ basics]({{ '/labs/lab-01-afl-basics/' | relative_url }})
