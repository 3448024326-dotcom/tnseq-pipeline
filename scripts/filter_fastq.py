#!/usr/bin/env python3
"""Keep FASTQ reads whose prefix matches a target sequence within a mismatch limit."""

import argparse
import gzip
from pathlib import Path
from typing import TextIO


def open_text(path: Path, mode: str) -> TextIO:
    """Open plain-text or gzip-compressed files in text mode."""
    if path.name.endswith(".gz"):
        return gzip.open(path, mode + "t")
    return path.open(mode, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--input", required=True, type=Path, help="Input FASTQ or FASTQ.GZ file")
    parser.add_argument("-o", "--output", required=True, type=Path, help="Output FASTQ or FASTQ.GZ file")
    parser.add_argument("-s", "--sequence", required=True, help="Target sequence expected at the read start")
    parser.add_argument(
        "-m",
        "--max-mismatches",
        type=int,
        default=6,
        help="Maximum allowed mismatches (default: 6)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    target = args.sequence.upper()

    if not target:
        raise SystemExit("ERROR: The target sequence cannot be empty.")
    if args.max_mismatches < 0:
        raise SystemExit("ERROR: The mismatch limit cannot be negative.")
    if not args.input.is_file():
        raise SystemExit(f"ERROR: Input file not found: {args.input}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    kept = 0

    with open_text(args.input, "r") as source, open_text(args.output, "w") as sink:
        while True:
            header = source.readline()
            if not header:
                break

            sequence = source.readline()
            plus = source.readline()
            quality = source.readline()
            if not (sequence and plus and quality):
                raise SystemExit("ERROR: The final FASTQ record is incomplete.")
            if not header.startswith("@") or not plus.startswith("+"):
                raise SystemExit(f"ERROR: FASTQ record {total + 1} is malformed.")
            if len(sequence.rstrip("\r\n")) != len(quality.rstrip("\r\n")):
                raise SystemExit(f"ERROR: Sequence and quality lengths differ in FASTQ record {total + 1}.")

            total += 1
            read_prefix = sequence.strip().upper()[: len(target)]
            if len(read_prefix) != len(target):
                continue

            mismatches = sum(a != b for a, b in zip(target, read_prefix))
            if mismatches <= args.max_mismatches:
                sink.writelines((header, sequence, plus, quality))
                kept += 1

    if total:
        print(f"FASTQ filtering completed: total={total:,}, kept={kept:,}, fraction={kept / total:.2%}")
    else:
        print("FASTQ filtering completed: the input file was empty.")


if __name__ == "__main__":
    main()
