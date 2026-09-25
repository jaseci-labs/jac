"""Behavioral tests for bare functions stored in containers (native).

Regression suite for the callable-in-list crash class: `list[Callable]`
lowers its element slots to raw i8*, while the Callable read/call
convention loads a {fn, env} closure pair — so a bare code pointer stored
via a list literal, `append`/`insert`, or `lst[i] = f` was read back as a
closure box, retained through its code bytes, and called through garbage
(SIGSEGV). Stores into list slots now wrap raw functions as owned
{fn, env=null} boxes (`_wrap_fn_as_closure_value`). Dicts were never
affected — their Callable value type lowers to the closure struct, so the
centralized `_coerce_type` wrap already fired — but they are pinned here
so a future lowering change cannot regress them silently.

Every fixture function routes around a decoy (`h_bad` returns -99), so a
wrong-target dispatch can never satisfy the asserts.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "callable-in-list: append then index-set then call" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "list_append_dispatch", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 107;
}

test "callable-in-list: list literal elements dispatch" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "list_literal_dispatch", ctypes.c_int64, ctypes.c_int64);
    # h_one(4) + h_two(4) = 104 + 204.
    assert f(4) == 308;
}

test "callable-in-list: insert wraps and releases exactly once" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "list_insert_dispatch", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 105;
}

test "callable-in-list: global list element dispatch" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "global_list_dispatch", ctypes.c_int64, ctypes.c_int64);
    assert f(6) == 206;
}

test "callable-in-list: list of funcs passed as a param" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "list_as_param", ctypes.c_int64, ctypes.c_int64);
    # h_one(3) + h_two(3) = 103 + 203.
    assert f(3) == 306;
}

test "callable value: bare fn passed as a Callable param" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "fn_as_param", ctypes.c_int64, ctypes.c_int64);
    assert f(2) == 102;
}

test "callable-in-dict: literal + index-set values dispatch" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "dict_dispatch", ctypes.c_int64, ctypes.c_int64);
    # h_one(1) + h_two(1) = 101 + 201.
    assert f(1) == 302;
}

test "callable-in-dict: list of dicts passed as a param" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "list_of_dicts_dispatch", ctypes.c_int64, ctypes.c_int64);
    assert f(9) == 209;
}

test "callable-in-list: two rebound slots chain through each other" {
    (eng, _) = compile_native("callable_in_container.jac");
    f = get_func(eng, "chained_dispatch", ctypes.c_int64, ctypes.c_int64);
    # h_two(h_one(1)) = 200 + 101.
    assert f(1) == 301;
}
