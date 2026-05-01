#!/bin/bash
# Links mailscanner.so and stubs.so from the harness/ directory.
# Run ../harness/setup.sh first!
set -euo pipefail
cd "$(dirname "$0")"

HARNESS_DIR="../harness"

for f in mailscanner.so stubs.so; do
    if [ ! -f "$HARNESS_DIR/$f" ]; then
        echo "ERROR: $HARNESS_DIR/$f not found. Run $HARNESS_DIR/setup.sh first."
        exit 1
    fi
    ln -sf "$HARNESS_DIR/$f" .
done

echo "Linked mailscanner.so and stubs.so"
echo ""
echo "Next steps:"
echo "  1. Edit harness_exercise.c (fill in the TODOs)"
echo "  2. clang -m32 -g -O2 -o harness_exercise harness_exercise.c -ldl"
echo "  3. ./harness_exercise corpus_exercise/attachment.txt   # sanity check"
echo "  4.  Run afl-showmap to test AFL++ QEMU mode instrumentation works."
echo "  4. ./run_fuzz_exercise.sh                              # fuzz it"
