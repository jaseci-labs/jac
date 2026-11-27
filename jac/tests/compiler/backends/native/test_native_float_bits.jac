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

# -0.0 == 0.0 under float equality (stub bodies would pass that check), so
# the sign bit is pinned through __float_bits equality instead.
test "float bits: exact IEEE-754 patterns, reversal, round trips, -0.0 sign and NaN payload" {
    (eng, _) = compile_native("float_bits_intrinsic.jac");
    bits_of = get_func(eng, "bits_of", ctypes.c_int64, ctypes.c_double);
    float_of = get_func(eng, "float_of", ctypes.c_double, ctypes.c_int64);
    round_trip = get_func(eng, "round_trip", ctypes.c_double, ctypes.c_double);
    bits_round_trip = get_func(eng, "bits_round_trip", ctypes.c_int64, ctypes.c_int64);
    assert bits_of(1.5) == BITS_1_5 , f"__float_bits(1.5) hit the stub: {bits_of(1.5)}";
    assert float_of(BITS_1_5) == 1.5 , f"__bits_float(bits(1.5)): {float_of(BITS_1_5)}";
    assert round_trip(1.5) == 1.5 , f"round_trip(1.5) == {round_trip(1.5)}";
    assert round_trip(-2.75) == -2.75 , f"round_trip(-2.75) == {round_trip(-2.75)}";
    assert bits_of(-0.0) == BITS_NEG_ZERO , f"__float_bits(-0.0) lost the sign bit";
    assert bits_round_trip(BITS_NEG_ZERO) == BITS_NEG_ZERO , "-0.0 bits round trip";
    assert bits_round_trip(BITS_QNAN) == BITS_QNAN , "quiet-NaN bits round trip";
}
