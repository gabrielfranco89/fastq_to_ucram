rule fastqc:
    input:
        read1="{outdir}/merged_fastq/{sample}_R1.fastq.gz",
        read2="{outdir}/merged_fastq/{sample}_R2.fastq.gz",
    output:
        html1="{outdir}/qc/fastqc/{sample}_R1_fastqc.html",
        zip1="{outdir}/qc/fastqc/{sample}_R1_fastqc.zip",
        html2="{outdir}/qc/fastqc/{sample}_R2_fastqc.html",
        zip2="{outdir}/qc/fastqc/{sample}_R2_fastqc.zip",
    log:
        "{outdir}/logs/fastqc/{sample}.log",
    conda:
        "../envs/qc.yaml"
    message:
        """--- Running FastQC on merged FASTQ: {wildcards.sample}"""
    group: "fastqc"
    params:
        outdir=config["outdir"]
    threads: 4
    shell:
        """
        mkdir -p {params.outdir}/logs/fastqc
        mkdir -p {params.outdir}/qc/fastqc
        fastqc \
        -f fastq \
        --threads {threads} \
        --outdir {params.outdir}/qc/fastqc \
        {input.read1} {input.read2} \
        2> {log}
        """

rule multiqc:
    input:
        expand("{outdir}/qc/fastqc/{sample}_R1_fastqc.html", sample=samples.index, outdir=config["outdir"]),
        expand("{outdir}/qc/fastqc/{sample}_R2_fastqc.html", sample=samples.index, outdir=config["outdir"]),
    output:
        html="{outdir}/qc/multiqc/multiqc_report.html"
    log:
        "{outdir}/logs/multiqc/multiqc.log"
    conda:
        "../envs/qc.yaml"
    message:
        """--- Running MultiQC on FastQC reports ---"""
    params:
        outdir=config["outdir"]
    shell:
        """
        mkdir -p {params.outdir}/qc/multiqc
        mkdir -p {params.outdir}/logs/multiqc
        multiqc \
        --force \
        --outdir {params.outdir}/qc/multiqc \
        {params.outdir}/qc/fastqc \
        2> {log}
        """