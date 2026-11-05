"""The 64-bit bounds the emitter checks against, computed without `1 << 63`.

The kernel runs the emitter natively, where `1 << 63` overflows, so the
floordiv overflow check and the float abs mask build 2**63 from two halves."""
import ctypes;
import os;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }

test "floordiv of the lowest int by -1 overflows and float abs clears the sign" {
    (eng, _) = compile_native(
        "main.jac", os.path.join(NATIVE_FIXTURES, "floordiv_lowest")
    );
    assert get_func(eng, "chk_floordiv_lowest", ctypes.c_int64)() == 111;
    assert get_func(eng, "chk_abs_float", ctypes.c_int64)() == 53;
}
