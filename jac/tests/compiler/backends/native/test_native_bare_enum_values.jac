"""Enum members declared without a value count up from 1, as `auto()` does.

The layout pass read a bare member (an enum assignment with no value) as an
unknown literal, which blocked the whole enum: every member lowered to 0, so
all members compared equal natively. `TypeCategory` in the type system is such
an enum, and in the compiler kernel every type then answered `is_any_instance`
and every assignment type-checked.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "bare enum members get auto values and stay distinct" {
    (eng, _ir) = compile_native("bare_enum_values.jac");
    assert get_func(eng, "member_values", ctypes.c_int64)() == 1234;
    assert get_func(eng, "class_is_any", ctypes.c_int64)() == 0;
    assert get_func(eng, "any_is_any", ctypes.c_int64)() == 1;
    assert get_func(eng, "class_category", ctypes.c_int64)() == 4;
}
