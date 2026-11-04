"""An optional enum field from another unit renders in a base-typed str."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "a base-typed str renders a subclass with an optional enum field" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "optional_enum_text")
    );
    assert get_func(eng, "chk_optional_enum_text", ctypes.c_int64)() == 1;
}
