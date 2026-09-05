"""An explicit `return` in a `-> None` callable emits `ret void` (#8085).

`_forward_declare_method` lowers a `-> None` signature to a function returning
`void`, but `_codegen_return` coerced the returned expression to the
function's return type and emitted `builder.ret(val)` regardless. For
`return None` that is `ret i8* null` inside a `define void`, which LLVM
refuses to parse, so the whole module fails codegen with E5020 and silently
falls back to the server codespace -- the module lowers as nothing at all
rather than lowering wrongly.

Falling off the end of a `-> None` method was always fine (the fallback in
`_codegen_method` emits `ret_void`), which is why this survived: only an
explicit `return` with an expression breaks.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, names_global, native_address, native_force_opts }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _MEMO: list = [];

"""Compile the fixture once; a codegen failure here is the bug, not a symptom."""
def void_fixture -> uni.Module {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "void_return.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    _MEMO.append(ir);
    return ir;
}


test "a module with `return None` in a `-> None` method still produces IR" {
    ir = void_fixture();
    assert ir.gen.llvm_ir is not None , (
        "no native IR: `ret i8* null` in a void function fails LLVM's parser "
        "and takes the whole module with it"
    );
    assert ir.gen.native_engine is not None , "no JIT engine for the fixture";
}


test "every `-> None` callable terminates with ret void" {
    ir = void_fixture();
    text = str(ir.gen.llvm_ir);
    for line in text.splitlines() {
        stripped = line.strip();
        if stripped.startswith("ret ") and stripped != "ret void" {
            assert "void" not in stripped , f"value returned from void: {stripped}";
        }
    }
    for name in ("Box.touch", "Box.touch_call", "free_fn") {
        assert names_global(text, name) , (
            f"'{name}' is missing from the emitted IR"
        );
    }
}


test "the returned expression is still evaluated for its effects" {
    ir = void_fixture();
    _eng: any = ir.gen.native_engine;
    addr = native_address(_eng, "run");
    assert addr != 0 , "'run' not found in the JIT engine";
    run = ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
    assert run() == 201 , (
        "two `touch` calls and one `touch_call`: n == 2 and the discarded "
        "`bump()` still incremented COUNTER once"
    );
}
