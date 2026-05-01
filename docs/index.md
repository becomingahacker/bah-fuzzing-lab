---

## title: Home
layout: home
nav_order: 1

# OS2026 Fuzzing Workshop

Welcome! This is the lab guide for the **OS2026 Fuzzing Workshop**, a two-day workshop
to get you hands-on experience with coverage-guided fuzzing.
You will build fuzzing harnesses for real commercial software, run them with both LibFuzzer and AFL++, and learn to triage crashes.

## What you'll do

- **Day 1:  Snort 3 with LibFuzzer.** Build a fuzzer for Snort 3's  `bootp` service detector,
and tweak it for coverage and stability until it finds a real crash.
- **Day 2: Closed-source firmware with AFL++ QEMU mode.** Deep inside an extracted Sophos Firewall OS firwmare,
you'll do some light reverse engineering, convert an executable to a fuzzable shared
library with LIEF, and run AFL++ with CMPLOG and QASAN in hopes of finding a new bug.
- **Bonus Challenge: Parking Game.** Use a fuzzer to solve a puzzle game. Great practice for writing fuzzers for stateful targets.
There is less instruction on this one, so make sure to ask questions if stuck.

## How the lab is set up

Each attendee gets their own pod on Cisco Modeling Labs. Inside the pod is an
Ubuntu VM with the dependencies, target sources, and everything 
pre-staged for you so you can focus on learning to build fuzzing harnesses.
The lessons assume you are working on that VM, but every
step is reproducible on any modern Ubuntu/Linux box if you want to follow along
later.

When you sign up for a spot, you will receive SSH and pod credentials from your instructor.  
You are free to use SSH or a VSCode remote workspace using the SSH access to complete the modules.

## Asking for help

Throughout the workshop, raise your hand on WebEx or message one of the presenters any time you get stuck or if something
seems wrong in your lab environment. 
Being stuck for more than ~10 minutes on the same problem is a great signal to ask.  Fuzzing has a lot of
moving parts and it is much faster to debug together with someone who has hit nearly every issue you're running into.