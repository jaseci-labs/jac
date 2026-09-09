"""Inferred move-in for container grow arguments (#7857 Phase E frontier).

A named binding appended into a container while dead-after (the
rc_last_use fact) moves in instead of copying: the strdup disappears and
the local's slot is nulled so its release is a no-op. Bindings still
live after the append keep copy-in semantics; output is byte-identical
across gc modes either way.
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

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "move_in_infer.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _compile_ir -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=FIXTURE,
            options=CompileOptions(aot_mode=True, memory_profile="nogc")
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        return str(ir.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
}

def _fn_ir(ir: str, name: str) -> str {
    out: list[str] = [];
    active = False;
    for line in ir.split("\n") {
        if line.startswith("define") and name in line {
            active = True;
        }
        if active {
            out.append(line);
            if line == "}" {
                break;
            }
        }
    }
    assert out , f"no function body found for {name}";
    return "\n".join(out);
}

test "dead-after append moves in (no elem copy)" {
    body = _fn_ir(_compile_ir(), "dead_after");
    assert "rc.str.raw" not in body , body;
}

test "alive-after append still copies in" {
    body = _fn_ir(_compile_ir(), "alive_after");
    assert "rc.str.raw" in body , body;
}

test "move-in output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"mi_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
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
        assert outs["none"] == "1\nwor1d\n1\nend\n" , outs["none"];
        assert outs["rc"] == outs["none"] , outs["rc"];
        assert outs["cycles"] == outs["none"] , outs["cycles"];
    }
}
