"""An exception returned by a call and raised directly survives into its handler."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "raising a call's exception result keeps it alive for the handler" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "raise_owned_result")
    );
    assert get_func(eng, "chk_raise_owned_result", ctypes.c_int64)() == 41;
}
