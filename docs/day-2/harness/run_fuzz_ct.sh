#!/bin/bash
# Fuzz the Sophos mailscanner MIME Content-Type parser with CMPLOG.
# CMPLOG learns the "boundary", "charset", "name" strings from comparisons
# and injects them into the input, greatly improving exploration.
set -euo pipefail
cd "$(dirname "$0")"

[ -f harness_ct ] || { echo "Run ./setup.sh first"; exit 1; }

# Instrument range from: readelf -l mailscanner | grep "LOAD.*R E"
# 0x08048000 + 0x291968 = 0x082d9968, rounded to page: 0x082da000
export AFL_QEMU_INST_RANGES=0x08048000-0x082da000
export AFL_MAP_SIZE=65536

exec afl-fuzz \
    -Q \
    -c 0 \
    -i corpus_ct \
    -o findings_ct \
    -x dict/mime.dict \
    -t 500 \
    -m none \
    -- ./harness_ct @@
