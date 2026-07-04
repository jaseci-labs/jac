# M3 na frontend hook: `import from rust.<crate> { ... }` resolves in-compiler.
#
# A `.na.jac` that imports a Rust bridge by name is nacompiled straight to a native
# binary, with the bridge module synthesized in-compiler from the library's
# `.jac_bridge` metadata.  The compiler itself resolves `rust.regex` via the ported
# jaclang `rust_bridge` package + the TypeEvaluator / resolve_native_module hooks.
#
# Gated on both the bridge .so and a jaclang LLVM shim being present; skips cleanly
# (early return) in environments without the native toolchain.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }


glob _REPO = Path(__file__).resolve().parents[4],
     _JAC = _REPO / "jac",
     _SO = _REPO / "bridges" / "target" / "release" / "libjac_bridge_regex.so",
     _SHIM = _JAC / "zig-out" / "lib" / "libjacllvm.so",
     _PROGRAM = """import from rust.regex { Regex }

with entry {
    r = Regex("^[a-z]+$");
    if r.is_match("hello") { print("hello=1"); } else { print("hello=0"); }
    if r.is_match("Hello") { print("Hello=1"); } else { print("Hello=0"); }
    r.close();
    caught = False;
    try { bad = Regex("(unclosed"); } except Exception as e { caught = True; }
    if caught { print("badpat=RAISED"); } else { print("badpat=NOERROR"); }
}
""",
     _EXPECTED = ["hello=1", "Hello=0", "badpat=RAISED"];


def _shim -> object {
    if _SHIM.is_file() {
        return str(_SHIM);
    }
    return os.environ.get("JAC_LLVM_SHIM");
}


test "import from rust regex nacompiles and runs" {
    if not _SO.is_file() {
        return;
    }
    shim = _shim();
    if not shim {
        return;
    }
    with tempfile.TemporaryDirectory() as td {
        src = Path(td) / "use_bridge.na.jac";
        src.write_text(_PROGRAM);
        binp = Path(td) / "use_bridge";
        env = dict(os.environ);
        env["JAC_LLVM_SHIM"] = shim;
        env["PYTHONPATH"] = str(_JAC);
        env["JAC_RUST_BRIDGES_PATH"] = str(_SO.parent);
        build = subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", str(src), "-o", str(binp)],
            cwd=str(_JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600
        );
        assert binp.exists() , "nacompile did not produce a binary:\n" + build.stdout[-3000:] + build.stderr[-3000:];
        runenv = dict(os.environ);
        runenv["LD_LIBRARY_PATH"] = str(_SO.parent);
        run = subprocess.run(
            [str(binp)], capture_output=True, text=True, timeout=60, env=runenv
        );
        assert run.returncode == 0 , f"binary crashed: {run.stdout}\n{run.stderr}";
        got = [
            ln
            for ln in run.stdout.splitlines()
            if ln.strip()
        ];
        assert got == _EXPECTED , f"expected {_EXPECTED}, got {got}";
    }
}


test "needed libs and origin runpath" {
    # The bridge import must force dynamic linking (NEEDED) + $ORIGIN RUNPATH.
    if not _SO.is_file() {
        return;
    }
    shim = _shim();
    if not shim {
        return;
    }
    if shutil.which("readelf") is None {
        return;
    }
    with tempfile.TemporaryDirectory() as td {
        src = Path(td) / "use_bridge.na.jac";
        src.write_text(_PROGRAM);
        binp = Path(td) / "use_bridge";
        env = dict(os.environ);
        env["JAC_LLVM_SHIM"] = shim;
        env["PYTHONPATH"] = str(_JAC);
        env["JAC_RUST_BRIDGES_PATH"] = str(_SO.parent);
        subprocess.run(
            [sys.executable, "-m", "jaclang", "nacompile", str(src), "-o", str(binp)],
            cwd=str(_JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600
        );
        if not binp.exists() {
            return;
        }
        dyn = subprocess.run(
            ["readelf", "-d", str(binp)], capture_output=True, text=True
        ).stdout;
        assert "libjac_bridge_regex.so" in dyn , dyn;
        assert "$ORIGIN" in dyn , dyn;
    }
}
