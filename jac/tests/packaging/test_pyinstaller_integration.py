"""End-to-end PyInstaller hook acceptance test.

Builds a Jac-only package (``__init__.jac`` markers, zero ``__init__.py``)
and asserts the frozen binary runs. ~30-60 s cold build.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

pytest.importorskip("PyInstaller")

_FIXTURE = {
    "myapp/__init__.jac": "",
    "myapp/core/__init__.jac": "",
    "myapp/utils/__init__.jac": "",
    "myapp/utils/helpers.jac": 'def shout(msg: str) -> str { return msg + "!!!"; }\n',
    "myapp/core/greeter.jac": textwrap.dedent("""\
        import from myapp.utils.helpers { shout }
        def greet(name: str) -> str { return shout(f"Hello, {name}"); }
    """),
    "main.py": textwrap.dedent("""\
        import jaclang  # noqa: F401
        from myapp.core.greeter import greet
        if __name__ == "__main__":
            print(greet("world"))
    """),
}


def test_frozen_app_runs_jac_only_package(tmp_path: Path) -> None:
    for rel, body in _FIXTURE.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)

    build = subprocess.run(
        [sys.executable, "-m", "PyInstaller", "--noconfirm", "--onedir",
         "--collect-all", "jaclang",
         "--distpath", str(tmp_path / "dist"),
         "--workpath", str(tmp_path / "build"),
         "--specpath", str(tmp_path),
         str(tmp_path / "main.py")],
        cwd=tmp_path, capture_output=True, text=True,
    )
    assert build.returncode == 0, build.stderr
    assert len(list((tmp_path / "dist/main/_internal/myapp").rglob("*.jac"))) >= 5

    run = subprocess.run(
        [str(tmp_path / "dist/main/main")],
        cwd="/", capture_output=True, text=True, timeout=60,
    )
    assert run.returncode == 0, run.stderr
    assert "Hello, world!!!" in run.stdout
