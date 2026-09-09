"""Droppless affine inference for unannotated locals (#7857 Phase E).

A LOCAL binding with no ownership annotation whose object never escapes --
scalar field reads under calls and returns included -- allocates on the
stack in managed modes too, because for a type with no `drop` hook the
reclamation point is unobservable. Types with a `drop` hook are excluded
by the codegen gate, so hook timing never changes. Zero user action.
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "affine_inference.jac"
     );

def _compile_ir -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(file_path=FIXTURE, options=CompileOptions(aot_mode=True));
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

test "unannotated droppless local with call-position scalar reads is promoted" {
    body = _fn_ir(_compile_ir(), "scalar_reads");
    assert "stk.Point" in body , body;
}

test "a type with a drop hook is never inference-promoted" {
    body = _fn_ir(_compile_ir(), "hooked");
    assert "stk.Loud" not in body , body;
}
