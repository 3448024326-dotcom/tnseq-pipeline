#!/usr/bin/env python3
"""Unit tests for scripts/filter_fastq.py."""

import gzip
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
FILTER_SCRIPT = REPOSITORY_ROOT / "scripts" / "filter_fastq.py"
TARGET = "GTTGTGTGACTCTGGTAACTAGAGATCCCTCAGACCCTTTTAGTCAGTGTGGAAAATCTCTAGCAG"


class FilterFastqTest(unittest.TestCase):
    def test_plain_input_and_gzip_output(self) -> None:
        kept_sequence = TARGET + "ACGT"
        rejected_sequence = "A" * len(TARGET) + "ACGT"
        records = (
            f"@kept\n{kept_sequence}\n+\n{'I' * len(kept_sequence)}\n"
            f"@rejected\n{rejected_sequence}\n+\n{'I' * len(rejected_sequence)}\n"
        )

        with tempfile.TemporaryDirectory() as temporary_directory:
            input_path = Path(temporary_directory) / "input.fastq"
            output_path = Path(temporary_directory) / "output.fastq.gz"
            input_path.write_text(records, encoding="utf-8")

            completed = subprocess.run(
                [
                    sys.executable,
                    str(FILTER_SCRIPT),
                    "--input",
                    str(input_path),
                    "--output",
                    str(output_path),
                    "--sequence",
                    TARGET,
                    "--max-mismatches",
                    "6",
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertIn("total=2, kept=1", completed.stdout)
            with gzip.open(output_path, "rt") as filtered:
                output = filtered.read()
            self.assertIn("@kept", output)
            self.assertNotIn("@rejected", output)

    def test_rejects_malformed_quality_length(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            input_path = Path(temporary_directory) / "bad.fastq"
            output_path = Path(temporary_directory) / "output.fastq"
            input_path.write_text(f"@bad\n{TARGET}\n+\nIII\n", encoding="utf-8")

            completed = subprocess.run(
                [
                    sys.executable,
                    str(FILTER_SCRIPT),
                    "-i",
                    str(input_path),
                    "-o",
                    str(output_path),
                    "-s",
                    TARGET,
                ],
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("Sequence and quality lengths differ", completed.stderr)


if __name__ == "__main__":
    unittest.main()
