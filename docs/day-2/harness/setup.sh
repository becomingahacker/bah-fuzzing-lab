#!/bin/bash
# Setup: converts the mailscanner executable into a fuzzable shared library,
# builds stub symbols, compiles harnesses, creates seed corpus, and creates fuzzing dictionary.
#
# Usage: ./setup.sh <path-to-firmware-rootfs>
#
# In the lab, you can use $ROOT, which will already be set to the firmware rootfs.

set -euo pipefail

ROOT="${1:?Usage: $0 <path-to-sfos-rootfs>}"
[ -f "$ROOT/bin/mailscanner" ] || { echo "Not an SFOS rootfs (no bin/mailscanner): $ROOT"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Step 1: Convert mailscanner to a shared library with LIEF ==="

cp "$ROOT/bin/mailscanner" ./mailscanner.orig
python3 "$SCRIPT_DIR/convert_mailscanner.py" ./mailscanner.orig ./mailscanner.so
rm -f mailscanner.orig

echo "  Verifying target functions are exported..."
for sym in mime_content_type_new_from_string mime_content_type_destroy \
           Qdecode mime_disposition_new mime_disposition_destroy log_level; do
    addr=$(nm -D mailscanner.so 2>/dev/null | grep " [TBD] ${sym}$" | awk '{print $1}')
    if [ -n "$addr" ]; then
        printf "    %-45s 0x%s\n" "$sym" "$addr"
    else
        echo "    WARNING: $sym not found in exports"
    fi
done

echo ""
echo "=== Step 2: Build stubs for unresolved external symbols ==="

nm -D "$ROOT/bin/mailscanner" | grep " U " | \
    grep -v "@GLIBC\|@GCC\|@CXXABI\|@GLIBCXX" | \
    awk '{print $2}' | sed 's/@.*//' | sort -u > /tmp/stub_syms.txt

{
echo "/* Auto-generated stubs for mailscanner external symbols */"
while read sym; do
    echo "void *${sym} = (void*)0;"
done < /tmp/stub_syms.txt
} > stubs.c

clang -m32 -shared -o stubs.so stubs.c
echo "  Built stubs.so ($(wc -l < /tmp/stub_syms.txt) symbols)"
rm -f /tmp/stub_syms.txt

echo ""
echo "=== Step 3: Build harnesses ==="

echo "  Building harness_ct (mime_content_type_new_from_string)..."
clang -m32 -g -O2 -o harness_ct harness_ct.c -ldl

echo "  Building harness_qdecode..."
clang -m32 -g -O2 -o harness_qdecode harness_qdecode.c -ldl

echo ""
echo "=== Step 4: Generating starter seeds ==="

mkdir -p corpus_ct corpus_qdecode

# mime_content_type_new_from_string corpus
echo -n 'text/plain' > corpus_ct/text_plain.txt
echo -n 'text/html; charset=utf-8' > corpus_ct/html_charset.txt
echo -n 'multipart/mixed; boundary="----=_Part_123"' > corpus_ct/multipart.txt
echo -n 'application/octet-stream; name="file.exe"' > corpus_ct/attachment.txt
echo -n 'text/html; charset=UTF-8; boundary=b1; name=test' > corpus_ct/all_params.txt
echo -n 'multipart/alternative; boundary=unique-boundary-1' > corpus_ct/alt.txt
echo -n 'text/html; charset="iso-8859-1"' > corpus_ct/quoted_charset.txt
echo -n 'message/rfc822' > corpus_ct/message.txt
echo -n 'text/html; boundary="test\"escaped"' > corpus_ct/escaped.txt
echo -n 'text/html; charset=' > corpus_ct/empty_val.txt
printf 'multipart/mixed;\r\n\tboundary="----=_Part"' > corpus_ct/folded.txt

# Qdecode corpus
echo -n 'Hello =41=42=43 World' > corpus_qdecode/basic.txt
echo -n '=48=65=6C=6C=6F' > corpus_qdecode/all_hex.txt
echo -n 'No encoding here' > corpus_qdecode/plain.txt
echo -n '=4' > corpus_qdecode/truncated.txt
echo -n '=GG=ZZ' > corpus_qdecode/invalid_hex.txt
echo -n '=0D=0A=20' > corpus_qdecode/whitespace.txt
echo -n '=00=01=FF=FE' > corpus_qdecode/binary.txt

echo "  corpus_ct:      $(ls corpus_ct/ | wc -l) seeds"
echo "  corpus_qdecode: $(ls corpus_qdecode/ | wc -l) seeds"

echo ""
echo "=== Step 5: Create dictionaries ==="

mkdir -p dict

cat > dict/mime.dict << 'DICT'
"text"
"html"
"plain"
"multipart"
"mixed"
"alternative"
"application"
"octet-stream"
"message"
"rfc822"
"image"
"charset"
"boundary"
"name"
"filename"
"utf-8"
"iso-8859-1"
"/"
";"
"="
"\""
"\\\""
DICT

cat > dict/qdecode.dict << 'DICT'
"="
"=3D"
"=0D"
"=0A"
"=0D=0A"
"=20"
"=00"
"=FF"
"=41"
"=4"
"=="
"=GG"
DICT

echo ""
echo "=== Step 6: Running sanity check ==="

echo -n "  harness_ct:      "
if ./harness_ct corpus_ct/text_plain.txt 2>/dev/null; then
    echo "OK"
else
    echo "FAIL (exit $?)"
    exit 1
fi

echo -n "  harness_qdecode: "
if ./harness_qdecode corpus_qdecode/basic.txt 2>/dev/null; then
    echo "OK"
else
    echo "FAIL (exit $?)"
    exit 1
fi

echo ""
echo "Setup complete. Run:"
echo "  ./run_fuzz_qdecode.sh       # fuzz Qdecode"
echo "  ./run_fuzz_ct.sh            # fuzz Content-Type parser"
echo "  ./run_fuzz_qdecode_qasan.sh  # fuzz Qdecode with QASan memory checking"
echo "  ./run_fuzz_ct_qasan.sh      # fuzz Content-Type with QASan memory checking"
