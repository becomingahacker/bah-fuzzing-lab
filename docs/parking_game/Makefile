CXX      ?= clang++
CXXFLAGS ?= -std=c++17 -g -O1 -Wall -Wextra
PG_MAP   ?= maps/tokyo1.map

.PHONY: all test fuzz coverage clean

all: pg_tests pg_fuzz

pg_tests: tests.cpp parking_game.hpp map_parser.hpp
	$(CXX) $(CXXFLAGS) tests.cpp -o $@

pg_fuzz: fuzz_target.cpp parking_game.hpp map_parser.hpp
	$(CXX) $(CXXFLAGS) -fsanitize=fuzzer,address fuzz_target.cpp -o $@

# Coverage-instrumented build of the harness, used by the `coverage` target
# below to inspect what the fuzzer is (or isn't) reaching in parking_game.hpp.
pg_fuzz_cov: fuzz_target.cpp parking_game.hpp map_parser.hpp
	$(CXX) $(CXXFLAGS) -fsanitize=fuzzer,address \
		-fprofile-instr-generate -fcoverage-mapping \
		fuzz_target.cpp -o $@

test: pg_tests
	./pg_tests

fuzz: pg_fuzz
	PG_MAP=$(PG_MAP) ./pg_fuzz -max_len=256 corpus/

# Replay every input in corpus/ through a coverage-instrumented build and
# print an llvm-cov line-coverage report for parking_game.hpp. Requires the
# `llvm` apt package on Ubuntu (for llvm-profdata / llvm-cov).
coverage: pg_fuzz_cov
	rm -f fuzz_*.profraw pg.profdata
	PG_MAP=$(PG_MAP) LLVM_PROFILE_FILE="fuzz_%m.profraw" \
		./pg_fuzz_cov -runs=0 corpus/
	llvm-profdata merge -sparse fuzz_*.profraw -o pg.profdata
	llvm-cov report ./pg_fuzz_cov -instr-profile=pg.profdata parking_game.hpp

clean:
	rm -f pg_tests pg_fuzz pg_fuzz_cov pg.profdata
	rm -rf corpus crash-* leak-* oom-* fuzz_*.profraw
