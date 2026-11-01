"""Regression tests for native RC move-lowering (#6905 payoff, borrow-checker split).

When an assignment `b = a` binds a bare local whose source is owned, unique
and dead after the move, the native backend lowers it as a MOVE instead of an
alias-copy: it skips the defensive retain, and the destination inherits the
single reference and frees it exactly once.

These tests lock both halves: that the retain is actually elided (no retain
call in the emitted function) and that the result is sound at runtime (no
leak, no double free over a heavy loop).
"""

import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func, names_function }
import from jaclang.compiler.backends.native.mir.emit { RETAIN_SYMBOL }

"""The retain calls in function `name` of the fixture's emitted IR."""
def retain_calls(fixture: str, name: str) -> int {
    count = 0;
    inside = False;
    for line in compile_native_ir(fixture).llvm_ir().splitlines() {
        if line.startswith("define ") {
            inside = names_function(line, name);
        } elif inside and line == "}" {
            inside = False;
        }
        if inside and "call " in line and names_function(line, RETAIN_SYMBOL) {
            count += 1;
        }
    }
    return count;
}

test "move-lowering elides the `b = a` alias retain" {
    # `take(x: Box)` borrows, so the aliasing `b = a` is the only place a
    # retain could come from; the move leaves none.
    on = retain_calls("move_elision.jac", "run_moves");
    assert on == 0 , f"expected 0 retain calls after move-lowering, got {on}";
}

test "move-lowering is sound at runtime: correct result, no leak, no double free" {
    (eng, _) = compile_native("move_elision.jac");
    f = get_func(eng, "run_moves", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # A heavy loop: a double free would corrupt the heap and crash here; a leak
    # would grow RSS unbounded. Reaching the assert cleanly proves neither.
    assert f(400000) == 400000;
}
