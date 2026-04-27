---
title: "Day 2 · Exercise 1 — Structure-aware fuzzing"
permalink: /day-2/01-structure-aware-fuzzing/
---

# Day 2 · Exercise 1 — Structure-aware fuzzing

> Placeholder content — fill in with the real lab steps.

## Goals

- Recognize when a coverage-guided fuzzer struggles with a structured
  input format (e.g. PNG, ELF, JSON).
- Use an AFL++ dictionary to teach the fuzzer the format's tokens.
- Write a libFuzzer custom mutator (`LLVMFuzzerCustomMutator`) for a
  protobuf-shaped input.
- Compare coverage growth and crash rate before vs. after the
  structure-aware changes.

## Steps

1. Pick the structured target in `day-2/struct-aware/`.
2. Run AFL++ against it without a dictionary; record coverage after 5 min.
3. Add a dictionary file and rerun; record the delta.
4. Implement a libFuzzer custom mutator using the provided protobuf schema.
5. Diff the crashes / coverage edges between the two approaches.

## Navigation

- [Back to Day 2 index]({{ '/day-2/' | relative_url }})
- [Next: Exercise 2 — Harnessing & triaging a real target]({{ '/day-2/02-real-target-triage/' | relative_url }})
