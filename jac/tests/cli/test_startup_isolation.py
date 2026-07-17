"""Import isolation checks for manifest-backed CLI fast paths.

Jac bootstrap (including jac0core.runtime) is accepted as the startup floor.
These tests assert that lightweight informational paths do not eagerly import
command implementations or optional feature packages.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

JAC_ROOT = Path(__file__).resolve().parents[2]

# Heavy imports that manifest routing should avoid on fast paths.
_HEAVY_IMPORTS = {
    "jaclang.compiler",
    "jaclang.cli.commands",
    "jaclang.runtimelib.client",
    "jaclang.scale",
    "jaclang.byllm",
}


def _probe(argv: list[str], blocked: set[str] | None = None) -> tuple[int, str]:
    blocked = blocked if blocked is not None else _HEAVY_IMPORTS
    blocked_repr = repr(sorted(blocked))
    argv_repr = repr(["jac"] + argv)
    script = f"""
import os, sys, runpy
sys.path.insert(0, {str(JAC_ROOT)!r})
os.chdir({str(JAC_ROOT)!r})
BLOCKED = set({blocked_repr})
real_import = __builtins__.__import__
def tracking_import(name, globals=None, locals=None, fromlist=(), level=0):
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
    return proc.returncode, proc.stderr + proc.stdout


def test_version_fast_path_avoids_heavy_imports() -> None:
    code, err = _probe(["--version"])
    assert code == 0, err


def test_help_fast_path_avoids_heavy_imports() -> None:
    code, err = _probe(["--help"])
    assert code == 0, err


def test_bare_invocation_avoids_heavy_imports() -> None:
    code, err = _probe([])
    assert code == 0, err


def test_unknown_command_avoids_heavy_imports() -> None:
    code, err = _probe(["not-a-real-command"])
    assert code == 2, err


def test_hidden_commands_dispatch_via_manifest() -> None:
    """Hidden manifest verbs must route without registry.finalize()."""
    for argv in (["gen-jir-registry", "--help"], ["nacompile", "--help"]):
        code, err = _probe(argv, blocked=set())
        assert code == 0, f"jac {' '.join(argv)} failed: {err}"


def test_purge_avoids_heavy_imports() -> None:
    code, err = _probe(["purge", "--help"])
    assert code == 0, err


def test_command_help_isolates_features() -> None:
    """COMMAND --help must be served from the manifest parser alone.

    Help is short-circuited before project config, feature bootstrap, client
    imports, or command-implementation loading, so it must meet the same
    isolation bar as the global fast paths (--version/--help). Static argument
    choices live in the manifest, so help output is preserved.
    """
    for argv in (
        ["run", "--help"],
        ["check", "--help"],
        ["fmt", "--help"],
        ["code", "--help"],
        ["test", "--help"],
        ["build", "--help"],
        ["start", "--help"],
        ["setup", "--help"],
        ["scale", "--help"],
        ["model", "--help"],
        ["retheme", "--help"],
    ):
        code, err = _probe(argv)
        assert code == 0, f"jac {' '.join(argv)} leaked heavy imports or failed:\n{err}"


def test_command_help_preserves_terminator() -> None:
    """A literal --help after the argparse terminator is a script/remainder
    argument and must NOT trigger the help short-circuit (it is forwarded).
    """
    # `run` has a REMAINDER arg; `-- --help` is handed to the program, so this
    # is NOT a help request. It will try to run a (missing) program and exit
    # nonzero, but must not be mistaken for help (which would exit 0).
    code, _ = _probe(["run", "--", "--help"], blocked=set())
    assert code != 0


if __name__ == "__main__":
    test_version_fast_path_avoids_heavy_imports()
    test_help_fast_path_avoids_heavy_imports()
    test_bare_invocation_avoids_heavy_imports()
    test_unknown_command_avoids_heavy_imports()
    test_purge_avoids_heavy_imports()
    test_command_help_isolates_features()
    print("ok")
