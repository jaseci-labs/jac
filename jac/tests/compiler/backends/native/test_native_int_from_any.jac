"""`int()` of a value typed `any` converts the boxed value as Python does.

The builtin emitter had no case for a boxed `any` argument: it fell through to
the string parser and handed the box itself to `strtol`, so the whole function
failed to lower and was demoted (`int(raw.get("n", 0))` over a decoded JSON
dict is the common shape). A boxed int or bool is its payload, a boxed float
truncates toward zero, a boxed str parses base 10 (a bad literal raises
ValueError), and anything else raises TypeError.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "int of an any-typed value follows Python" {
    (eng, _ir) = compile_native("int_from_any.jac");
    assert get_func(eng, "int_of_boxed_int", ctypes.c_int64)() == 42;
    assert get_func(eng, "int_of_boxed_bool", ctypes.c_int64)() == 10;
    assert get_func(eng, "int_of_boxed_float", ctypes.c_int64)() == -697;
    assert get_func(eng, "int_of_boxed_str", ctypes.c_int64)() == 119;
    assert get_func(eng, "int_of_json_fields", ctypes.c_int64)() == 5217;
    assert get_func(eng, "int_of_boxed_bad_str", ctypes.c_int64)() == -1;
    assert get_func(eng, "int_of_boxed_list", ctypes.c_int64)() == -2;
}
