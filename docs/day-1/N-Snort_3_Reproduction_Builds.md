---
title: "Appendix: Snort 3 Reproduction Builds"
parent: "Day 1: Snort 3 with LibFuzzer"
nav_order: 99
---

## Reproduction Builds
It's one thing to find a crash in a fuzzer build of Snort with ASAN instrumentation enabled.  It's another to have it crash a real production instance of Snort.  To test that our fuzzer-found crashes are truly high impact, we'll want to build the full Snort and test our inputs against it as well.
### Building
> All build steps assume you're starting from a directory containing the `snort3` repository and the `libdaq` repository.  We'll assume it's `/home/cisco/target`.

#### Building Snort 3
Since `snort3` is our main fuzzing target here, we'll put extra care into building it with specific options.  We'll also customize its build as we try different strategies.  One strategy we'll use quite often is to build it with AddressSanitizer (ASAN).

To build `snort3` with ASAN, you can use `--enable-address-sanitizer` with `./configure_cmake.sh`.  We also use `--with-daq-includes=` and `--with-daq-libraries=` to point to the `libdaq/build/include` and `libdaq/build/lib` that we built in the previous step.

You can find more build options by using `./configure_cmake.sh --help`.  Keep in mind that his build is for building the entire snort application, so it will take awhile.  This kind of build is useful for testing crashing inputs against the "real deal" to see if it really would crash an instance of snort that has ASAN instrumentation enabled, instead of just in the fuzzer.

```bash
(
  cd snort3;
  CC=clang-20 CXX=clang++-20 ./configure_cmake.sh --enable-address-sanitizer --with-daq-includes=$PWD/../libdaq/build/include --with-daq-libraries=$PWD/../libdaq/build/lib --prefix=$PWD/snort_asan && \
  ( cd build; make -j $(nproc) install )
)
```

Now you should be able to find the `snort` executable in `snort3/snort_asan/bin`.

We'll also want to build the exact same thing without ASAN, so we can prove that a particular input can crash or do something nasty to an actual production Snort 3 instance that would be running on a typical network.

To do that, it's basically the same as before, without the `--enable-address-sanitizer`.

```bash
(
  cd snort3;
  CC=clang-20 CXX=clang++-20 ./configure_cmake.sh --with-daq-includes=$PWD/../libdaq/build/include --with-daq-libraries=$PWD/../libdaq/build/lib --prefix=$PWD/snort_asan && \
  ( cd build; make -j $(nproc) install )
)
```
### Running Snort 3
You can find Snort usage information with `snort3/snort_asan/snort --help`.

To test our fuzzer crashes with minimal fuss, we'll mostly be making use of its PCAP reading functionality: `bin/snort -c etc/snort/snort.lua -r path/to/file.pcap`

If you are testing an ASAN build, make sure to set `ASAN_OPTIONS=detect_leaks=0` when running Snort.