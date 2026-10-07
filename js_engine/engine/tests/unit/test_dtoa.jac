"""
Number -> string conversion (runtime/dtoa.jac).

number_to_string_radix10 is the engine's Number::toString (ES §6.1.6.1.20):
String(), Number.prototype.toString(), Array.prototype.join and property-key
conversion all go through it. dtoa_fixed is the digit generator behind
toPrecision/toExponential. Both are bignum-exact algorithms over the raw
IEEE-754 bits, so they depend on the native backend's float literal parsing,
float<->int conversion, and 64-bit integer arithmetic.

Expected strings come from node (V8) and were cross-checked against the exact
binary value of each double for the round-half cases.
"""

import from engine.src.runtime.dtoa { number_to_string_radix10, dtoa_fixed }
import from engine.src.runtime.jsvalue { MATH_INF, MATH_NEG_INF, MATH_NAN }
import from engine.src.ffi.libc { fflush, _exit }

glob _ok: int = 0,
     _fail: int = 0;

def _chks(label: str, got: str, want: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label + " — got '" + got + "' want '" + want + "'");
    }
}

def _tostr(label: str, x: float, want: str) {
    _chks("toString " + label, number_to_string_radix10(x), want);
}

"""dtoa_fixed returns [digits, k] where k is the decimal exponent of the first
digit — the same pair as the mantissa/exponent of toExponential(p - 1)."""
def _fixed(label: str, x: float, p: int, want_digits: str, want_k: int) {
    r: list[any] = dtoa_fixed(x, p);
    _chks("dtoa_fixed " + label + " digits", r[0], want_digits);
    _chks("dtoa_fixed " + label + " k", r[1], str(want_k));
}

with entry {
    # ── Shortest round-trip digits ────────────────────────────────────────────
    _tostr("0.1", 0.1, "0.1");
    _tostr("0.2", 0.2, "0.2");
    _tostr("0.1+0.2", 0.1 + 0.2, "0.30000000000000004");
    _tostr("1/3", 1.0 / 3.0, "0.3333333333333333");
    _tostr("2/3", 2.0 / 3.0, "0.6666666666666666");
    _tostr("123.456", 123.456, "123.456");
    _tostr("-1.5", -1.5, "-1.5");
    _tostr("4294967296.5", 4294967296.5, "4294967296.5");
    _tostr("12345678.9", 12345678.9, "12345678.9");

    # ── Integral values print without a fraction ─────────────────────────────
    _tostr("100", 100.0, "100");
    _tostr("2^53", 9007199254740992.0, "9007199254740992");
    _tostr("2^53+1 rounds to 2^53", 9007199254740993.0, "9007199254740992");
    _tostr("1e20", 1e20, "100000000000000000000");
    _tostr("123456789012345680000", 123456789012345680000.0, "123456789012345680000");

    # ── Exponent thresholds: k >= 21 and k <= -7 switch to exponential ───────
    _tostr("1e21", 1e21, "1e+21");
    _tostr(
        "1.7976931348623157e308 (max)",
        1.7976931348623157e308,
        "1.7976931348623157e+308"
    );
    _tostr("1e-6", 1e-6, "0.000001");
    _tostr("0.000001234", 0.000001234, "0.000001234");
    _tostr("1e-7", 1e-7, "1e-7");
    _tostr("1.5e-7", 1.5e-7, "1.5e-7");
    _tostr("-1e-7", -0.0000001, "-1e-7");
    _tostr("123e-20", 123e-20, "1.23e-18");

    # ── Subnormal / smallest normal ──────────────────────────────────────────
    _tostr("5e-324 (min subnormal)", 5e-324, "5e-324");
    _tostr(
        "2.2250738585072014e-308 (min normal)",
        2.2250738585072014e-308,
        "2.2250738585072014e-308"
    );

    # ── Specials ─────────────────────────────────────────────────────────────
    _tostr("+0", 0.0, "0");
    _tostr("-0", -0.0, "0");
    _tostr("Infinity", MATH_INF, "Infinity");
    _tostr("-Infinity", MATH_NEG_INF, "-Infinity");
    _tostr("NaN", MATH_NAN, "NaN");

    # ── Shortest output must parse back to the identical double ──────────────
    rt_bad: int = 0;
    i: int = 1;
    while i <= 400 {
        xs: list[float] = [
            float(i) / 7.0,
            float(i) / 3.0e5,
            float(i) * 1.1e15,
            1.0 / float(i)
        ];
        for x in xs {
            s: str = number_to_string_radix10(x);
            if float(s) != x {
                rt_bad = rt_bad + 1;
                if rt_bad <= 5 {
                    print(
                        "FAIL: round-trip "
                            + s
                            + " does not parse back to the same double"
                    );
                }
            }
        }
        i = i + 1;
    }
    _chks("shortest digits round-trip (1600 values)", str(rt_bad), "0");

    # ── dtoa_fixed: p significant digits, correctly rounded on the exact value ─
    _fixed("123.456 p4", 123.456, 4, "1235", 2);
    _fixed("1/3 p5", 1.0 / 3.0, 5, "33333", -1);
    _fixed("0.000123456 p2", 0.000123456, 2, "12", -4);
    _fixed("99.99 p3 carries into a new digit", 99.99, 3, "100", 2);
    _fixed("1e21 p3", 1e21, 3, "100", 21);
    _fixed("5e-324 p1", 5e-324, 1, "5", -324);
    # Round-half cases decided by the exact binary value, not the decimal text:
    _fixed("1.005 p3 (1.00499999…)", 1.005, 3, "100", 0);
    _fixed("9.995 p3 (9.99499999…)", 9.995, 3, "999", 0);
    _fixed("1.45 p2 (1.44999999…)", 1.45, 2, "14", 0);
    _fixed("8.345 p3 (8.34500000…06)", 8.345, 3, "835", 0);
    # Exact ties round up (ES: pick the larger n).
    _fixed("2.5 p1 exact tie", 2.5, 1, "3", 0);
    _fixed("0.5 p1", 0.5, 1, "5", -1);

    print("dtoa: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail > 0 {
        fflush(0);
        _exit(1);
    }
}
