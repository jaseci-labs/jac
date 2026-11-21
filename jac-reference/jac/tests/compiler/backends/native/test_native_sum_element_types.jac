"""`sum` accumulates in the type Python would produce.

The native `sum` emitter always accumulated in an `i64` phi and combined each
element with an integer `add`. For a `list[float]` the add mixes `i64` and
`double`, so the emitter failed, the enclosing function was demoted to its
Python-only implementation, and native callers could not reach it. Lists of
bools were summed without widening, and the optional start value was ignored.

The emitter now accumulates in `double` when the list's elements or the start
value are floats and in `i64` otherwise, widening bools and narrower integers,
and it seeds the accumulator from the start value when one is given. The
loop's back-edge is registered from the block the body actually ends in.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "sum follows list element types and start values" {
    (eng, _ir) = compile_native("sum_element_types.jac");
    assert get_func(eng, "sum_ints", ctypes.c_int64)() == 10;
    assert get_func(eng, "sum_floats", ctypes.c_double)() == 1.75;
    assert get_func(eng, "sum_bools", ctypes.c_int64)() == 3;
    assert get_func(eng, "sum_int_start", ctypes.c_int64)() == 13;
    assert get_func(eng, "sum_float_start", ctypes.c_double)() == 3.5;
    assert abs(get_func(eng, "sum_float_comprehension", ctypes.c_double)() - 0.8)
        < 1e-12;
    assert get_func(eng, "sum_empty_floats", ctypes.c_double)() == 0.0;
}

test "a float sum keeps the terms a plain running total rounds away" {
    (eng, _ir) = compile_native("sum_element_types.jac");
    # CPython carries the rounding error of each float addition beside the
    # total (Neumaier's compensated sum) and folds it in at the end.
    kept = 10000000000000002.0;
    assert get_func(eng, "sum_float_start_keeps_small_ints", ctypes.c_double)() == kept;
    assert get_func(eng, "sum_float_start_keeps_small_floats", ctypes.c_double)()
        == kept;
    assert get_func(eng, "sum_floats_keeps_small_terms", ctypes.c_double)() == kept;
    # An int start meets the first float in an ordinary addition; only the
    # additions after it are compensated.
    assert get_func(eng, "sum_int_start_adds_first_float_plainly", ctypes.c_double)()
        == 1e16;
    assert get_func(eng, "sum_tenths", ctypes.c_double)() == 1.0;
    # A total that overflowed stays infinite: its error term is not finite.
    assert get_func(eng, "sum_floats_overflow", ctypes.c_double)() == float("inf");
}
