"""List subscripts follow Python's index semantics natively.

`xs[i]` / `xs[i] = v` follow Python: a negative index counts from the end and
anything still out of range raises IndexError, including indices whose
magnitude overflows the unsigned length compare.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "list reads follow Python index semantics" {
    (eng, _) = compile_native("list_index_check.jac");
    f = get_func(eng, "read_at", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert [f(5, 2), f(5, -1), f(5, -5)] == [20, 40, 0];
    assert [f(5, 5), f(5, -6), f(0, 0), f(0, -1)] == [-999, -999, -999, -999];
    big = 1 << 62;
    assert [f(5, big), f(5, -big), f(5, -(1 << 63))] == [-999, -999, -999];
    w = get_func(eng, "walk", ctypes.c_int64, ctypes.c_int64);
    assert w(1000) == 0;
}

test "list writes follow Python index semantics" {
    (eng, _) = compile_native("list_index_check.jac");
    f = get_func(
        eng, "write_at", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(4, 1, 7) == 7 * 31 * 31;
    assert f(4, -1, 7) == 7;
    assert f(4, -4, 7) == 7 * 31 * 31 * 31;
    assert f(4, 4, 7) == -999;
    assert f(4, -5, 7) == -999;
    assert f(4, -(1 << 63), 7) == -999;
}
