#!/usr/bin/env python3
"""Lift P3 object-core c2jac wave entries with ``jac tool c2jac``.

Reads ``jac-py/tools/p3_object_core/manifest.json`` ``c2jac_objects_wave`` list.
Each entry is lifted as a single C file (not ``--project``) with P3 include stubs.

Run from repo root:
    .venv/bin/python jac-py/tools/lift_p3_objects.py
    .venv/bin/python jac-py/tools/lift_p3_objects.py --stem boolobject
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p3_object_core" / "manifest.json"
_INCLUDES = _HERE / "p3_object_core" / "includes"
_JAC = _REPO / ".venv" / "bin" / "jac"
_REF_ROOT = "reference/cpython"


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=_REPO, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}")


def _resolve_source(row: dict) -> Path:
    rel = row["cpython_path"]
    if rel.startswith("jac-py/"):
        src = (_REPO / rel).resolve()
    else:
        src = (_REPO / _REF_ROOT / rel).resolve()
    return src


def _lift_row(row: dict) -> None:
    src = _resolve_source(row)
    if not src.is_file():
        raise FileNotFoundError(f"lift_p3_objects: missing source {src}")
    out = (_REPO / row["lift_output"]).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(_JAC),
        "tool",
        "c2jac",
        str(src.relative_to(_REPO)),
        "-o",
        str(out.relative_to(_REPO)),
        "-I",
        str(_INCLUDES.relative_to(_REPO)),
    ]
    _run(cmd)
    sidecar = out.with_suffix(".c2jac.report.json")
    print(f"lifted {row['stem']} -> {out.relative_to(_REPO)}")
    print(f"sidecar -> {sidecar.relative_to(_REPO)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=_MANIFEST,
        help="P3 object-core manifest JSON",
    )
    parser.add_argument(
        "--stem",
        help="lift one wave entry by stem (default: all status=lift entries)",
    )
    args = parser.parse_args(argv)
    if not _JAC.is_file():
        print(f"lift_p3_objects: missing {_JAC}", file=sys.stderr)
        return 1
    if not _INCLUDES.is_dir():
        print(f"lift_p3_objects: missing includes {_INCLUDES}", file=sys.stderr)
        return 1
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    wave = manifest.get("c2jac_objects_wave", [])
    if args.stem:
        rows = [r for r in wave if r.get("stem") == args.stem]
        if not rows:
            print(f"lift_p3_objects: unknown stem {args.stem!r}", file=sys.stderr)
            return 1
    else:
        rows = [r for r in wave if r.get("status") == "lift"]
        if not rows:
            print("lift_p3_objects: no status=lift entries in wave", file=sys.stderr)
            return 1
    for row in rows:
        _lift_row(row)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
