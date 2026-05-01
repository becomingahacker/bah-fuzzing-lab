#!/bin/bash
# Fuzz the exercise harness (Content-Disposition parser) with CMPLOG.
set -euo pipefail
cd "$(dirname "$0")"

[ -f harness_exercise ] || {
    echo "Compile first: clang -m32 -g -O2 -o harness_exercise harness_exercise.c -ldl"
    exit 1
}

# Instrument range from: readelf -l mailscanner | grep "LOAD.*R E"
# 0x08048000 + 0x291968 = 0x082d9968, rounded to page: 0x082da000
export AFL_QEMU_INST_RANGES=0x08048000-0x082da000

exec afl-fuzz \
    -Q \
    -c 0 \
    -i corpus_exercise \
    -o findings_exercise \
    -x dict/disposition.dict \
    -t 500 \
    -m none \
    -- ./harness_exercise @@
