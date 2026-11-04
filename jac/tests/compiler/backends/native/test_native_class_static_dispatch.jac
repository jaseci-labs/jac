"""A static field read through a class value takes the value of the class it
holds, for subclasses defined in another module."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "a class value reads the static its own class declares" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "class_static_dispatch")
    );
    got = get_func(eng, "chk_static_dispatch", ctypes.c_int64)();
    assert got == 340 - 1 , got;
}
