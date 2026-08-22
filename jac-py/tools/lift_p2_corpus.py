#!/usr/bin/env python3
"""Lift the P2 proving-wave corpus with ``jac tool c2jac``.

Reads ``jac-py/tools/p2_corpus/manifest.json``. Per-file sources may live outside
``p2_corpus/corpus`` (P1 fixtures are reused). Project mode lifts every listed
``.c`` in one invocation; aggregate sidecar is written to ``lift_output``.

Run from repo root:
    .venv/bin/python jac-py/tools/lift_p2_corpus.py
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import shutil
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p2_corpus" / "manifest.json"
_JAC = _REPO / ".venv" / "bin" / "jac"


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=_REPO, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=_MANIFEST,
        help="corpus manifest JSON (default: jac-py/tools/p2_corpus/manifest.json)",
    )
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    out_dir = (_REPO / manifest["lift_output"]).resolve()
    if not _JAC.is_file():
        print(f"lift_p2_corpus: missing {_JAC}", file=sys.stderr)
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    staging = (_HERE / "p2_corpus" / "_staging").resolve()
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    for row in manifest["files"]:
        src = (_REPO / row["source"]).resolve()
        if not src.is_file():
            print(f"lift_p2_corpus: missing source {src}", file=sys.stderr)
            return 1
        stem = row["stem"]
        (staging / f"{stem}.c").write_bytes(src.read_bytes())

    cmd = [
        str(_JAC),
        "tool",
        "c2jac",
        "--project",
        str(staging.relative_to(_REPO)),
        "-o",
        str(out_dir.relative_to(_REPO)),
    ]
    include_dir = manifest.get("include_dir")
    if include_dir:
        inc_path = (_HERE / "p2_corpus" / include_dir).resolve()
        if inc_path.is_dir():
            cmd.extend(["-I", str(inc_path.relative_to(_REPO))])

    _run(cmd)

    report = out_dir / "project.c2jac.report.json"
    print(f"lifted corpus -> {out_dir.relative_to(_REPO)}")
    print(f"aggregate report -> {report.relative_to(_REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
