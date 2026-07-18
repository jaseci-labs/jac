"""Differential-identity tests over the ownbench kernels
(jac/examples/ownbench): one annotated source per kernel, compiled under
three memory modes, must produce byte-identical output (minus the ns=
timing line).

This is the executable witness of the ownership design's erasure and
monotonicity guarantees, and the regression net for the headerless codegen
fixes of 2026-07-17, which only differential execution can see:
  - overwrite-release on `x = f(x)` dropped the value the callee had taken
    ownership of (use-after-free under --gc none, masked under rc);
  - caller-arg and scope-exit releases ignored ownership transfer into
    `own` parameters (use-after-free that surfaced only under allocation
    reuse; deriv segfaults without the fix).

The enforced build compiles with --assert-no-rc, so a zero-RC regression
fails the compile step itself. The erasure test round-trips a kernel
through harness/erase.jac (the executable Theorem-3 eraser) and checks the
bare build reproduces the annotated digest.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob OWNBENCH = str(Path(__file__).resolve().parents[4] / "examples" / "ownbench"),
     MODES = ["none", "rc", "cycles"],
     SMALL_ARGS: dict[str, list[str]] = {
         "own_binarytrees": ["8"],
         "own_vecdot": ["500", "5"],
         "own_histogram": ["5000", "3"],
         "own_vm": ["200", "50"],
         "own_rbtree": ["1000", "2"],
         "own_deriv": ["20", "3"],

     };

"""nacompile flags for a memory mode."""
def _mode_flags(mode: str) -> list[str] {
    if mode == "none" {
        return ["--enforce-nogc", "--gc", "none", "--assert-no-rc"];
    }
    return ["--gc", mode];
}

"""Compile `src` to `out_bin` under `mode`; assert success."""
def _nacompile(src: str, mode: str, out_bin: str) {
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", src] + _mode_flags(mode) + [
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=300,
    );
    assert comp.returncode == 0 , (
        f"nacompile --gc {mode} failed for {os.path.basename(src)}:"
        f" exit={comp.returncode}\n"
        f"stdout: {comp.stdout[-600:] if comp.stdout else '(empty)'}\n"
        f"stderr: {comp.stderr[-600:] if comp.stderr else '(empty)'}"
    );
    assert os.path.exists(out_bin) , f"binary not produced at {out_bin}";
}

"""Run a kernel binary; return its digest (stdout minus the ns= line)."""
def _digest(out_bin: str, args: list[str]) -> str {
    proc = subprocess.run(
        [out_bin] + args, capture_output=True, text=True, timeout=120
    );
    assert proc.returncode == 0 , (
        f"{os.path.basename(out_bin)} exited {proc.returncode}"
        f" (segfault/abort under this mode is a codegen regression)"
    );
    lines = [
        ln
        for ln in proc.stdout.splitlines()
        if not ln.startswith("ns=")
    ];
    return "\n".join(lines);
}

"""Compile+run `kernel` under all three modes; assert identical digests."""
def _assert_differential_identity(kernel: str) {
    src = os.path.join(OWNBENCH, "kernels", f"{kernel}.na.jac");
    assert os.path.exists(src) , f"kernel missing: {src}";
    args = SMALL_ARGS[kernel];
    with tempfile.TemporaryDirectory() as tmp {
        digests: dict[str, str] = {};
        for mode in MODES {
            out_bin = os.path.join(tmp, f"{kernel}_{mode}");
            _nacompile(src, mode, out_bin);
            digests[mode] = _digest(out_bin, args);
        }
        assert digests["none"] == digests["rc"] , (
            f"{kernel}: enforced-headerless output diverges from rc:\n"
            f"--- none ---\n{digests['none']}\n--- rc ---\n{digests['rc']}"
        );
        assert digests["rc"] == digests["cycles"] , (
            f"{kernel}: rc output diverges from cycles:\n"
            f"--- rc ---\n{digests['rc']}\n--- cycles ---\n{digests['cycles']}"
        );
        assert digests["none"] , f"{kernel}: empty output";
    }
}

test "ownbench differential identity: binarytrees (drop-order witness)" {
    _assert_differential_identity("own_binarytrees");
}

test "ownbench differential identity: vecdot" {
    _assert_differential_identity("own_vecdot");
}

test "ownbench differential identity: histogram" {
    _assert_differential_identity("own_histogram");
}

test "ownbench differential identity: vm" {
    _assert_differential_identity("own_vm");
}

test "ownbench differential identity: rbtree" {
    _assert_differential_identity("own_rbtree");
}

test "ownbench differential identity: deriv (own-param transfer stress)" {
    _assert_differential_identity("own_deriv");
}

test "ownbench erasure round-trip: deriv reproduces annotated digest" {
    src = os.path.join(OWNBENCH, "kernels", "own_deriv.na.jac");
    eraser = os.path.join(OWNBENCH, "harness", "erase.jac");
    args = SMALL_ARGS["own_deriv"];
    with tempfile.TemporaryDirectory() as tmp {
        erased = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", eraser, src],
            capture_output=True,
            text=True,
            timeout=120,
        );
        assert erased.returncode == 0 , f"erase.jac failed: {erased.stderr}";
        for leftover in [": own ", ": &", "(&", ", &", "&mut "] {
            assert leftover not in erased.stdout , (
                f"erase.jac left annotation pattern '{leftover}' behind"
            );
        }
        bare_src = os.path.join(tmp, "own_deriv_bare.na.jac");
        with open(bare_src, "w") as f {
            f.write(erased.stdout);
        }
        annotated_bin = os.path.join(tmp, "own_deriv_rc");
        bare_bin = os.path.join(tmp, "own_deriv_bare_rc");
        _nacompile(src, "rc", annotated_bin);
        _nacompile(bare_src, "rc", bare_bin);
        annotated = _digest(annotated_bin, args);
        bare = _digest(bare_bin, args);
        assert annotated == bare , (
            f"erased build diverges from annotated build:\n"
            f"--- annotated ---\n{annotated}\n--- bare ---\n{bare}"
        );
    }
}
