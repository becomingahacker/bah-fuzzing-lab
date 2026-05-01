---
title: "Part 1: Building Snort 3"
parent: "Day 1: Snort 3 with LibFuzzer"
nav_order: 1
---

# Building Snort 3
## Dependencies
We have pre-installed dependencies for building `libdaq` and `snort3` on our cloud , but if for some reason you need to uninstall them or otherwise don't have them, here are the necessary packages install instructions that should get you set up:

```bash
sudo apt install clang-20 clangd-20 clang-format-20 clang-tidy-20 clang-tools-20
sudo apt install libdumbnet-dev flex hwloc luajit openssl libssl-dev libpcap-dev libpcre2-dev pkg-config zlib1g-dev cmake autoconf autotools-dev make binutils sed gawk libtool libhwloc-dev libluajit-5.1-dev liblzma-dev
```

#### libdaq
One dependency of snort that we'll build fresh is `libdaq`.  Building is pretty straight-forward.  We specify an absolute path in `--prefix` into which the built components will be "installed" after the build completes.  The rest is basically just following the instructions from the project's README.   We use `-j $(nproc)` in the `make` command to have it use as many cores as you have on your system to speed up the build.

>All build steps assume you're starting from a directory containing the `snort3` repository and the `libdaq` repository.  We'll assume it's `/home/cisco/target`.

```bash
(
  cd libdaq/;
  ./bootstrap && \
  CC=clang-20 CXX=clang++-20 ./configure --prefix=/usr && \
  make -j $(nproc) && sudo make install
)
```
## Building our first Snort fuzzer
Building all of Snort 3 is time-consuming and wasteful when all we want to do is fuzz individual components of it to find bugs.  In this section, we'll cover creating a special fuzzer build of Snort that will only pull in necessary components of Snort and build your fuzzer.

Luckily, the Snort team has put a lot of work into making a system that allows for fuzzers to be made fairly simply.  If we start a fuzzer build using the `--enable-fuzzers` and `--enable-fuzz-sanitizer` flags, we can produce some working built-in fuzzers:
```bash
(
  cd snort3
  CC=clang CXX=clang++ ./configure_cmake.sh --enable-fuzz-sanitizer \
    --enable-fuzzers \
    --enable-address-sanitizer && \
  ( cd build; make fuzz -j $(nproc) )
)
```
Now we will see inside `snort3/build/fuzz` there is `file_olefile_fuzz` and `file_decomp_zip_fuzz`.  These are working LibFuzzer fuzzers that can be run as-is.

Let's see how they're built.

### Looking at existing fuzzers

If we search through the Snort repository for these fuzzers,
```bash
/home/cisco/target/snort3$ rg file_olefile_fuzz
...
src/decompress/fuzz/file_olefile_fuzz.cc
19:// file_olefile_fuzz.cc author Jason Crowder <jasocrow@cisco.com>

src/decompress/fuzz/CMakeLists.txt
9:add_fuzzer( file_olefile_fuzz
```
We find a C++ source file and a `CMakeLists.txt` build file.

The `CMakeLists.txt` file uses a special `add_fuzzer` function to allow us to add a fuzzer with all of the objects/source files it depends on to build.  When you aren't deeply familiar with a codebase, you'll usually figure out how to satisfy these dependencies  via trial and error by trying to build and noticing the linker errors.

The `file_olefile_fuzz.cc` file is where the fuzzer is actually implemented.  Let's take a look at that, in chunks:

First we have some include file that describe various datatypes and functions we'll use.  We found these by looking at how Snort parses OLE files.  We get compiler errors when trying to build our fuzzer until we include these.
```cpp
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "helpers/boyer_moore_search.h"
#include "../file_olefile.h"
```

Next up comes the stubs.  When we write our initial fuzzer and have satisfied the `#include` compiler errors, don't be surprised if you suddenly get a bunch of linker errors.  This means that although the compiler now knows about various functions and data types, it doesn't know where they are defined.

To get around this, a naive solution could be to just add each of the source files that define the missing functions/data types to our fuzzer's build, but then you may find that you have even *more* linker errors than before, because that source file may reference even more functions/types that we need to then add to our build.

This would go on and grow exponentially, so the better solution is to use stubs.  These are minimal implementations of functions or data types that we define to say to the linker "Hey remember that function/type I mentioned?  Here is how it's defined!"

For example, below there is the function `DetectionEngine::get_current_packet`.  We looked through how the Snort 3 OLE parser uses that function, determined that it isn't critical to how the parser runs, and had it just return a `nullptr`.  You have to be careful and do some testing though, because sometimes you'll introduce harness bugs; that is, bugs that are caused by your harness rather than the software you're fuzz-testing.  We repeated that process for all the linker errors until the linker was satisfied.
```cpp
using namespace snort;

THREAD_LOCAL const snort::Trace* vba_data_trace = nullptr;
Packet* DetectionEngine::get_current_packet() { return nullptr; }
uint8_t TraceApi::get_constraints_generation() { return 0; }
void TraceApi::filter(snort::Packet const&) { }
LiteralSearch::Handle* search_handle = nullptr;
const LiteralSearch* searcher = nullptr;
static snort::BoyerMooreSearchNoCase static_searcher((const uint8_t*)"ATTRIBUT", 8);
namespace snort
{
void trace_vprintf(const char* name, TraceLevel log_level,
    const char* trace_option, const Packet* p, const char* fmt, va_list ap) { }
}
```

This is the meat of the fuzzer.  This function uses a standard naming scheme that was started by LibFuzzer/LLVMFuzzer.  Although it's originally from LibFuzzer, it is compatible with AFL++ fuzzing as well.  Basically, input will arrive as a buffer and a size that tells the fuzzer how much data it has to work with.

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
```

The OLE fuzzer is rather simple, given that the original OLE parser defined in `src/decompress/file_olefile.cc` contains a function `oleproess` which takes in a data buffer and size just like `LLVMFuzzerTestOneInput`.

```cpp
{
    uint8_t* vba_buf = nullptr;
    uint32_t vba_buf_len = 0;
    uint32_t clamped_size = (uint32_t)size;

    if (size > UINT32_MAX)
    {
        return 0;
    }

    searcher = &static_searcher;
```
Here's where we actually call the function we're fuzzing.  It requires a pointer to another data buffer and size to output to, in case the OLE parser finds embedded VBA content to parse as well.
```cpp
    oleprocess(data, clamped_size, vba_buf, vba_buf_len);
```
Finally, we have cleanup code.  It's typical in fuzzers to have memory get allocated by whatever you're testing or to have values that are important for the each fuzzing run to get changed by the running target.  Therefore, at the end of your fuzzing run, you need to clean up by deallocating allocated memory and setting important values back to what they should be for the beginning of the next fuzzing iteration.
```cpp    

    if (vba_buf && vba_buf_len)
    {
        delete[] vba_buf;
    }

    return 0;
}
```

With that under our belts, we're ready to get our hands dirty and write another fuzzer.