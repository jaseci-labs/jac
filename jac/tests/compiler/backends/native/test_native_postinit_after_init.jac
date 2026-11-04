"""A user-defined init replaces the generated constructor, so postinit does not run after it."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "postinit follows the generated constructor but not a user-defined init" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "postinit_after_init")
    );
    assert get_func(eng, "chk_postinit_after_init", ctypes.c_int64)() == 5113;
}
