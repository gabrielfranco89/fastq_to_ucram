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


def is_paired(sample: str) -> bool:
    """Return True if the sample has a second-end FASTQ file."""
    val = samples.loc[sample, "read2"]
    return pd.notna(val) and str(val).strip() != ""


# Reading functions
def get_fastq_input(wildcards) -> dict:
    "Return a dict of names containing the group, lane, and paths to the fastq files for a given sample."
    reads = {
        "read1": samples.loc[wildcards.sample, "read1"],
        "read2": samples.loc[wildcards.sample, "read2"],
        "group": samples.loc[wildcards.sample, "group"],
        "lane": samples.loc[wildcards.sample, "lane"],
        "replicate": samples.loc[wildcards.sample, "replicate"],
    }    
    return reads


def get_all_fastq_for_sample(wildcards) -> dict:
    """Return lists of all read1/read2 files for a given sample across all groups/lanes."""
    sample_data = samples.loc[[wildcards.sample]]  # Double brackets = DataFrame
    
    read1_files = sample_data["read1"].tolist()
    read2_files = sample_data["read2"].tolist()
    
    return {
        "read1": read1_files,
        "read2": read2_files,
    }

def get_fastq_updated(wildcards) -> dict:
    # read sample sheet
    samples_updated = (
        pd.read_csv(f"{config['outdir']}/samplesheet/updated_fastq_paths.tsv", sep="\t", dtype={"sample": str})
        .set_index("sample", drop=False)
        .sort_index()
    )

    out = {
        "read1": samples_updated.loc[wildcards.sample, "read1"],
        "read2": samples_updated.loc[wildcards.sample, "read2"],
    }
    return out

def get_restored_fastq_input(wildcards) -> dict:
    """Return restored FASTQ paths for use with ``unpack()`` in checksum_restored."""
    reads = {
        "read1": f"{config['outdir']}/restored_fastq/{wildcards.sample}_R1.fastq.gz",
        "read2": f"{config['outdir']}/restored_fastq/{wildcards.sample}_R2.fastq.gz",
    }
    return reads
