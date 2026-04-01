## Workflow overview

The workflow is built using [snakemake](https://snakemake.readthedocs.io/en/stable/) and consists of the following steps:

1. Create checksums for fastq files
2. Transform fastq files to unmapped CRAMs (uCRAM)
3. Decompress uCRAMs back to fastq to check if the reads are the same as original
4. Report if they match
5. (Optional) Run a fastqc/multiqc on reads

## Running the workflow

### Input data

The input files should be listed on `config.yaml` under `samplesheet`
The sample sheet has the following layout:

| sample  | group | | lane |  replicate | read1                      | read2                      |
| ------- | --------- | ------- | --------- | -------------------------- | -------------------------- |
| sample1 | S1 | L001 | 001        | sample1.read1.fastq.gz | sample1.read2.fastq.gz |
| sample2 | S1 | L002 | 001       | sample2.read1.fastq.gz | sample2.read2.fastq.gz |

### Parameters

This table lists all parameters that can be used to run the workflow.

| parameter          | type | details                               | default                        |
| ------------------ | ---- | ------------------------------------- | ------------------------------ |
| **samplesheet**    |      |                                       |                                |
| path               | str  | path to samplesheet, mandatory        | "config/samples.tsv"           |
| **get_genome**     |      |                                       |                                |
| outdir           | str  | path to where it should be write the results, mandatory |  |
