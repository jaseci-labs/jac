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

A callable with no `-> T` returns None as well (#7139): it used to lower to
`i64`, so `f() is None` was False under native. A caller that uses such a
call's result as a value either refuses with E5092 or binds None; it never
crashes the compiler or invents a value.
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


test "the returned expression is still evaluated for its effects" {
    ir = void_fixture();
    _eng: any = ir.gen.native_engine;
    addr = native_address(_eng, "run");
    assert addr != 0 , "'run' not found in the JIT engine";
    run = ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
    assert run() == 305 , (
        "three `touch`-style calls and five `bump()` calls (a `return bump()`, a "
        "nested def, parens, a discarded if/else, a reassignment): n == 3, COUNTER == 5; "
        "-1 means a void call compared with None answered wrongly"
    );
}


test "a caller using a None call result as a value demotes or binds None, never crashes" {
    path = os.path.join(FIXTURES, "void_binding.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, options=native_force_opts());
    assert not prog.errors_had , (
        f"binding a None result must demote or lower, never fail: {[
            str(e) for e in prog.errors_had
        ]}"
    );
    iface: any = ir.gen.native_iface;
    if "caller" not in iface.demoted {
        eng: any = ir.gen.native_engine;
        assert eng is not None , "no JIT engine for the fixture";
        caller = ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(
            native_address(eng, "caller")
        );
        assert caller(3) == 3;
    }
}
