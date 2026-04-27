---
title: "Day 2 · Exercise 2 — Harnessing & triaging a real target"
permalink: /day-2/02-real-target-triage/
---

# Day 2 · Exercise 2 — Harnessing & triaging a real target

> Placeholder content — fill in with the real lab steps.

## Goals

- Pick a real-world C/C++ library on the VM and write a libFuzzer
  harness for one of its parsers.
- Run the harness with ASan + UBSan and collect a crash within the
  workshop timebox.
- Minimize the crashing input.
- Classify the bug (memory-safety class), then write a one-paragraph
  triage note as if you were filing it upstream.

## Steps

1. Choose a target from the curated list in `day-2/real-targets/`.
2. Identify a parser entry point and write `LLVMFuzzerTestOneInput`.
3. Build with `-fsanitize=fuzzer,address,undefined` and a small corpus.
4. Run for ~10 min; tail `crash-*` and reproduce.
5. Minimize with `-minimize_crash=1` and re-trigger from the minimized input.
6. Capture the ASan stack trace + minimized input + your triage note in
   `~/findings/`.

## Wrap-up

- Discuss findings with your group.
- File the most interesting finding in the workshop tracker.

## Navigation

- [Back to Day 2 index]({{ '/day-2/' | relative_url }})
- [Previous: Exercise 1 — Structure-aware fuzzing]({{ '/day-2/01-structure-aware-fuzzing/' | relative_url }})
- [Back to home]({{ '/' | relative_url }})
