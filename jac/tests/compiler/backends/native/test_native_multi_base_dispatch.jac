"""A class with two bases from other units dispatches getters and methods through each base."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "a class with two bases from other units dispatches through each base" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "multi_base_dispatch")
    );
    assert get_func(eng, "chk_multi_base_dispatch", ctypes.c_int64)() == 360422;
}
