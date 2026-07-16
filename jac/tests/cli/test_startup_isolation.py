"""Import isolation checks for Tier-0 fast paths."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

JAC_ROOT = Path(__file__).resolve().parents[2]


def _probe(argv: list[str], blocked: set[str]) -> tuple[int, str]:
    blocked_repr = repr(sorted(blocked))
    argv_repr = repr(["jac"] + argv)
    script = f"""
import os, sys, runpy
sys.path.insert(0, {str(JAC_ROOT)!r})
os.chdir({str(JAC_ROOT)!r})
BLOCKED = set({blocked_repr})
real_import = __builtins__.__import__
def tracking_import(name, globals=None, locals=None, fromlist=(), level=0):
    for part in name.split('.'):
        pass
    for key in (name, name.split('.')[0]):
        if key in BLOCKED:
            raise ImportError(f"blocked: {{name}}")
    return real_import(name, globals, locals, fromlist, level)
__builtins__.__import__ = tracking_import
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
"""
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=JAC_ROOT,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stderr


def test_version_fast_path_blocks_heavy_imports() -> None:
    blocked = {
        "jaclang.compiler",
        "jaclang.jac0core.runtime",
        "jaclang.runtimelib.client",
        "jaclang.scale",
        "jaclang.byllm",
    }
    code, err = _probe(["--version"], blocked)
    assert code == 0, err


def test_help_fast_path_blocks_heavy_imports() -> None:
    blocked = {
        "jaclang.compiler",
        "jaclang.jac0core.runtime",
        "jaclang.runtimelib.client",
        "jaclang.scale",
        "jaclang.byllm",
    }
    code, err = _probe(["--help"], blocked)
    assert code == 0, err


def test_purge_blocks_heavy_imports() -> None:
    blocked = {
        "jaclang.compiler",
        "jaclang.jac0core.runtime",
        "jaclang.runtimelib.client",
        "jaclang.scale",
        "jaclang.byllm",
    }
    code, err = _probe(["purge", "--help"], blocked)
    assert code == 0, err


if __name__ == "__main__":
    test_version_fast_path_blocks_heavy_imports()
    test_help_fast_path_blocks_heavy_imports()
    test_purge_blocks_heavy_imports()
    print("ok")
