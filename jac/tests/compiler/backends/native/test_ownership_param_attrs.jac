"""Ownership contract positions never become unsound LLVM parameter attributes.

Under `rc` and `managed` a retain or release writes the borrowed object's count
header through the pointer, and LLVM deletes plain stores through a `readonly`
argument, so a refcounted build must never mark a borrowed (`&`) or `imm`
parameter `readonly`. Managed params carry no ownership attributes at all.
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
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "ownership_param_attrs.jac"
     );

def _compile_ir(gc_mode: (str | None) = None) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=FIXTURE,
            options=CompileOptions(
                aot_mode=True,
                no_ir_cache=True,
                skip_native_engine=True,
                na_gc_mode=gc_mode
            )
        );
        assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
        assert ir is not None and ir.gen.llvm_ir is not None;
        return str(ir.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
}

def _fn_line(ir: str, name: str) -> str {
    for line in ir.split("\n") {
        if line.startswith("define") and name in line {
            return line;
        }
    }
    assert False , f"no define line found for {name}";
    return "";
}

test "refcounted builds keep borrow and imm params writable" {
    for gc_mode in ("cycles", "rc") {
        ir = _compile_ir(gc_mode);
        for name in ("attr_reader", "attr_viewer") {
            line = _fn_line(ir, name);
            assert "readonly" not in line , line;
        }
    }
}

test "managed params carry no ownership attributes" {
    line = _fn_line(_compile_ir(), "attr_plain");
    assert "noalias" not in line , line;
    assert "readonly" not in line , line;
}
