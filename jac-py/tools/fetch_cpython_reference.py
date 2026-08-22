"""Ensure the pinned CPython reference checkout exists for jac-py generators.

Policy pin: CURRENT.md (CPython 3.14.6, tag v3.14.6).

Usage:
    python jac-py/tools/fetch_cpython_reference.py
    python jac-py/tools/fetch_cpython_reference.py --check
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
REF_DIR = _REPO / "reference" / "cpython"
CPYTHON_REPO = "https://github.com/python/cpython"
CPYTHON_TAG = "v3.14.6"
CPYTHON_COMMIT = "c63aec69bd59c55314c06c23f4c22c03de76fe45"
MARKER = REF_DIR / "Include" / "opcode_ids.h"


def _run(cmd: list[str], *, cwd: Path | None = None) -> None:
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if proc.returncode != 0:
        msg = proc.stderr.strip() or proc.stdout.strip() or "command failed"
        raise RuntimeError(f"{' '.join(cmd)}: {msg}")


def current_head() -> str | None:
    if not (REF_DIR / ".git").exists():
        return None
    proc = subprocess.run(
        ["git", "-C", str(REF_DIR), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def is_pinned() -> bool:
    return current_head() == CPYTHON_COMMIT and MARKER.is_file()


def fetch() -> None:
    REF_DIR.parent.mkdir(parents=True, exist_ok=True)
    if not (REF_DIR / ".git").exists():
        _run(
            [
                "git",
                "clone",
                "--depth",
                "1",
                "--branch",
                CPYTHON_TAG,
                CPYTHON_REPO,
                str(REF_DIR),
            ]
        )
    else:
        _run(["git", "-C", str(REF_DIR), "fetch", "origin", "tag", CPYTHON_TAG, "--depth", "1"])
        _run(["git", "-C", str(REF_DIR), "checkout", "--force", CPYTHON_TAG])
    head = current_head()
    if head != CPYTHON_COMMIT:
        raise RuntimeError(
            f"reference/cpython at {head}, expected pinned commit {CPYTHON_COMMIT}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if the pinned reference checkout is missing",
    )
    args = parser.parse_args(argv)
    if is_pinned():
        return 0
    if args.check:
        print(
            f"{REF_DIR} missing or not at {CPYTHON_TAG} ({CPYTHON_COMMIT}); "
            "run fetch_cpython_reference.py",
            file=sys.stderr,
        )
        return 1
    fetch()
    if not is_pinned():
        print(f"{REF_DIR} is not at pinned commit after fetch", file=sys.stderr)
        return 1
    print(f"reference/cpython ready at {CPYTHON_TAG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
