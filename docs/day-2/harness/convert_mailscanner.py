#!/usr/bin/env python3
"""Convert the mailscanner ELF executable into a shared library to prep it for fuzzing

Usage: python3 convert_mailscanner.py <input> <output>
"""
import sys
import lief

src, dst = sys.argv[1], sys.argv[2]
binary = lief.parse(src)

# Change ELF type from EXEC to DYN so we can dlopen it
binary.header.file_type = lief.ELF.Header.FILE_TYPE.DYN

# Remove NEEDED entries for unnecessary libs.
# The MIME/SMTP parsing code only calls libc/stdlib functions (until proven otherwise)
keep = {"libc.so.6", "ld-linux.so.2", "libdl.so.2", "libm.so.6",
        "libpthread.so.0", "libgcc_s.so.1", "libstdc++.so.6"}
for entry in list(binary.dynamic_entries):
    if entry.tag == lief.ELF.DynamicEntry.TAG.NEEDED:
        if entry.name not in keep:
            binary.remove_library(entry.name)

# Remove symbol version tables (they reference the removed libs)
for entry in binary.dynamic_entries:
    if entry.tag in (lief.ELF.DynamicEntry.TAG.VERSYM,
                     lief.ELF.DynamicEntry.TAG.VERNEED,
                     lief.ELF.DynamicEntry.TAG.VERNEEDNUM):
        entry.tag = lief.ELF.DynamicEntry.TAG.NULL

binary.write(dst)
print(f"  Wrote {dst}")
