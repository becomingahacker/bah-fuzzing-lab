---
title: "Lab 1 — AFL++ basics"
permalink: /labs/lab-01-afl-basics/
---

# Lab 1 — AFL++ basics

> Placeholder content — fill in with the real lab steps.

## Goals

- Understand what coverage-guided fuzzing is and why AFL++ uses it.
- Build a target with `afl-clang-fast` instrumentation.
- Run `afl-fuzz` against the instrumented target with a small seed corpus.
- Triage a crash that AFL++ finds.

## Steps

1. Clone the lab target repo.
2. Build with `afl-clang-fast` / `afl-clang-fast++`.
3. Prepare a `seeds/` directory with a couple of valid inputs.
4. Run `afl-fuzz -i seeds -o out -- ./target @@`.
5. Inspect crashes under `out/default/crashes/` and reproduce one.

## Next

- [Lab 2 — libFuzzer + sanitizers]({{ '/labs/lab-02-libfuzzer-sanitizers/' | relative_url }})
- [Back to home]({{ '/' | relative_url }})
