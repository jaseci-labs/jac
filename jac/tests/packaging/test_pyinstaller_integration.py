"""End-to-end PyInstaller hook acceptance test.

Builds a Jac-only package (``__init__.jac`` markers, zero ``__init__.py``)
and asserts the frozen binary runs. Obsoletes PR #5466's manual scaffolding
if this passes. Skipped when PyInstaller is unavailable; full build takes
roughly 30-60 seconds.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

pytest.importorskip("PyInstaller")


def _write(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(body).lstrip())


def test_frozen_app_runs_jac_only_package(tmp_path: Path) -> None:
    _write(tmp_path / "myapp" / "__init__.jac", "")
    _write(tmp_path / "myapp" / "core" / "__init__.jac", "")
    _write(tmp_path / "myapp" / "utils" / "__init__.jac", "")
    _write(
        tmp_path / "myapp" / "utils" / "helpers.jac",
        """
        def shout(msg: str) -> str {
            return msg + "!!!";
        }
        """,
    )
    _write(
        tmp_path / "myapp" / "core" / "greeter.jac",
        """
        import from myapp.utils.helpers { shout }

        def greet(name: str) -> str {
            return shout(f"Hello, {name}");
        }
        """,
    )
    _write(
        tmp_path / "main.py",
        """
        import jaclang  # noqa: F401
        from myapp.core.greeter import greet

        if __name__ == "__main__":
            print(greet("world"))
        """,
    )

    build = subprocess.run(
        [
            sys.executable,
            "-m",
            "PyInstaller",
            "--noconfirm",
            "--onedir",
            "--collect-all",
            "jaclang",
            "--distpath",
            str(tmp_path / "dist"),
            "--workpath",
            str(tmp_path / "build"),
            "--specpath",
            str(tmp_path),
            str(tmp_path / "main.py"),
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert build.returncode == 0, build.stderr

    bundled = list((tmp_path / "dist" / "main" / "_internal" / "myapp").rglob("*.jac"))
    assert len(bundled) >= 5, f"expected myapp/*.jac bundled, got: {bundled}"

    run = subprocess.run(
        [str(tmp_path / "dist" / "main" / "main")],
        cwd="/",
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert run.returncode == 0, run.stderr
    assert "Hello, world!!!" in run.stdout, run.stdout
