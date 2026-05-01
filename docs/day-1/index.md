---
title: "Day 1: Snort 3 with LibFuzzer"
nav_order: 2
has_children: true
permalink: /day-1/
---

# Day 1: Fuzzing Snort 3 with LibFuzzer

Day 1 walks you through writing a coverage-guided fuzzer against Snort 3's
`bootp` service detector using LibFuzzer with AddressSanitizer, then tuning
the harness for coverage and stability until it finds a real bug.

## What you'll learn

1. How to build a fuzzer-instrumented Snort 3 with `--enable-fuzzers` and the
   sanitizer flags.
2. How LibFuzzer harnesses are structured: includes, stubs, and
   `LLVMFuzzerTestOneInput`.
3. How to design a packet-level harness with `FuzzedDataProvider` so you only
   spend fuzzing entropy on bytes that actually matter.
4. How to measure and improve coverage with `llvm-profdata` / `llvm-cov`.
5. How to switch the same target over to AFL++ instrumentation to measure
   stability, and how to chase the usual stability-killers (global state,
   non-deterministic time/RNG, etc.).
6. How to validate fuzzer-found crashes against a real Snort 3 build to
   confirm impact.

## Prerequisites

- A pod on the workshop's CML environment, or a local Linux box with the
  Snort 3 build dependencies installed.
- The `snort3` and `libdaq` source trees checked out side-by-side (already
  staged at `/home/cisco/target` on the lab VM).
- Comfort reading C++ and a working `clang-20` toolchain.

## Lesson plan

Work through the chapters in order. Each one builds on the previous, and the
asset files (`service_bootp.cc`, `bootp-fuzz-template.cc`, the seed corpus,
etc.) live alongside the lessons in this directory so you can grab them
directly if you are following along outside the lab VM.

When you finish, you will have a working, tuned harness and a reproducible
crash that lands in `service_bootp.cc`.
