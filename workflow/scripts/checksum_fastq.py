"""Compute content-based checksums for FASTQ file(s).

Normalises FASTQ records so that:
- Reads are sorted by name (handles re-ordering between input and restored files)
- The '+' separator line is ignored (samtools fastq may omit the read name there)
- Both plain and gzip-compressed FASTQ files are accepted

Snakemake interface
-------------------
input  : named FASTQ paths, e.g. read1="...", read2="..."  (read2 is optional)
output : a single JSON file that maps each read-group label to its checksum
log    : log file path
"""

import gzip
import hashlib
import json
import sys

sys.stderr = open(snakemake.log[0], "w", buffering=1)


def read_fastq_records(filepath: str) -> dict:
    """Return a dict mapping read-ID → (sequence, quality) for every record."""
    records: dict = {}
    opener = gzip.open if filepath.endswith(".gz") else open
    try:
        with opener(filepath, "rt") as fh:
            while True:
                header = fh.readline()
                if not header:
                    break
                seq = fh.readline().strip()
                fh.readline()  # skip '+' line
                qual = fh.readline().strip()
                if not seq:
                    continue
                # Normalise read name: strip '@' prefix and everything after the
                # first whitespace, then strip /1 or /2 pair suffixes so that
                # original and restored reads map to the same key.
                read_id = header.strip().lstrip("@").split()[0]
                if read_id.endswith(("/1", "/2")):
                    read_id = read_id[:-2]
                records[read_id] = (seq, qual)
    except EOFError:
        pass  # truncated gzip (e.g. empty placeholder file) – just return what we have
    return records


def compute_checksum(records: dict) -> str:
    """Return an MD5 hex digest over records sorted by read name."""
    h = hashlib.md5()
    for name in sorted(records.keys()):
        seq, qual = records[name]
        h.update(f"{name}\t{seq}\t{qual}\n".encode())
    return h.hexdigest()


# -----------------------------------------------------------------
# Main
# -----------------------------------------------------------------
checksums: dict = {}

for label, filepath in snakemake.input.items():
    sys.stderr.write(f"Processing {label}: {filepath}\n")
    records = read_fastq_records(filepath)
    checksum = compute_checksum(records)
    checksums[label] = {
        "file": filepath,
        "num_reads": len(records),
        "checksum": checksum,
    }
    sys.stderr.write(f"  reads    : {len(records)}\n")
    sys.stderr.write(f"  checksum : {checksum}\n")

with open(snakemake.output[0], "w") as fh:
    json.dump(checksums, fh, indent=2)

sys.stderr.write("Checksum computation complete.\n")