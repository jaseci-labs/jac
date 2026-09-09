"""Nested lists of scalars under nogc enforcement (#7857 Phase B).

Fresh inner list literals move into outer lists (literals and
append/insert); the outer list's element-drop slot stamps the inner
container's drop so inner buffers free exactly once at outer drop, with
byte-identical output across gc modes. Deeper nesting, named inner
bindings, and non-scalar inner elements stay fenced (E1406).
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob OWNFIELD_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "fixtures", "nogc_ownfield"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _compile(path: str) -> tuple {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            path, options=CompileOptions(aot_mode=True, memory_profile="nogc")
        );
        codes = [
            a.code.code
            for a in (list(prog.errors_had) + list(prog.warnings_had))
            if a.code is not None
                and (a.code.code.startswith("E14") or a.code.code.startswith("E13"))
        ];
        codes.sort();
        text = str(ir.gen.llvm_ir) if ir is not None and ir.gen.llvm_ir else "";
        return (codes, text);
    } finally {
        pop_native_target(prev);
    }
}

test "nested scalar list literals pass the fence and stamp inner drops" {
    (codes, text) = _compile(os.path.join(OWNFIELD_DIR, "own_nested_list.jac"));
    assert codes == [] , codes;
    assert "__drop_List_i64" in text , "inner container drop not stamped";
}

test "nested list output stays byte-identical across gc modes" {
    fixture = os.path.join(OWNFIELD_DIR, "own_nested_list.jac");
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"nl_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", fixture]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        assert outs["none"] == "3\n2\n4\nend\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
