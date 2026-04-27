---
title: Day 1
nav_order: 3
has_children: true
permalink: /day-1/
---

# Day 1 — Fuzzing fundamentals

Day 1 introduces the core idea of coverage-guided fuzzing and the two
toolchains we'll use throughout the workshop: **AFL++** and **libFuzzer**.
By the end of the day you should be able to instrument a small target,
run a fuzzer against it, and triage a crash with sanitizers.

## Prereqs

- You have completed the [environment setup]({{ '/setup/' | relative_url }}).
- You can SSH into your pod's `ubuntu-fuzzing` VM as `cisco`.

Pick an exercise from the sidebar to get started.
