---
title: "Day 2: Closed-Source Firmware with AFL++"
nav_order: 3
has_children: true
permalink: /day-2/
---

# Fuzzing Closed-Source Firmware with AFL++ QEMU Mode

A hands-on tutorial using Sophos Firewall OS as the target. By the end you'll have  
built all the tools to find a 0day vulnerability in a proprietary MIME decoder.

## What You'll Learn

1. How to pick a fuzzing target inside extracted firmware
2. How to find a function's prototype using radare2 (or your preferred toolkit)
3. How to convert a non-PIE executable into a fuzzable shared library with LIEF
4. How to write a C harness that loads and calls the target
5. How to run AFL++ in QEMU mode with CMPLOG and QASan
6. How to triage crashes and confirm vulnerabilities

## Prerequisites

> These are already fulfilled in the lab environment so you can get rightt to building.  
> The prerequisites here are for if you decide to continue on your own machines.

- AFL++ built from source, with QEMU mode build for i386 (`CPU_TARGET=i386` during `make distrib`)
- The Sophos SFOS root filesystem extracted and available (`$ROOT`)
- Python `lief` package (`pip3 install lief`)
- `radare2` for disassembly one-liners used in the guide
- 32-bit clang toolchain (`apt install clang libc6-dev-i386`)
- Basic C and x86 assembly knowledge

## Files

The lessons start off pretty dense to make sure you have all the info you need, but they get more to the point as you get further.

```
fuzzer_lesson/
  README.md              <- you are here
  01_picking_targets.md  -- survey firmware, choose a target
  02_reverse_engineering.md -- disassemble the target func with r2
  03_writing_harness.md  -- LIEF conversion, stubs, the C harness
  04_running_afl.md      -- seeds, QEMU mode, QASAN, CMPLOG
  05_exercise.md         -- your turn: fuzz a different parser function
  harness/               -- working code (setup.sh builds everything)
  exercise/              -- skeleton with TODOs for you to fill in
```

Make sure to ask questions if you get stuck!  During the workshop we'll have Breakout Rooms on WebEx we can use to 1:1 debug things, and during the conference we'll be around to answer questions.

Start with [Part 1: Picking a Fuzzing Target]({% link day-2/01_picking_targets.md %}).