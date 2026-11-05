"""Constructors with more defaulted fields than one mask word holds."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "a constructor with more than 63 defaulted fields keeps every default" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "ctor_many_defaults")
    );
    assert get_func(eng, "chk_ctor_many_defaults", ctypes.c_int64)() == 1065;
}
