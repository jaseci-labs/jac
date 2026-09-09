"""Owned str containers under --memory nogc own their elements.

Fresh strings move into list/set/dict containers, named bindings and string
literals are copied in, and the headerless container drop frees the elements
it owns through a per-instance element-drop slot -- all with zero RC calls in
the emitted IR (the zero-RC contract of --memory nogc).
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "nogc"),
     PROG = "str_container_prog.jac";

def _compile_ir(entry_path: str) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=entry_path,
            options=CompileOptions(aot_mode=True, memory_profile="nogc")
        );
        assert not prog.errors_had , [str(e) for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
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
            "build",
            "--native",
            src,
            "--memory",
            "nogc",
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
