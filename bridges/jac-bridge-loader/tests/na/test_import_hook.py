"""M3 na frontend hook: `import from rust.<crate> { ... }` resolves in-compiler.

This is the true M3 na exit path: a `.na.jac` that imports a Rust bridge by name
is nacompiled straight to a native binary, with the bridge module synthesized
in-compiler from the library's `.jac_bridge` metadata — no generated files the
user maintains, no out-of-band synthesis step.

Distinct from `conformance.py`, which prepends the synthesized source out-of-band;
here the compiler itself resolves `rust.regex` via the ported jaclang
`rust_bridge` package + the `TypeEvaluator` / `resolve_native_module` hooks.

Gated on both the bridge `.so` and a jaclang LLVM shim being present, so it
skips cleanly in environments without the native toolchain.
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

PROGRAM = """\
import from rust.regex { Regex }

with entry {
    r = Regex("^[a-z]+$");
    if r.is_match("hello") { print("hello=1"); } else { print("hello=0"); }
    if r.is_match("Hello") { print("Hello=1"); } else { print("Hello=0"); }
    r.close();
    caught = False;
    try { bad = Regex("(unclosed"); } except Exception as e { caught = True; }
    if caught { print("badpat=RAISED"); } else { print("badpat=NOERROR"); }
}
"""

EXPECTED = ["hello=1", "Hello=0", "badpat=RAISED"]


def _shim() -> str | None:
    if SHIM.is_file():
        return str(SHIM)
    return os.environ.get("JAC_LLVM_SHIM")


@pytest.mark.skipif(not SO.is_file(), reason="libjac_bridge_regex.so not built")
def test_import_from_rust_regex_nacompiles_and_runs():
    shim = _shim()
    if not shim:
        pytest.skip("no LLVM shim (JAC_LLVM_SHIM unset and jac/zig-out/lib absent)")

    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "use_bridge.na.jac"
        src.write_text(PROGRAM)
        binp = Path(td) / "use_bridge"

        env = dict(
            os.environ,
            JAC_LLVM_SHIM=shim,
            PYTHONPATH=str(JAC),
            JAC_RUST_BRIDGES_PATH=str(SO.parent),
        )
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
        got = [ln for ln in run.stdout.splitlines() if ln.strip()]
        assert got == EXPECTED, f"expected {EXPECTED}, got {got}"


@pytest.mark.skipif(not SO.is_file(), reason="libjac_bridge_regex.so not built")
def test_needed_libs_and_origin_runpath():
    """The bridge import must force dynamic linking (NEEDED) + $ORIGIN RUNPATH."""
    shim = _shim()
    if not shim:
        pytest.skip("no LLVM shim")
    import shutil

    if shutil.which("readelf") is None:
        pytest.skip("readelf not available")

    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "use_bridge.na.jac"
        src.write_text(PROGRAM)
        binp = Path(td) / "use_bridge"
        env = dict(
            os.environ,
            JAC_LLVM_SHIM=shim,
            PYTHONPATH=str(JAC),
            JAC_RUST_BRIDGES_PATH=str(SO.parent),
        )
        subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", str(src), "-o", str(binp)],
            cwd=str(JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600,
        )
        if not binp.exists():
            pytest.skip("nacompile unavailable in this environment")
        dyn = subprocess.run(
            ["readelf", "-d", str(binp)], capture_output=True, text=True
        ).stdout
        assert "libjac_bridge_regex.so" in dyn, dyn
        assert "$ORIGIN" in dyn, dyn
