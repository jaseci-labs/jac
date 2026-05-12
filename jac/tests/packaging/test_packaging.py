"""Tests for jaclang.packaging + the PyInstaller hook end-to-end.

Unit tests run unconditionally (~50 ms). The integration test requires
PyInstaller and is skipped otherwise (~30-60 s cold build).
"""

from __future__ import annotations

import os
import pkgutil
import subprocess
import sys
import textwrap
from importlib.metadata import entry_points
from pathlib import Path

import pytest

from jaclang.packaging import iter_jaclang_data_files, iter_user_jac_sources


def _mk(path: Path, body: str = "") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)


def test_iter_user_jac_sources_filters_correctly(tmp_path: Path) -> None:
    for rel in [
        "myapp/__init__.jac",
        "myapp/core/__init__.jac",
        "myapp/core/greeter.jac",
        "myapp/notes.txt",
        "myapp/.cache/stale.jac",
    ]:
        _mk(tmp_path / rel)
    _mk(tmp_path / ".hidden" / "__init__.jac")
    _mk(tmp_path / "_priv" / "__init__.jac")
    _mk(tmp_path / "pyonly" / "__init__.py")

    got = list(
        iter_user_jac_sources([str(tmp_path), str(tmp_path), "", "/nonexistent"])
    )
    srcs = [s for s, _ in got]

    assert len(got) == 3
    assert all(s.endswith(".jac") for s in srcs)
    assert not any(
        seg in s for s in srcs for seg in (".hidden", ".cache", "_priv", "pyonly")
    )


def test_iter_jaclang_data_files_includes_modresolver() -> None:
    """Regression guard: modresolver.jac is load-bearing for frozen-app bootstrap."""
    import jaclang

    root = os.path.dirname(jaclang.__file__)
    files = list(iter_jaclang_data_files())
    assert files
    assert all(p.startswith(root) for p, _ in files)
    assert all(rel.split(os.sep, 1)[0] == "jaclang" for _, rel in files)
    assert any(
        p.endswith(os.path.join("jac0core", "modresolver.jac")) for p, _ in files
    )


def test_pyinstaller_entry_point_is_discoverable_and_works(tmp_path: Path) -> None:
    """Entry point is registered and activates ``.jac`` path-based discovery."""
    eps = [ep for ep in entry_points(group="pyinstaller40") if "jaclang" in ep.value]
    assert eps, "jaclang pyinstaller40 entry point not registered"

    hook_dirs = eps[0].load()()
    assert hook_dirs and os.path.isfile(os.path.join(hook_dirs[0], "hook-jaclang.py"))

    pkg = tmp_path / "testpkg"
    pkg.mkdir()
    (pkg / "__init__.jac").write_text("")
    spec = pkgutil.get_importer(str(tmp_path)).find_spec("testpkg")
    assert spec is not None, "path-level .jac hook not installed by get_hook_dirs()"


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
    pytest.importorskip("PyInstaller")

    for rel, body in _FIXTURE.items():
        _mk(tmp_path / rel, body)

    # Under PEP 660 editable installs, jaclang is on sys.meta_path only —
    # invisible to PyInstaller's path-based analyzer. ``--paths`` injects
    # jaclang's parent directly into pathex. Wheel installs don't need this.
    import jaclang

    jaclang_parent = os.path.dirname(os.path.dirname(jaclang.__file__))

    build = subprocess.run(
        [
            sys.executable,
            "-m",
            "PyInstaller",
            "--noconfirm",
            "--onedir",
            "--paths",
            jaclang_parent,
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

    internal = tmp_path / "dist/main/_internal"
    bundled = (
        list((internal / "myapp").rglob("*.jac"))
        if (internal / "myapp").exists()
        else []
    )
    assert len(bundled) >= 5, (
        f"myapp not bundled (got {len(bundled)})\n{build.stderr[-2000:]}"
    )

    run = subprocess.run(
        [str(tmp_path / "dist/main/main")],
        cwd="/",
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert run.returncode == 0, run.stderr
    assert "Hello, world!!!" in run.stdout
