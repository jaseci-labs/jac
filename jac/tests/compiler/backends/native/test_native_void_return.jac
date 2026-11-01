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
`i64`, so `f() is None` was False under native. It lowers to `void` now, and a
caller that uses such a call's result as a value is refused (E5092 when native
is required; otherwise it is demoted).
"""

import ctypes;
import from tests.support {
    compile_mir,
    compile_native,
    names_global,
    native_address,
    source_spelled
}

glob _MEMO: list[any] = [];

"""Compile the fixture once; a codegen failure here is the bug, not a symptom."""
def void_fixture -> tuple[any, any] {
    if _MEMO {
        return _MEMO[0];
    }
    (eng, fx) = compile_native("void_return.jac");
    _MEMO.append((eng, fx, ));
    return (eng, fx);
}


test "a module with `return None` in a `-> None` method still produces IR" {
    (eng, fx) = void_fixture();
    assert fx.llvm_ir() , (
        "no native IR: `ret i8* null` in a void function fails LLVM's parser "
        "and takes the whole module with it"
    );
    assert eng is not None , "no JIT engine for the fixture";
}


test "every `-> None` callable terminates with ret void" {
    (_eng, fx) = void_fixture();
    text = source_spelled(fx.llvm_ir());
    for line in text.splitlines() {
        stripped = line.strip();
        if stripped.startswith("ret ") and stripped != "ret void" {
            assert "void" not in stripped , f"value returned from void: {stripped}";
        }
    }
    lines = text.splitlines();
    for name in ("Box.touch", "Box.touch_call", "Box.bare_touch", "free_fn", "bump") {
        assert any(
            line.startswith("define void") and names_global(line, name)
            for line in lines
        ) , f"'{name}' returns None and must be defined returning void";
    }
}


test "the returned expression is still evaluated for its effects" {
    (eng, _fx) = void_fixture();
    addr = native_address(eng, "run");
    assert addr != 0 , "'run' not found in the JIT engine";
    run = ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
    assert run() == 305 , (
        "three `touch`-style calls and five `bump()` calls (a `return bump()`, a "
        "nested def, parens, a discarded if/else, a reassignment): n == 3, COUNTER == 5; "
        "-1 means a void call compared with None answered wrongly"
    );
}


test "a caller using a None call result as a value is refused" {
    fx = compile_mir("void_binding.jac");
    for caller in ("caller", "method_caller") {
        assert fx.is_demoted(caller) , (
            f"{caller} must refuse the None result it uses: {fx.demoted()}"
        );
        assert not fx.reason(caller).startswith("calls ") , (
            f"the refusal belongs to {caller} itself, not to the callee it "
            f"uses: {fx.reason(caller)}"
        );
    }
}
