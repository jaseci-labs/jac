"""`int(text, base)` parses in the given base.

The single-argument builtin path lowered only the first argument, so the base
was dropped and every string parsed as decimal: `int("1b", 16)` raised and
`int("033", 8)` gave 33.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "int with an explicit base parses in that base" {
    (eng, _ir) = compile_native("int_with_base.jac");
    assert get_func(eng, "hex_lower", ctypes.c_int64)() == 27;
    assert get_func(eng, "hex_upper", ctypes.c_int64)() == 255;
    assert get_func(eng, "hex_prefixed", ctypes.c_int64)() == 16;
    assert get_func(eng, "octal", ctypes.c_int64)() == 27;
    assert get_func(eng, "binary", ctypes.c_int64)() == 5;
    assert get_func(eng, "sliced_hex", ctypes.c_int64)() == 27;
    assert get_func(eng, "decimal_default", ctypes.c_int64)() == 42;
}
