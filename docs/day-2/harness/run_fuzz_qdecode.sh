#!/bin/bash
# Fuzz the Sophos mailscanner Qdecode function with CMPLOG.
# Finds a heap buffer overflow within seconds.
set -euo pipefail
cd "$(dirname "$0")"

[ -f harness_qdecode ] || { echo "Run ./setup.sh first"; exit 1; }

# Instrument only mailscanner code, not libc or the harness.
# Range from: readelf -l mailscanner | grep "LOAD.*R E" -> 0x08048000, size 0x291968
# 0x08048000 + 0x291968 = 0x082d9968, rounded up to page: 0x082da000
export AFL_QEMU_INST_RANGES=0x08048000-0x082da000
# Coverage bitmap size. 65536 (default) is fine for a single function target.
export AFL_MAP_SIZE=65536

exec afl-fuzz \
    -Q \
    -c 0 \
    -i corpus_qdecode \
    -o findings_qdecode \
    -x dict/qdecode.dict \
    -t 500 \
    -m none \
    -- ./harness_qdecode @@
