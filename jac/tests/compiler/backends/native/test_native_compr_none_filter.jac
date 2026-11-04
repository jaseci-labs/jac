"""A comprehension filter on optionals keeps only the present elements."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "an is-not-None comprehension filter drops the None elements" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "compr_none_filter")
    );
    assert get_func(eng, "chk_compr_none_filter", ctypes.c_int64)() == 22;
}
