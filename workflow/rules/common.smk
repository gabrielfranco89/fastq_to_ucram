# import basic packages
import pandas as pd
from snakemake.utils import validate

# read sample sheet
samples = (
    pd.read_csv(config["samplesheet"], sep="\t", dtype={"sample": str})
    .set_index("sample", drop=False)
    .sort_index()
)


# validate sample sheet and config file
validate(samples, schema="../../config/schemas/samples.schema.yaml")
validate(config, schema="../../config/schemas/config.schema.yaml")


# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def is_paired(sample: str) -> bool:
    """Return True if the sample has a second-end FASTQ file."""
    val = samples.loc[sample, "read2"]
    return pd.notna(val) and str(val).strip() != ""


def get_fastq_input(wildcards) -> dict:
    """Return a dict of named FASTQ paths for use with ``unpack()``."""
    reads = {"read1": samples.loc[wildcards.sample, "read1"]}
    if is_paired(wildcards.sample):
        reads["read2"] = samples.loc[wildcards.sample, "read2"]
    return reads


def get_restored_fastq_input(wildcards) -> dict:
    """Return restored FASTQ paths for use with ``unpack()`` in checksum_restored."""
    reads = {
        "read1": f"results/restored_fastq/{wildcards.sample}_R1.fastq.gz",
    }
    if is_paired(wildcards.sample):
        reads["read2"] = f"results/restored_fastq/{wildcards.sample}_R2.fastq.gz"
    return reads
