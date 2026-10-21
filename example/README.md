# Synthetic filtering example

`example.fastq` contains two synthetic records:

- `kept_read`: an exact match to the configured target prefix.
- `discarded_read`: more than six mismatches in the target-length prefix.

Run the filter directly from the repository root:

```bash
python3 scripts/filter_fastq.py \
  --input example/example.fastq \
  --output example/example.filtered.fastq.gz \
  --sequence GTTGTGTGACTCTGGTAACTAGAGATCCCTCAGACCCTTTTAGTCAGTGTGGAAAATCTCTAGCAG \
  --max-mismatches 6
```

The expected summary is stored in `expected_filter_summary.txt`. The generated output is intentionally ignored by Git.
