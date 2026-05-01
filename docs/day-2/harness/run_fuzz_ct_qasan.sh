#!/bin/bash
# Fuzz the Content-Type parser with QASan (QEMU AddressSanitizer).
# Catches heap buffer overflows that don't necessarily SIGSEGV.
#
# Requires: libqasan.so built for i386 in the AFL++ directory.
#   cd AFLplusplus/qemu_mode/libqasan
#   CC="clang -m32" make
set -euo pipefail
cd "$(dirname "$0")"

[ -f harness_ct ] || { echo "Run ./setup.sh first"; exit 1; }

# Find AFL++ directory (adjust if your install is elsewhere)
AFL_DIR="${AFL_PATH:-}"
if [ -z "$AFL_DIR" ]; then
    for d in ~/workspace/AFLplusplus /usr/local/lib/afl /usr/lib/afl; do
        if [ -f "$d/libqasan.so" ]; then
            AFL_DIR="$d"
            break
        fi
    done
fi

if [ -z "$AFL_DIR" ] || [ ! -f "$AFL_DIR/libqasan.so" ]; then
    echo "Cannot find libqasan.so. Set AFL_PATH to your AFL++ build directory."
    echo "Build it with: cd AFLplusplus/qemu_mode/libqasan && CC='clang -m32' make"
    exit 1
fi

export AFL_PATH="$AFL_DIR"
export AFL_USE_QASAN=1
# Instrument range from: readelf -l mailscanner | grep "LOAD.*R E"
# 0x08048000 + 0x291968 = 0x082d9968, rounded to page: 0x082da000
export AFL_QEMU_INST_RANGES=0x08048000-0x082da000
export AFL_MAP_SIZE=65536

exec afl-fuzz \
    -Q \
    -i corpus_ct \
    -o findings_ct_qasan \
    -x dict/mime.dict \
    -t 2000 \
    -m none \
    -- ./harness_ct @@
