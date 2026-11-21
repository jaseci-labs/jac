"""Regression tests (#7850, re-pointed by #7871 D): __float_bits /
__bits_float lower through the intrinsic registry, never through user stubs.

INTRINSIC_REGISTRY is the single authority for the reserved intrinsic set:
classify_call tags these calls INTRINSIC before any user symbol can claim
them, and NaIRGenPass._codegen_call dispatches through the registry entry.
The fixture's stub definitions draw the W6008 collision warning and return
deliberately wrong values (0 / 0.0), so every assertion here distinguishes
the real bitcast from a stub fallthrough.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

# IEEE-754 double bit patterns, as signed i64 (what ctypes.c_int64 yields).
glob BITS_1_5 = 4609434218613702656,  # 0x3FF8000000000000
     BITS_NEG_ZERO = -9223372036854775808,  # 0x8000000000000000
     BITS_QNAN = 9221120237041090560;  # 0x7FF8000000000000

test "float bits: __float_bits(1.5) is the exact IEEE-754 pattern" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    bits_of = get_func(eng, "bits_of", ctypes.c_int64, ctypes.c_double);
    got = bits_of(1.5);
    assert got == BITS_1_5 , f"__float_bits(1.5) hit the stub: {got}";
}

test "float bits: __bits_float reverses the exact pattern" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    float_of = get_func(eng, "float_of", ctypes.c_double, ctypes.c_int64);
    got = float_of(BITS_1_5);
    assert got == 1.5 , f"__bits_float(0x3FF8000000000000) hit the stub: {got}";
}

test "float bits: float->bits->float round trip preserves values" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    round_trip = get_func(eng, "round_trip", ctypes.c_double, ctypes.c_double);
    assert round_trip(1.5) == 1.5 , f"round_trip(1.5) == {round_trip(1.5)}";
    assert round_trip(-2.75) == -2.75 , f"round_trip(-2.75) == {round_trip(-2.75)}";
}

# -0.0 == 0.0 under float equality (the stub bodies would pass that check),
# so the sign bit is pinned through __float_bits equality instead.
test "float bits: -0.0 keeps its sign bit under bits equality" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    bits_of = get_func(eng, "bits_of", ctypes.c_int64, ctypes.c_double);
    got = bits_of(-0.0);
    assert got == BITS_NEG_ZERO , f"__float_bits(-0.0) lost the sign bit: {got}";
    bits_round_trip = get_func(eng, "bits_round_trip", ctypes.c_int64, ctypes.c_int64);
    got_rt = bits_round_trip(BITS_NEG_ZERO);
    assert got_rt == BITS_NEG_ZERO , f"-0.0 bits round trip: {got_rt}";
}

test "float bits: NaN payload survives bits->float->bits" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    bits_round_trip = get_func(eng, "bits_round_trip", ctypes.c_int64, ctypes.c_int64);
    got = bits_round_trip(BITS_QNAN);
    assert got == BITS_QNAN , f"quiet-NaN bits round trip: {got}";
}
