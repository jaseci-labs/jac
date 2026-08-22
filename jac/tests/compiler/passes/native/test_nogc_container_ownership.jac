"""Owned str containers under --gc none own their elements.

Fresh strings move into list/set/dict containers, named bindings and string
literals are copied in, and the headerless container drop frees the elements
it owns through a per-instance element-drop slot -- all with zero RC calls in
the emitted IR (the zero-RC contract of --enforce-nogc --assert-no-rc).
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "nogc"),
     PROG = "str_container_prog.jac";

def _compile_ir(entry_path: str) -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = "wasm32-unknown-unknown";
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=entry_path,
            options=CompileOptions(
                aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
            )
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
}

test "str containers compile RC-free with element-drop loops in the IR" {
    ir = _compile_ir(os.path.join(FIXTURES, PROG));
    assert "__rc_" not in ir , "str container build re-entered the RC world";
    assert "edrop" in ir , "container drop carries no element-drop machinery";
}

test "host binary runs str containers and passes assert-no-rc" {
    src = os.path.join(FIXTURES, PROG);
    out_bin = os.path.join(tempfile.mkdtemp(), "strcont.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            src,
            "--scrub",
            "--gc",
            "none",
            "--enforce-nogc",
            "--assert-no-rc",
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=300
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode == 0 , f"nacompile failed: {combined[-900:]}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=60);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    out = proc.stdout.strip().split("\n");
    assert out == ["4", "x0", "lit", "keep7", "v1", "w", "1"] , f"str container output mismatch: {out}";
}
