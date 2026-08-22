#!/usr/bin/env python3
"""Run one libtest snippet through layer_p2_libtest (JacPython ceval path)."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_JAC = _REPO / ".venv" / "bin" / "jac"
_JACPYTHON = _REPO / "jac-py" / "jacpython"


def _run(source: str, expect: str) -> tuple[bool, str]:
    if not _JAC.is_file():
        return False, f"missing {_JAC}"
    entry = textwrap.dedent(
        f"""
        import from layer_p2_libtest {{ p2_libtest_expect_ok }}
        with entry {{
            (ok, detail) = p2_libtest_expect_ok({source!r}, {expect!r});
            if ok {{
                print("PASS:" + detail);
            }} else {{
                print("FAIL:" + detail);
            }}
        }}
        """
    ).strip()
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".jac",
        prefix="libtest_snippet_",
        dir=_JACPYTHON,
        delete=False,
        encoding="utf-8",
    ) as handle:
        handle.write(entry + "\n")
        path = Path(handle.name)
    env = dict(os.environ)
    jac_src = _REPO / "jac"
    env["PYTHONPATH"] = str(jac_src)
    env["JAC_DEV_SOURCE"] = str(jac_src)
    cp = os.environ.get("JACPYTHON_CPYTHON")
    if cp:
        env["JACPYTHON_CPYTHON"] = cp
    try:
        proc = subprocess.run(
            [str(_JAC), "run", str(path)],
            cwd=_REPO,
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
        )
    finally:
        path.unlink(missing_ok=True)
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or proc.stdout or "").strip()
    if proc.returncode != 0:
        return False, stderr or stdout or f"exit {proc.returncode}"
    if stdout.startswith("PASS:"):
        return True, stdout[5:]
    if stdout.startswith("FAIL:"):
        return False, stdout[5:]
    return False, stdout or "missing PASS/FAIL marker"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="embedded Python snippet")
    parser.add_argument("--expect", default="ok", help="expected stdout")
    args = parser.parse_args(argv)
    ok, detail = _run(args.source, args.expect)
    if ok:
        print(detail)
        return 0
    print(detail, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
