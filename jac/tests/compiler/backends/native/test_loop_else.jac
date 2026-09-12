"""End-to-end tests for loop `else` clauses on the native backend (#8629).

The else body of a for/while loop must run exactly when the loop
exhausts normally; a `break` bypasses it (PEP 530/341 semantics). The
probes return whether the else body ran, so each lowering path in the
native backend -- while, C-style iter-for, the indexed range path and
the iter-protocol list/string paths -- is checked for both edges.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "while else runs on exhaustion and is skipped by break" {
    (_eng, _ir) = compile_native("loop_else.jac");
    f = get_func(_eng, "while_else_ran", ctypes.c_bool, ctypes.c_int64);
    assert f(3) is True , "else must run when while exhausts normally";
    assert f(0) is True , "else must run for a zero-iteration while";
    g = get_func(_eng, "while_else_break_skips", ctypes.c_bool, ctypes.c_int64);
    assert g(5) is False , "break must bypass the while else body";
    assert g(0) is True , "no break taken means the else still runs";
}

test "iter-for else runs on exhaustion and is skipped by break" {
    (_eng, _ir) = compile_native("loop_else.jac");
    f = get_func(_eng, "iter_for_else_ran", ctypes.c_bool, ctypes.c_int64);
    assert f(3) is True , "else must run when iter-for exhausts normally";
    assert f(0) is True , "else must run for a zero-iteration iter-for";
    g = get_func(_eng, "iter_for_else_break_skips", ctypes.c_bool, ctypes.c_int64);
    assert g(5) is False , "break must bypass the iter-for else body";
    assert g(1) is True , "no break taken means the else still runs";
}

test "range for else runs on exhaustion and is skipped by break" {
    (_eng, _ir) = compile_native("loop_else.jac");
    f = get_func(_eng, "range_for_else_ran", ctypes.c_bool);
    assert f() is True , "else must run when a range for exhausts";
    g = get_func(_eng, "range_for_else_break_skips", ctypes.c_bool);
    assert g() is False , "break must bypass the range-for else body";
    h = get_func(_eng, "range_for_else_contributes", ctypes.c_int64);
    assert h() == 1006 , "6 + 1000: exhaustion falls into the else block";
}

test "iter-protocol for else covers lists and strings" {
    (_eng, _ir) = compile_native("loop_else.jac");
    f = get_func(_eng, "list_for_else_ran", ctypes.c_bool);
    assert f() is True , "else must run when a list for exhausts";
    g = get_func(_eng, "list_for_else_break_skips", ctypes.c_bool);
    assert g() is True , "break must bypass the list-for else body";
    h = get_func(_eng, "str_for_else_ran", ctypes.c_bool);
    assert h() is True , "string for exhaustion must fall into the else block";
}
