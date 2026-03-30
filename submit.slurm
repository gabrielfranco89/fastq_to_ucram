#!/bin/bash
#SBATCH --job-name=snakemake_run
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=logs/snakemake_%j.out
#SBATCH --error=logs/snakemake_%j.err

ml 2025
#ml Miniconda3/25.5.1-1 

cd $SLURM_SUBMIT_DIR

snakemake -p \
  --profile config/snellius/ \
  --use-singularity \
  --singularity-args "--bind $(pwd):$(pwd)" \
  --singularity-prefix /gpfs/work2/0/brugada/not_gabriel/singularity_cache \
