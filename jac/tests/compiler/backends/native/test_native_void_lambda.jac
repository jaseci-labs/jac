"""A `-> None` lambda over a statement body terminates with `ret void`.

`_codegen_lambda` coerced the body's value into the declared return type and
emitted `builder.ret(val)` unconditionally. For a `-> None` lambda whose body
is a statement call, `tail_return_expr()` hands back that call, so a void
function ended with `ret i64 0` -- which LLVM refuses, failing the whole
module with E5020 and silently demoting it to the server codespace.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    native_address,
    native_force_opts,
    source_spelled
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _MEMO: list[any] = [];

"""Compile the fixture once; a codegen failure here is the bug itself."""
def lambda_fixture -> uni.Module {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "void_lambda_stmt_body.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    _MEMO.append(ir);
    return ir;
}


test "a module carrying a void lambda over a statement body still lowers" {
    ir = lambda_fixture();
    assert ir.gen.llvm_ir is not None , (
        "no native IR: a value returned from a void function fails LLVM's "
        "parser and takes the whole module with it"
    );
}


test "no void function returns a value" {
    ir = lambda_fixture();
    text = source_spelled(str(ir.gen.llvm_ir));
    _in_void = False;
    _saw_void = False;
    for line in text.splitlines() {
        stripped = line.strip();
        if stripped.startswith("define ") {
            _in_void = stripped.split("define ", 1)[1].lstrip().startswith("void ");
            _saw_void = _saw_void or _in_void;
        } elif stripped == "}" {
            _in_void = False;
        } elif _in_void and stripped.startswith("ret ") {
            assert stripped == "ret void" , (
                f"value returned from a void function: {stripped}"
            );
        }
    }
    assert _saw_void , "the fixture emitted no void function at all";
}
