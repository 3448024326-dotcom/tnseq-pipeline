#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
# EDIT THESE THREE VALUES FOR EACH SAMPLE
# ==============================================================================
INPUT_FASTQ="data/M1-5s_1.clean.fq.gz"
MAX_MISMATCHES=6
TRIM_BP=66

# ==============================================================================
# PROJECT SETTINGS: normally configured only once
# ==============================================================================
REFERENCE_GENOME="reference/Complexgenome.fna"
TARGET_SEQUENCE="GTTGTGTGACTCTGGTAACTAGAGATCCCTCAGACCCTTTTAGTCAGTGTGGAAAATCTCTAGCAG"
THREADS=4
CONDA_ENV="tnseq-pipeline"  # Set to "" when the environment is already active.
OUTPUT_ROOT="results"
MIN_MAPQ=0
EXCLUDE_SAM_FLAGS=2308  # Exclude unmapped, secondary, and supplementary alignments.

# No routine editing should be needed below this line.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPOSITORY_ROOT"

FASTQ_BASENAME="$(basename "$INPUT_FASTQ")"
SAMPLE_NAME="${FASTQ_BASENAME%.gz}"
SAMPLE_NAME="${SAMPLE_NAME%.fastq}"
SAMPLE_NAME="${SAMPLE_NAME%.fq}"
SAMPLE_NAME="${SAMPLE_NAME%.clean}"
OUTDIR="${OUTPUT_ROOT}/${SAMPLE_NAME}"

[[ -f "$INPUT_FASTQ" ]] || {
  echo "ERROR: FASTQ file not found: $INPUT_FASTQ" >&2
  exit 1
}
[[ -f "$REFERENCE_GENOME" ]] || {
  echo "ERROR: Reference genome not found: $REFERENCE_GENOME" >&2
  exit 1
}
[[ "$MAX_MISMATCHES" =~ ^[0-9]+$ ]] || {
  echo "ERROR: MAX_MISMATCHES must be a non-negative integer." >&2
  exit 2
}
[[ "$TRIM_BP" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: TRIM_BP must be a positive integer." >&2
  exit 2
}
[[ "$THREADS" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: THREADS must be a positive integer." >&2
  exit 2
}
[[ "$MIN_MAPQ" =~ ^[0-9]+$ ]] || {
  echo "ERROR: MIN_MAPQ must be a non-negative integer." >&2
  exit 2
}

if [[ -n "$CONDA_ENV" ]]; then
  command -v conda >/dev/null 2>&1 || {
    echo "ERROR: conda was not found. Activate the environment manually or set CONDA_ENV to an empty string." >&2
    exit 1
  }
  eval "$(conda shell.bash hook)"
  conda activate "$CONDA_ENV"
fi

for program in python3 cutadapt bwa samtools Rscript awk; do
  command -v "$program" >/dev/null 2>&1 || {
    echo "ERROR: Required program not found: $program" >&2
    exit 1
  }
done

mkdir -p "$OUTDIR"
FILTERED_FASTQ="$OUTDIR/${SAMPLE_NAME}.filtered.fastq.gz"
TRIMMED_FASTQ="$OUTDIR/${SAMPLE_NAME}.trimmed.fastq.gz"
SORTED_BAM="$OUTDIR/${SAMPLE_NAME}.sorted.bam"
SITE_TABLE="$OUTDIR/${SAMPLE_NAME}.sites.txt"
SITE_COUNTS="$OUTDIR/${SAMPLE_NAME}.site_counts.csv"

{
  printf "parameter\tvalue\n"
  printf "input_fastq\t%s\n" "$INPUT_FASTQ"
  printf "reference_genome\t%s\n" "$REFERENCE_GENOME"
  printf "target_sequence\t%s\n" "$TARGET_SEQUENCE"
  printf "max_mismatches\t%s\n" "$MAX_MISMATCHES"
  printf "trim_bp\t%s\n" "$TRIM_BP"
  printf "threads\t%s\n" "$THREADS"
  printf "minimum_mapq\t%s\n" "$MIN_MAPQ"
  printf "excluded_sam_flags\t%s\n" "$EXCLUDE_SAM_FLAGS"
} > "$OUTDIR/${SAMPLE_NAME}.run_config.tsv"

{
  echo "run_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "python=$(python3 --version 2>&1)"
  echo "cutadapt=$(cutadapt --version 2>&1)"
  echo "bwa=$( (bwa 2>&1 || true) | awk '/Version:/ {print $2; exit}')"
  echo "samtools=$(samtools --version | awk 'NR==1 {print $2}')"
  echo "R=$(Rscript --version 2>&1 | awk '{for (i=1; i<=NF; i++) if ($i=="version") {print $(i+1); exit}}')"
} > "$OUTDIR/${SAMPLE_NAME}.software_versions.txt"

echo "Sample: $SAMPLE_NAME"
echo "Output directory: $OUTDIR"

echo "[1/5] Filtering reads by the target sequence"
python3 "$SCRIPT_DIR/filter_fastq.py" \
  --input "$INPUT_FASTQ" \
  --output "$FILTERED_FASTQ" \
  --sequence "$TARGET_SEQUENCE" \
  --max-mismatches "$MAX_MISMATCHES"

echo "[2/5] Removing ${TRIM_BP} bp from the 5-prime end"
cutadapt -u "$TRIM_BP" -o "$TRIMMED_FASTQ" "$FILTERED_FASTQ" \
  > "$OUTDIR/${SAMPLE_NAME}.cutadapt.log"

echo "[3/5] Aligning reads and creating a coordinate-sorted BAM file"
if [[ ! -f "${REFERENCE_GENOME}.bwt" ]]; then
  echo "BWA index not found; building it now"
  bwa index "$REFERENCE_GENOME"
fi
bwa mem -t "$THREADS" "$REFERENCE_GENOME" "$TRIMMED_FASTQ" \
  | samtools sort -@ "$THREADS" -o "$SORTED_BAM" -
samtools index -@ "$THREADS" "$SORTED_BAM"

echo "[4/5] Extracting reference names and leftmost alignment positions"
samtools view -F "$EXCLUDE_SAM_FLAGS" -q "$MIN_MAPQ" "$SORTED_BAM" \
  | awk 'BEGIN {OFS="\t"} {print $3, $4}' \
  > "$SITE_TABLE"

echo "[5/5] Counting reads at each insertion site"
Rscript "$SCRIPT_DIR/count_sites.R" "$SITE_TABLE" "$SITE_COUNTS"

echo "Pipeline completed successfully."
echo "Sorted BAM: $SORTED_BAM"
echo "Site counts: $SITE_COUNTS"
