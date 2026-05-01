---
title: "Part 2: Creating Your Harness"
parent: "Day 1: Snort 3 with LibFuzzer"
nav_order: 2
---

# Creating Your Harness
##  Packet Fuzzing
- There are a lot of different types of harnesses you can choose to construct. What type of harness you make should be heavily informed by what portion of the code you are targeting. What type of data does it intake? What does it do with that data? 
- In this workshop, we'll be focusing on making a packet fuzzer for snort3's bootp service detector. 
## Examining the Target
- First, open `service_bootp.cc`
- What is the entry point? Where does the service detector start?
- As I'm sure you've noticed, the bulk of service detector's code is in the `validate` function (Line 105). It does its parsing and identification from there. It looks like a fairly complicated target, and is definitely worth fuzzing.


## Knowing the Tools
- We've included an extra library called `FuzzedDataProvider` for you. It's the simplest way to parse out data from your fuzzer into data types that you already know and love. It also helps to keep track of where you are in the byte array so you don't accidentally reuse or skip any bytes! 
- Here's the basics that you'll need for this exercise:
	- `ConsumeIntegral<T>()` — pulls `sizeof(T)` bytes and returns them as a `T` (zero-pads if short).
	- `ConsumeBool()` — pulls one byte; returns its low bit as a `bool`.
	- `ConsumeBytes<T>(n)` — returns a `std::vector<T>` of up to `n` elements (may return fewer).
## Setting up the Foundation

- The entry point for `validate` is `AppIdDiscoveryArgs`. By digging further into this, we can find that `AppIdDiscoveryArgs` is a Class composed of:

```c++
class AppIdDiscoveryArgs
{
...
    const uint8_t* data; // the data of the packet
    uint16_t size; // the declared size of the packet
    AppidSessionDirection dir; // the direction of the packet (to the client or the server)
    AppIdSession& asd; // the current session that the packet belongs to
    snort::Packet* pkt; // the packet itself
    AppidChangeBits& change_bits; // the change bits
};
```

- When it comes to creating harnesses, always try to avoid fuzzing unnecessary inputs. Think of your fuzzing data as a valuable resource that should be used only when it makes sense. For example, when constructing the packet, do you HAVE to use fuzzed IP addresses? Or can you just leave them set but zeroed out?
- Most of the setup has been done for you, but choose wisely as to how you utilize your data. If you have questions or if you're just plain not sure, please let a helper know, and they can check for you!
- Once you're done with that, add the harness to `CMakeLists.txt`. Look at how the other harnesses are added, and decide what you might need to adjust or change to your own entries to have your harness compile. Run the command below in the top directory of snort, replacing the make target with the name of the harness that you chose.

```
  CC=clang CXX=clang++ ./configure_cmake.sh --enable-fuzz-sanitizer \
    --enable-fuzzers \
    --enable-address-sanitizer && \
  ( cd build; make <NAME OF HARNESS THAT YOU PUT IN CMAKELIST>)
```

- Run it for a few minutes. If you chose your inputs right, you should be able to find a real crash in service_bootp.cc! 
