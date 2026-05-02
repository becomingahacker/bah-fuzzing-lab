---
title: "Part 3: Improving Your Harness"
parent: "Day 1: Snort 3 with LibFuzzer"
nav_order: 3
---

# Improving Your Harness
Congratulations! You now have a working harness. There are two main aspects to the harness that needs to be monitored. First is the coverage, then the stability. 

## Coverage
- Part of what makes coverage based harnesses so cool is the ability of engines like LibFuzzer to find what lines of code it covered. The way to do that is to instrument the target. The snort team has added the necessary flags as an option in their build script, so all we have to add is the --enable-fuzz-coverage flag.
- Start from the snort directory, build your snort instance with instrumentation. 

```
./configure_cmake.sh --enable-fuzz-coverage --enable-fuzz-sanitizer --enable-fuzzers
cd build
```

- Now build your specific harness, and then run the harness for a few minutes with crash detection off. The goal isn't to find a crash right off the bat, but just to make sure that the harness can find its way through the entirety of your target. 

```
make <name of your harness>
cd fuzz
ASAN_OPTIONS=detect_leaks=0 LLVM_PROFILE_FILE="fuzz_%m.profraw" ./<name of your harness> -max_total_time=300 -print_final_stats=1
```

- After this run, LLVM will generate a raw profile file. You can use another LLVM tool, profdata, to merge and index the raw files into a format that the parser can read. Then, LLVM can show the results of the file in a human readable format. In this instance, we'll choose text, so that we can read it in the terminal.

```
llvm-profdata merge -sparse fuzz_*.profraw -o cov.profdata
llvm-cov report ./<name of your harness> -instr-profile=cov.profdata
llvm-cov show -format=text -instr-profile=cov.profdata \
./<name of your harness> -output-dir=rsync_fuzz_cov'
```

- If you are able to find any lines that aren't covered, ask yourself these questions:
	- Is it relevant to the code being targeted?
		- If not, should it be stubbed out?
	- If so, is the issue with the harness itself?
	- Do I need to write seeds to help the harness get going?

- Sometimes the answer is to run the harness for a bit longer, especially for more complicated codepaths. If your coverage stats for your target are not 100%, take a look at what might be different! Play around with the harness to find out what you might need to get full coverage. Feel free to ask a helper if you get stuck. 
- When you fix what you think is the issue, go through the above process again and see if your coverage stats improve.

## Stability
- A good fuzzing harness needs to be stable. This means that whenever an input is replayed in the harness, it will always come out with the same result and hit the same code paths. 
- You usually want to be aiming for above 100%, or close to 100% stability on your harnesses.
- This matters because low stability means that the fuzzer can't tell real new coverage from noise and wastes cycles on non-bugs and may miss real ones.
- The usual suspects can include global states that don't clear themselves after each input, RNG without a fixed seed, time/clock calls, ASLR-dependent iteration order, or threads.
- Let's take a gander at instrumenting our binary with AFL so that we can measure stability. First, remove the original build and then rebuild with the given compile script.

```bash
rm -rf build
export AFL_DIR=/home/cisco/AFLplusplus # or wherever the path to AFL++ is
export AFL_LIBRARY_DIR=/home/cisco/AFLplusplus # or wherever the path to libAFLDriver.a
./fuzz/scripts/compile/build-afl-fuzzers.sh
```

- Now, instead of LibFuzzer instrumentation, the binary is instrumented with AFL instrumentation! This is useful because AFL has the capability to measure stability whereas LibFuzzer doesn't. Usually you need to write a script to generate some seeds to get started, but we've done that for you to save time. Run this command to get started:

```bash
afl-fuzz -i bootp_seeds -o out/ -- ./build/fuzz/bootp-fuzz-template
```

- Notice the stability number in the `item geometry` box. It should be hovering around the 95% to 96% mark. Usually that's pretty good, but this exercise should be at 100% stability. What could be causing the issue? Read over the stub and harness and see if you can spot the issue. How can you fix it?
	- (Hint: it's one of the 5 issues that we listed earlier!)
- Once you figure it out, make the relevant changes to the files and then go through the process again. See if it improves. Happy hunting~!
