---
title: "Bonus: Parking Game Fuzzer"
nav_order: 4
permalink: /parking_game/
---

# Parking Game Fuzzer Tutorial

This is a simple parking game fuzzer tutorial. It finds solutions to parking games by generating random moves and checking if the game is solved.

Your goal is to modify fuzz_target.cpp to find solutions. The fuzzer will generate an array of bytes, where each pair of bytes represents a car index and a direction. You need to use these bytes to make moves on the board. Make use of the `board.shift_car()` method to make moves. Return 0 if the move is invalid, otherwise continue.



## Build on mac

requires llvm to be installed `brew install llvm`

```
make pg_fuzz  CXX=$(brew --prefix llvm)/bin/clang++
```

## Running fuzzer

```
PG_MAP=maps/tokyo1.map ./pg_fuzz -runs=0 -use_value_profile=1 -max_len=128 corpus/
```

ft should increase over time until if finds a crash. The crash is a solution to the parking game.