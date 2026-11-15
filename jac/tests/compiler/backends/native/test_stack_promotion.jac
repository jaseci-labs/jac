"""Stack promotion of owned locals with frame-local borrows (#7857 Phase A).

An `own` local that is never moved out, never sealed, and whose only
call-position uses are checked borrows (`&`/`&mut` args to borrow-annotated
params with scalar returns) or attribute reads may live on the stack instead
of the heap. The escape facts come from RcFactsPass consuming the ownership
annotations; a returned owner stays on the heap. rc-stats reports the count
as `promoted=N`.
"""

import os;
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import subprocess;
import from tests.support { jac_command, TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "stack_promotion.jac"
     ),
     C_FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "stack_promotion_c.jac"
     );

def _compile_ir(gc_mode: str, enforce: bool) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=FIXTURE,
            options=CompileOptions(
                aot_mode=True,
                na_gc_mode=gc_mode,
                nogc_enforce_all=enforce,
                no_ir_cache=True,
                skip_native_engine=True
            )
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
}

def _compile_native_ir(path: str) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=path,
        options=CompileOptions(aot_mode=True, no_ir_cache=True, skip_native_engine=True)
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    assert ir is not None and ir.gen.llvm_ir is not None;
    return str(ir.gen.llvm_ir);
}

def _fn_ir(ir: str, name: str) -> str {
    lines = ir.split("\n");
    out: list[str] = [];
    active = False;
    for line in lines {
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

test "managed mode: borrowed-only owner is stack-promoted" {
    body = _fn_ir(_compile_ir("cycles", False), "promoted_frame");
    assert "stk.Buffer" in body , body;
}

test "managed mode: returned owner stays on the heap" {
    body = _fn_ir(_compile_ir("cycles", False), "escaping_frame");
    assert "stk.Buffer" not in body , body;
}

test "headerless mode: borrowed-only owner is stack-promoted" {
    body = _fn_ir(_compile_ir("none", True), "promoted_frame");
    assert "stk.Buffer" in body , body;
    assert "malloc" not in body , body;
}

test "jac explain memory reports the promoted count" {
    res = subprocess.run(
        jac_command("explain", "memory", FIXTURE, "--memory", "rc"),
        capture_output=True,
        text=True
    );
    assert res.returncode == 0 , res.stderr;
    assert "promoted=1" in res.stderr , res.stderr;
}

test "a C record of raw pointers lent to C lives on the stack, released by nothing" {
    body = _fn_ir(_compile_native_ir(C_FIXTURE), "lend_slots");
    assert "stk.PointerSlots" in body , body;
    assert "malloc" not in body , body;
    assert "unwind.node" not in body , body;
}

test "a local also bound to a heap record is still released" {
    body = _fn_ir(_compile_native_ir(C_FIXTURE), "rebind_slots");
    assert "__rc_release" in body , body;
}

test "a named function used as a Callable is a static closure" {
    ir = _compile_native_ir(C_FIXTURE);
    body = _fn_ir(ir, "apply_named");
    assert "__jac_fnclos" in body , body;
    assert "malloc" not in body and "__rc_alloc" not in body , body;
}
