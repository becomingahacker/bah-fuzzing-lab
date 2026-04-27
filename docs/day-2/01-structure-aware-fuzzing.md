---
title: "Exercise 1 — Structure-aware fuzzing"
parent: Day 2
nav_order: 1
permalink: /day-2/01-structure-aware-fuzzing/
---

# Exercise 1 — Structure-aware fuzzing

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
