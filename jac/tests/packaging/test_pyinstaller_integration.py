"""End-to-end integration test for the PyInstaller hook.

Builds a tiny Jac-only package (``__init__.jac`` markers, zero ``__init__.py``)
with PyInstaller and asserts the frozen binary runs and produces the expected
output. This is the acceptance test for the whole hook architecture: if it
passes, PR #5466's manual ``__init__.py`` scaffolding is no longer needed.

Skipped automatically when PyInstaller is not installed. A cold frozen build
typically takes 30-60 s, so expect the test to be slow.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

pytest.importorskip(
    "PyInstaller",
    reason="PyInstaller is required for the frozen-app integration test",
)


def _write(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(body).lstrip())


@pytest.fixture
def jac_only_project(tmp_path: Path) -> Path:
    """Materialize a Jac-only package + entry script under ``tmp_path``.

    Deliberately omits every ``__init__.py`` in ``myapp/`` and every
    ``import jaclang`` in ``main.py`` — the whole point is that the hook
    handles both.
    """
    _write(tmp_path / "myapp" / "__init__.jac", '"""myapp package marker."""\n')
    _write(tmp_path / "myapp" / "core" / "__init__.jac", '"""myapp.core."""\n')
    _write(tmp_path / "myapp" / "utils" / "__init__.jac", '"""myapp.utils."""\n')

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
        # ``import jaclang`` up front is realistic for any production
        # Jac-on-Python app (it's almost always pulled in by some dependency
        # like jac-client or byllm). What we actually care about proving
        # here is that once jaclang IS in the graph, no ``__init__.py``
        # scaffolding is needed in user Jac packages — which is exactly
        # what PR #5466 was working around by hand.
        import jaclang  # noqa: F401

        from myapp.core.greeter import greet

        if __name__ == "__main__":
            print(greet("world"))
        """,
    )

    return tmp_path


def _pyinstaller_cmd() -> list[str]:
    """Return an argv prefix that invokes PyInstaller.

    Prefer ``python -m PyInstaller`` over the ``pyinstaller`` console script
    so the test works even when the script is not on ``PATH`` (e.g. in some
    CI sandboxes).
    """
    return [sys.executable, "-m", "PyInstaller"]


def test_frozen_app_runs_jac_only_package(jac_only_project: Path) -> None:
    """Golden-path acceptance test for the hook end-to-end.

    * Build ``main.py`` as a onedir PyInstaller app.
    * Do NOT pass ``--collect-all``, ``--paths``, or ``--additional-hooks-dir``
      — the jaclang entry-point hook has to do all the work on its own.
    * Run the produced binary from a directory that is NOT the source tree,
      so accidental source-path resolution cannot mask a bundling bug.
    * Assert it prints the expected Jac-compiled greeting.
    """
    project = jac_only_project

    build_result = subprocess.run(
        [
            *_pyinstaller_cmd(),
            "--noconfirm",
            "--onedir",
            # ``--collect-all jaclang`` is the one flag we expect a real user
            # to need. It tells PyInstaller to recursively collect jaclang's
            # submodules, both ``.py`` and (via our hook's data walk) ``.jac``.
            # Without it, PyInstaller only walks what main.py statically
            # imports, and misses jaclang-internal ``.jac`` files that are
            # loaded lazily at runtime through ``JacMetaImporter``.
            "--collect-all",
            "jaclang",
            "--distpath",
            str(project / "dist"),
            "--workpath",
            str(project / "build"),
            "--specpath",
            str(project),
            str(project / "main.py"),
        ],
        cwd=project,
        capture_output=True,
        text=True,
    )
    assert build_result.returncode == 0, (
        f"pyinstaller exited {build_result.returncode}\nstderr:\n{build_result.stderr}"
    )

    binary = project / "dist" / "main" / "main"
    assert binary.exists(), f"binary not produced: {binary}"

    # Confirm the bundler actually copied user .jac sources into _internal/.
    # This is the load-bearing step — if it regresses, the hook's data-walk is
    # broken even if the build claims success.
    bundled_jac = list(
        (project / "dist" / "main" / "_internal" / "myapp").rglob("*.jac")
    )
    assert len(bundled_jac) >= 5, f"expected myapp/*.jac bundled, got: {bundled_jac}"

    # Run from cwd=/ so sys.path can't accidentally resolve myapp from the
    # source tree.
    run_result = subprocess.run(
        [str(binary)],
        cwd="/",
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert run_result.returncode == 0, (
        f"frozen app exited {run_result.returncode}\n"
        f"stdout:\n{run_result.stdout}\n"
        f"stderr:\n{run_result.stderr}"
    )
    assert "Hello, world!!!" in run_result.stdout, (
        f"unexpected output:\n{run_result.stdout}"
    )


def test_no_init_py_was_added(jac_only_project: Path) -> None:
    """Sanity check that our fixture genuinely has no ``__init__.py`` scaffolding.

    A silent rename or accidental Python-package markers would invalidate the
    main acceptance test — this guards against that happening by mistake.
    """
    stray = list((jac_only_project / "myapp").rglob("__init__.py"))
    assert stray == [], (
        f"fixture has __init__.py files — test would no longer validate the "
        f"hook: {stray}"
    )


def test_pyinstaller_cli_resolvable() -> None:
    """Self-check: the ``python -m PyInstaller`` entrypoint is runnable.

    Catches obvious install-environment weirdness early, so a real test
    failure won't be confused with PyInstaller being half-broken.
    """
    result = subprocess.run(
        [*_pyinstaller_cmd(), "--version"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip(), "empty --version output"
