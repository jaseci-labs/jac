"""M3 exit criterion: the *same* `.jac` source, observationally identical on both
runtimes.

`conformance.py` already proves the na binary and the CPython ctypes loader agree
against the same `.so` — but it drives each side from a *separately generated*
probe (Python calls on one side, an injected Jac probe on the other). That leaves
one seam untested: whether a single hand-written `.jac` program, importing the
bridge *by name* (`import from rust.regex { Regex }`), produces identical output
when it is

  * run on the CPython interpreter   (`jaclang run`  -> the `rust.` meta-importer
    installed by `import jaclang`, D1.2), and
  * nacompiled to a native binary     (`jaclang nacompile` -> the in-compiler
    `rust.*` resolution hook, D1.1).

Both halves were built independently; this is the test that exercises them from
ONE source and asserts byte-identical observations — the "observationally
identical on both runtimes" bar in MISSION.md / IMPLEMENTATION.md M3.

Gated on both the bridge `.so` and a jaclang LLVM shim; skips cleanly otherwise.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[4]
JAC = REPO / "jac"
SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_regex.so"
SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so"

# One source, driven through both runtimes. Every observation is emitted on a
# single "OBS " line so the comparison is robust to interpreter banners / the
# pre-existing JScaleExecutionContext teardown noise, and covers the happy path
# (matches) plus the error path (bad patterns must RAISE on both).
PROGRAM = """\
import from rust.regex { Regex }

with entry {
    r1 = Regex("foo\\\\d+");
    if r1.is_match("foo42") { print("OBS m1=1"); } else { print("OBS m1=0"); }
    if r1.is_match("bar") { print("OBS m2=1"); } else { print("OBS m2=0"); }
    r1.close();

    r2 = Regex("^[a-z]+$");
    if r2.is_match("hello") { print("OBS m3=1"); } else { print("OBS m3=0"); }
    if r2.is_match("Hello") { print("OBS m4=1"); } else { print("OBS m4=0"); }
    r2.close();

    caught1 = False;
    try { bad1 = Regex("(unclosed"); } except Exception as e { caught1 = True; }
    if caught1 { print("OBS e1=RAISED"); } else { print("OBS e1=NOERROR"); }

    caught2 = False;
    try { bad2 = Regex("[z-a]"); } except Exception as e { caught2 = True; }
    if caught2 { print("OBS e2=RAISED"); } else { print("OBS e2=NOERROR"); }
}
"""

EXPECTED = [
    "OBS m1=1",
    "OBS m2=0",
    "OBS m3=1",
    "OBS m4=0",
    "OBS e1=RAISED",
    "OBS e2=RAISED",
]


def _shim() -> str | None:
    if SHIM.is_file():
        return str(SHIM)
    return os.environ.get("JAC_LLVM_SHIM")


def _obs(stdout: str) -> list[str]:
    return [ln for ln in stdout.splitlines() if ln.startswith("OBS ")]


def _run_cpython(src_dir: Path, env: dict) -> list[str]:
    """CPython interpreter path: `jaclang run` resolves rust.regex at runtime."""
    src = src_dir / "prog.jac"
    src.write_text(PROGRAM)
    r = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", str(src)],
        cwd=str(JAC),
        env=env,
        capture_output=True,
        text=True,
        timeout=300,
    )
    # Assert on stdout, not returncode: a pre-existing JScaleExecutionContext
    # teardown bug can taint the exit code even on a clean run.
    return _obs(r.stdout), r


def _run_na(src_dir: Path, env: dict) -> list[str]:
    """na AOT path: `jaclang nacompile` resolves rust.regex in-compiler, run it."""
    src = src_dir / "prog.na.jac"
    src.write_text(PROGRAM)
    binp = src_dir / "prog"
    build = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", str(src), "-o", str(binp)],
        cwd=str(JAC),
        env=env,
        capture_output=True,
        text=True,
        timeout=600,
    )
    assert binp.exists(), (
        "nacompile did not produce a binary:\n"
        + build.stdout[-3000:]
        + build.stderr[-3000:]
    )
    run = subprocess.run(
        [str(binp)],
        capture_output=True,
        text=True,
        timeout=60,
        env=dict(os.environ, LD_LIBRARY_PATH=str(SO.parent)),
    )
    assert run.returncode == 0, f"binary crashed: {run.stdout}\n{run.stderr}"
    return _obs(run.stdout), run


@pytest.mark.skipif(not SO.is_file(), reason="libjac_bridge_regex.so not built")
def test_same_jac_source_conforms_on_both_runtimes():
    shim = _shim()
    if not shim:
        pytest.skip("no LLVM shim (JAC_LLVM_SHIM unset and jac/zig-out/lib absent)")

    env = dict(
        os.environ,
        JAC_LLVM_SHIM=shim,
        PYTHONPATH=str(JAC),
        JAC_RUST_BRIDGES_PATH=str(SO.parent),
        LD_LIBRARY_PATH=str(SO.parent),
    )

    with tempfile.TemporaryDirectory() as td:
        cpy, cpy_r = _run_cpython(Path(td), env)
        na, na_r = _run_na(Path(td), env)

    # Neither side may be silently empty (which would make `cpy == na` vacuous).
    assert cpy == EXPECTED, (
        f"CPython diverged from expected:\n{cpy}\n---\n{cpy_r.stdout}\n{cpy_r.stderr}"
    )
    assert na == EXPECTED, (
        f"na diverged from expected:\n{na}\n---\n{na_r.stdout}\n{na_r.stderr}"
    )
    # The heart of the M3 exit bar: one source, identical observations.
    assert cpy == na, f"runtime divergence: cpython={cpy} na={na}"
