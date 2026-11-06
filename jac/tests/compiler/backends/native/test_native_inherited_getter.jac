"""A getter inherited from another unit fills its subclass's vtable slot."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "a subclass reaches a getter declared two units up" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "inherited_getter")
    );
    assert get_func(eng, "chk_inherited_getter", ctypes.c_int64)() == 2121;
}
