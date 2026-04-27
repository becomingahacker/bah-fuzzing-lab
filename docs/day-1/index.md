---
title: "Day 1"
permalink: /day-1/
---

# Day 1 — Fuzzing fundamentals

Day 1 introduces the core idea of coverage-guided fuzzing and the two
toolchains we'll use throughout the workshop: **AFL++** and **libFuzzer**.
By the end of the day you should be able to instrument a small target,
run a fuzzer against it, and triage a crash with sanitizers.

## Exercises

1. [Exercise 1 — AFL++ basics]({{ '/day-1/01-afl-basics/' | relative_url }})
2. [Exercise 2 — libFuzzer + sanitizers]({{ '/day-1/02-libfuzzer-sanitizers/' | relative_url }})

## Prereqs

- You have completed the [environment setup]({{ '/setup/' | relative_url }}).
- You can SSH into your pod's `ubuntu-fuzzing` VM as `cisco`.

## Navigation

- [Back to home]({{ '/' | relative_url }})
- [Continue to Day 2 →]({{ '/day-2/' | relative_url }})
