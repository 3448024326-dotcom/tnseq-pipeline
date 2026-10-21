# Tn-seq Processing Pipeline

This pipeline filters Tn-seq reads by a target sequence, trims the 5-prime end, aligns the retained reads to a reference genome, and counts reads at candidate insertion sites.

## System Requirements

### Software dependencies

- Python == 3.11.15
- cutadapt == 5.2
- BWA == 0.7.19
- samtools == 1.23.1
- htslib == 1.23.1
- R == 4.5.2

### Operating system

- Linux with Bash

## Installation

Create the conda environment from `environment.yml`:

```bash
conda env create -f environment.yml
conda activate tnseq-pipeline
```

## Instructions

1. Place the input FASTQ file and reference genome in the desired directories.

2. Open `scripts/run_tnseq.sh` and edit the following three values for each sample:

```bash
INPUT_FASTQ="data/M1-5s_1.clean.fq.gz"
MAX_MISMATCHES=6
TRIM_BP=66
```

3. Set the reference genome path in `scripts/run_tnseq.sh` if necessary:

```bash
REFERENCE_GENOME="reference/Complexgenome.fna"
```

4. Run the pipeline from the repository directory:

```bash
bash scripts/run_tnseq.sh
```

## Output

Results are written to `results/<sample_name>/`:

- Filtered FASTQ file
- Trimmed FASTQ file
- cutadapt log
- Coordinate-sorted BAM file and index
- Insertion-site coordinate table
- Insertion-site read-count table
- Run configuration and software-version records

The sample name is generated automatically from the FASTQ filename. For example, `M1-5s_1.clean.fq.gz` is reported as `M1-5s_1`.
