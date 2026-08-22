#!/usr/bin/env python3
"""Measure Tier-B density from a c2jac project aggregate sidecar.

Reads ``project.c2jac.report.json`` (or a compatible aggregate path), sums
``tier_b_total``, counts non-comment Jac LOC across the listed ``output`` files,
and prints density = tier_b_total / total_jac_loc.

Run from repo root:
    .venv/bin/python jac-py/tools/measure_tier_b.py \\
        jac-py/tools/p1_corpus/baseline/project.c2jac.report.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def _repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def _jac_loc(path: Path) -> int:
    if not path.is_file():
        raise FileNotFoundError(path)
    count = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        count += 1
    return count


def measure(report_path: Path, repo_root: Path) -> dict[str, object]:
    data = json.loads(report_path.read_text(encoding="utf-8"))
    tier_b_total = int(data.get("tier_b_total", 0))
    per_file: list[dict[str, object]] = []
    total_jac_loc = 0
    for row in data.get("files", []):
        out_rel = row["output"]
        out_path = repo_root / out_rel
        loc = _jac_loc(out_path)
        total_jac_loc += loc
        per_file.append(
            {
                "output": out_rel,
                "tier_b_count": int(row.get("tier_b_count", 0)),
                "jac_loc": loc,
            }
        )
    density = (tier_b_total / total_jac_loc) if total_jac_loc else 0.0
    return {
        "report": str(report_path.relative_to(repo_root)),
        "tier_b_total": tier_b_total,
        "total_jac_loc": total_jac_loc,
        "density": density,
        "files": per_file,
    }


def main(argv: list[str] | None = None) -> int:
    repo_root = _repo_root()
    default_report = (
        repo_root / "jac-py/tools/p1_corpus/baseline/project.c2jac.report.json"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report",
        nargs="?",
        type=Path,
        default=default_report,
        help="path to project.c2jac.report.json (default: p1 slice-1b baseline)",
    )
    args = parser.parse_args(argv)
    report_path = args.report if args.report.is_absolute() else repo_root / args.report
    try:
        result = measure(report_path, repo_root)
    except (OSError, KeyError, json.JSONDecodeError, TypeError, ValueError) as exc:
        print(f"measure_tier_b: {exc}", file=sys.stderr)
        return 1
    print(f"report:         {result['report']}")
    print(f"tier_b_total:   {result['tier_b_total']}")
    print(f"total_jac_loc:  {result['total_jac_loc']}")
    print(f"density:        {result['density']:.6f}")
    for row in result["files"]:
        print(
            f"  {row['output']}: tier_b={row['tier_b_count']} jac_loc={row['jac_loc']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
