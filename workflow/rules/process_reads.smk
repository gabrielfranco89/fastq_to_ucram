####################################################################
# FASTQ -> uCRAM -> Fastq
####################################################################

## Check if the fastq's are already merged
rule merge_split_fastq:
    input:
        unpack(get_all_fastq_for_sample),
    output:
        read1="{outdir}/merged_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/merged_fastq/{sample}_R2.fastq.gz",
        tsv_piece=temp(
            "{outdir}/merged_fastq/{sample}_fastq_paths.tsv"
        )
    log:
        "{outdir}/merged_fastq/{sample}.log",
    group: "merge_split_fastq"
    shell:
        """
        echo "Merging R1 files for {wildcards.sample}" > {log}
        cat {input.read1} > {output.read1} 2>> {log}
        
        echo "Merging R2 files for {wildcards.sample}" >> {log}
        cat {input.read2} > {output.read2} 2>> {log}

        # Save the paths to the merged files for downstream rules
        echo -e "{wildcards.sample}\t{output.read1}\t{output.read2}" > {output.tsv_piece}
        """

rule create_tsv_merged_fastq:
    input:
        tsv=expand(
            "{outdir}/merged_fastq/{sample}_fastq_paths.tsv",
            sample=samples.index.unique().tolist(),
            outdir=config["outdir"]
        ),
    output:
        "{outdir}/samplesheet/updated_fastq_paths.tsv",
    shell:
        """
        echo -e "sample\tread1\tread2" > {output}
        cat {input.tsv} | sort -u >> {output}

        """


# Compute content-based checksums for input FASTQ files
# -----------------------------------------------------
def get_checksum_resources(wildcards, attempt):
    basemem=16000
    return basemem + (8000*(attempt+1))

rule checksum_input:
    input:        
        #unpack(get_fastq_updated),
        #"{outdir}/samplesheet/updated_fastq_paths.tsv",
        read1="{outdir}/merged_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/merged_fastq/{sample}_R2.fastq.gz",
    output:
        "{outdir}/checksums/{sample}.input.json",
    log:
        "{outdir}/logs/checksum/{sample}.input.log",
    conda:
        "../envs/samtools.yaml"
    resources:
        mem_mb=get_checksum_resources
    group: "checksum_input"
    message:
        """--- Computing checksums for input FASTQ: {wildcards.sample}"""
    script:
        "../scripts/checksum_fastq.py"


def get_mem_resources(wildcards, attempt):
    basemem=32000
    return basemem + (8000*(attempt+1))

# Convert FASTQ files to unaligned CRAM (uCRAM) format
# -----------------------------------------------------
rule fastq_to_ucram:
    input:
        read1="{outdir}/merged_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/merged_fastq/{sample}_R2.fastq.gz",
    output:
        ucram="{outdir}/ucram/{sample}.ucram",
    log:
        "{outdir}/logs/fastq_to_ucram/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    group: "fastq_to_ucram"
    message:
        """--- Converting FASTQ to uCRAM: {wildcards.sample}"""
    resources:
        mem_mb=get_mem_resources
    run:
        if "read2" in dict(input):
            shell(
                "samtools import "
                "-1 {input.read1} -2 {input.read2} "
                "-O cram,no_ref=1,version=3.0 "
                "-o {output.ucram} "
                "2> {log}"
            )
        else:
            shell(
                "samtools import "
                "-0 {input.read1} "
                "-O cram,no_ref=1,version=3.0 "
                "-o {output.ucram} "
                "2> {log}"
            )

rule ucram_to_fastq:
    input:
        ucram=rules.fastq_to_ucram.output.ucram,
    output:
        read1="{outdir}/restored_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/restored_fastq/{sample}_R2.fastq.gz",
    log:
        "{outdir}/logs/ucram_to_fastq/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Converting uCRAM back to FASTQ: {wildcards.sample}"""
    group: "ucram_to_fastq"
    resources:
        mem_mb=get_mem_resources
    shell:
        """
        samtools fastq \
        -1 {output.read1} -2 {output.read2} \
        -0 /dev/null -s /dev/null \
        --threads {threads} \
        -N {input.ucram} \
        2> {log}
        """

rule checksum_restored:
    input:
        read1="{outdir}/restored_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/restored_fastq/{sample}_R2.fastq.gz",
    output:
        "{outdir}/checksums/{sample}.restored.json",
    log:
        "{outdir}/logs/checksum/{sample}.restored.log",
    conda:
        "../envs/samtools.yaml"
    group: "checksum_restored"
    message:
        """--- Computing checksums for restored FASTQ: {wildcards.sample}"""
    resources:
        mem_mb=get_checksum_resources
    script:
        "../scripts/checksum_fastq.py"

    

rule verify_roundtrip:
    input:
        input_checksums="{outdir}/checksums/{sample}.input.json",
        restored_checksums="{outdir}/checksums/{sample}.restored.json",
        ucram=rules.fastq_to_ucram.output.ucram,
    output:
        report="{outdir}/verify/{sample}_roundtrip.txt",
    log:
        "{outdir}/logs/verify/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    group: "verify_roundtrip"
    message:
        """--- Verifying round-trip integrity: {wildcards.sample}"""
    script:
        "../scripts/verify_roundtrip.py"
    