"""Verify round-trip integrity: FASTQ → uCRAM → FASTQ.

Reads the two JSON checksum files produced by checksum_fastq.py (one for the
original FASTQ input, one for the restored FASTQ output) and writes a
human-readable report.  Raises RuntimeError when any checksum does not match
so that Snakemake marks the run as failed.

Snakemake interface
-------------------
input.input_checksums    : JSON produced from original FASTQ files
input.restored_checksums : JSON produced from restored FASTQ files
input.ucram              : uCRAM file (included for reference in the report)
output[0]                : plain-text report file
log[0]                   : log file path
wildcards.sample         : sample identifier
"""

import json
import os
import sys

sys.stderr = open(snakemake.log[0], "w", buffering=1)

sample = snakemake.wildcards.sample

with open(snakemake.input.input_checksums) as fh:
    input_cs = json.load(fh)

with open(snakemake.input.restored_checksums) as fh:
    restored_cs = json.load(fh)

ucram_path = snakemake.input.ucram
ucram_size = os.path.getsize(ucram_path)

# -------------------------------------------------------
# Build report
# -------------------------------------------------------
lines = [
    f"Round-trip verification report",
    f"  Sample  : {sample}",
    f"  uCRAM   : {ucram_path}  ({ucram_size:,} bytes)",
    "",
    "Checksum comparison (MD5 over sorted read-name / sequence / quality):",
    "-" * 70,
]

all_pass = True
all_labels = sorted(set(list(input_cs.keys()) + list(restored_cs.keys())))

for label in all_labels:
    if label in input_cs and label in restored_cs:
        inp = input_cs[label]
        res = restored_cs[label]
        match = inp["checksum"] == res["checksum"]
        status = "PASS ✓" if match else "FAIL ✗"
        if not match:
            all_pass = False
        lines += [
            f"  {label}:",
            f"    original  ({inp['num_reads']:>6} reads)  {inp['checksum']}  {inp['file']}",
            f"    restored  ({res['num_reads']:>6} reads)  {res['checksum']}  {res['file']}",
            f"    result  : {status}",
            "",
        ]
    elif label in input_cs:
        lines.append(f"  {label}: present in input but MISSING from restored — FAIL ✗")
        all_pass = False
    else:
        lines.append(f"  {label}: present in restored but MISSING from input — FAIL ✗")
        all_pass = False

overall = "PASS ✓" if all_pass else "FAIL ✗"
lines += [
    "-" * 70,
    f"Overall result : {overall}",
    "",
]

report = "\n".join(lines) + "\n"

with open(snakemake.output[0], "w") as fh:
    fh.write(report)

sys.stderr.write(report)

if not all_pass:
    raise RuntimeError(
        f"Round-trip checksum verification FAILED for sample '{sample}'. "
        "See report for details."
    )

sys.stderr.write("Verification complete.\n")