"""`round` matches Python for halves and for an ndigits argument.

The call lowering routed `round` through the single-argument builtin path, so
`round(x, n)` silently dropped `n` and returned an integer. The emitter also
used C `round`, which rounds halves away from zero, where Python rounds them
to even (`round(2.5) == 2`).

`round` now receives every positional argument. One argument rounds half to
even with `rint`. With ndigits the result stays a float: non-negative ndigits
are correctly rounded from the exact binary value by formatting with `%.*f`
and parsing back, as CPython does (`round(2.675, 2) == 2.67`), and negative
ndigits scale and round half to even. `round(int, n)` returns the int for a
constant non-negative n and refuses to lower otherwise.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "round follows Python halves and ndigits" {
    (eng, _ir) = compile_native("round_ndigits.jac");
    assert get_func(eng, "round_half_even_low", ctypes.c_int64)() == 2;
    assert get_func(eng, "round_half_even_high", ctypes.c_int64)() == 4;
    assert get_func(eng, "round_negative_half", ctypes.c_int64)() == -2;
    assert get_func(eng, "round_two_places", ctypes.c_double)() == 0.83;
    assert get_func(eng, "round_binary_half", ctypes.c_double)() == 2.67;
    assert get_func(eng, "round_negative_places", ctypes.c_double)() == 1200.0;
    places = get_func(
        eng, "round_runtime_places", ctypes.c_double, ctypes.c_double, ctypes.c_int64
    );
    for (value, digits) in [
        (-1.25, 1),
        (0.125, 2),
        (0.375, 2),
        (5.55, 1),
        (98765.4321, -3)
    ] {
        assert places(value, digits) == round(value, digits);
    }
    assert get_func(eng, "round_int_places", ctypes.c_int64)() == 7;
}
