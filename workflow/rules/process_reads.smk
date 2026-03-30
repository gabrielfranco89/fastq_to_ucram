# ----------------------------------------------------- #
# FASTQ → uCRAM → FASTQ round-trip pipeline            #
# ----------------------------------------------------- #


# Compute content-based checksums for input FASTQ files
# -----------------------------------------------------
rule checksum_input:
    input:
        unpack(get_fastq_input),
    output:
        "results/checksums/{sample}.input.json",
    log:
        "results/logs/checksum/{sample}.input.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Computing checksums for input FASTQ: {wildcards.sample}"""
    script:
        "../scripts/checksum_fastq.py"


# Convert FASTQ files to unaligned CRAM (uCRAM) format
# -----------------------------------------------------
rule fastq_to_ucram:
    input:
        unpack(get_fastq_input),
    output:
        ucram="results/ucram/{sample}.cram",
    log:
        "results/logs/fastq_to_ucram/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Converting FASTQ to uCRAM: {wildcards.sample}"""
    run:
        if "read2" in dict(input):
            shell(
                "samtools import "
                "-1 {input.read1} -2 {input.read2} "
                "-O cram,no_ref=1 "
                "-o {output.ucram} "
                "2> {log}"
            )
        else:
            shell(
                "samtools import "
                "-0 {input.read1} "
                "-O cram,no_ref=1 "
                "-o {output.ucram} "
                "2> {log}"
            )


# Convert uCRAM back to FASTQ
# -----------------------------------------------------
rule ucram_to_fastq:
    input:
        ucram=rules.fastq_to_ucram.output.ucram,
    output:
        read1="results/restored_fastq/{sample}_R1.fastq.gz",
        read2="results/restored_fastq/{sample}_R2.fastq.gz",
    log:
        "results/logs/ucram_to_fastq/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Converting uCRAM back to FASTQ: {wildcards.sample}"""
    run:
        if is_paired(wildcards.sample):
            shell(
                "samtools fastq "
                "-1 {output.read1} -2 {output.read2} "
                "-0 /dev/null -s /dev/null "
                "-N {input.ucram} "
                "2> {log}"
            )
        else:
            shell(
                "samtools fastq "
                "-0 {output.read1} "
                "-N {input.ucram} "
                "2> {log}"
            )
            shell("gzip -c /dev/null > {output.read2}")


# Compute content-based checksums for restored FASTQ files
# ---------------------------------------------------------
rule checksum_restored:
    input:
        unpack(get_restored_fastq_input),
    output:
        "results/checksums/{sample}.restored.json",
    log:
        "results/logs/checksum/{sample}.restored.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Computing checksums for restored FASTQ: {wildcards.sample}"""
    script:
        "../scripts/checksum_fastq.py"


# Verify round-trip integrity and write report
# ---------------------------------------------------------
rule verify_roundtrip:
    input:
        input_checksums="results/checksums/{sample}.input.json",
        restored_checksums="results/checksums/{sample}.restored.json",
        ucram=rules.fastq_to_ucram.output.ucram,
    output:
        report="results/verify/{sample}_roundtrip.txt",
    log:
        "results/logs/verify/{sample}.log",
    conda:
        "../envs/samtools.yaml"
    message:
        """--- Verifying round-trip integrity: {wildcards.sample}"""
    script:
        "../scripts/verify_roundtrip.py"
