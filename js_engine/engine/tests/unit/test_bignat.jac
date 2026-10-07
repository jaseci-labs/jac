"""
Arbitrary-precision naturals (runtime/bignat.jac): [sign, limb0, limb1, …] with
base-10^9 limbs, least significant first. Backs Temporal epoch-nanosecond math
and BigInt literal/radix parsing, so it depends on exact 64-bit integer
multiply / floor-divide / modulo in the native backend.

Expected values are computed with Python's arbitrary-precision int.
"""

import from engine.src.runtime.bignat {
    bn_zero,
    bn_from_int,
    bn_parse_decimal,
    bn_to_string,
    bn_add,
    bn_sub,
    bn_mul,
    bn_mul_small,
    bn_divmod,
    bn_neg,
    bn_cmp,
    bn_sign,
    bn_is_zero,
    _BN_DIV_REM
}
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

def _chki(label: str, got: int, want: int) {
    _chks(label, str(got), str(want));
}

def _dec(a: list[int]) -> str {
    return bn_to_string(a, 10);
}

glob A: str = "123456789012345678901234567890",
     B: str = "-98765432109876543210",
     C: str = "999999999999999999999999999";

with entry {
    a: list[int] = bn_parse_decimal(A);
    b: list[int] = bn_parse_decimal(B);
    c: list[int] = bn_parse_decimal(C);

    # ── Parse / print ────────────────────────────────────────────────────────
    _chks("parse/print positive", _dec(a), A);
    _chks("parse/print negative", _dec(b), B);
    _chks("leading zeros dropped", _dec(bn_parse_decimal("000123")), "123");
    _chks("explicit + sign", _dec(bn_parse_decimal("+42")), "42");
    _chks("-0 prints as 0", _dec(bn_parse_decimal("-0")), "0");
    _chks("zero", _dec(bn_zero()), "0");
    _chks("limb boundary 10^9", _dec(bn_parse_decimal("1000000000")), "1000000000");
    _chks(
        "inner zero limb padded",
        _dec(bn_parse_decimal("5000000000000000001")),
        "5000000000000000001"
    );

    # ── from_int across the i64 range ────────────────────────────────────────
    _chks("from_int 0", _dec(bn_from_int(0)), "0");
    _chks("from_int -1", _dec(bn_from_int(-1)), "-1");
    _chks(
        "from_int INT64_MAX",
        _dec(bn_from_int(9223372036854775807)),
        "9223372036854775807"
    );
    _chks(
        "from_int INT64_MIN",
        _dec(bn_from_int(-9223372036854775807 - 1)),
        "-9223372036854775808"
    );

    # ── Radix output ─────────────────────────────────────────────────────────
    _chks("radix 16", bn_to_string(a, 16), "18ee90ff6c373e0ee4e3f0ad2");
    _chks("radix 36", bn_to_string(a, 36), "byw97um9s91dlz68tsi");
    _chks(
        "radix 2 negative",
        bn_to_string(b, 2),
        "-1010101101010100101010011010011100011100101001001100111111011101010"
    );

    # ── Add / sub: carries and sign changes ──────────────────────────────────
    _chks(
        "c + 1 carries through every limb",
        _dec(bn_add(c, bn_from_int(1))),
        "1000000000000000000000000000"
    );
    _chks("a + b (mixed signs)", _dec(bn_add(a, b)), "123456788913580246791358024680");
    _chks("b + a commutes", _dec(bn_add(b, a)), "123456788913580246791358024680");
    _chks("a - b", _dec(bn_sub(a, b)), "123456789111111111011111111100");
    _chks("b - a", _dec(bn_sub(b, a)), "-123456789111111111011111111100");
    x_minus_x: list[int] = bn_add(a, bn_neg(a));
    _chks("a + (-a) prints 0", _dec(x_minus_x), "0");
    _chk_zero: bool = bn_is_zero(x_minus_x);
    _chki("a + (-a) is zero", 1 if _chk_zero else 0, 1);
    _chks("5 + -8", _dec(bn_add(bn_from_int(5), bn_from_int(-8))), "-3");

    # ── Mul ──────────────────────────────────────────────────────────────────
    _chks(
        "a * b",
        _dec(bn_mul(a, b)),
        "-12193263113702179522496570642237463801111263526900"
    );
    _chks(
        "c * c",
        _dec(bn_mul(c, c)),
        "999999999999999999999999998000000000000000000000000001"
    );
    _chks("a * 0", _dec(bn_mul(a, bn_zero())), "0");
    _chks(
        "a * 97 (mul_small)",
        _dec(bn_mul_small(a, 97)),
        "11975308534197530853419753085330"
    );

    # ── Divmod (divisor fits in i64) ─────────────────────────────────────────
    q1: list[int] = bn_divmod(a, bn_from_int(987654321));
    _chks("a / 987654321", _dec(q1), "124999998873437499901");
    _chks("a % 987654321", _dec(_BN_DIV_REM), "574845669");
    big: list[int] = bn_add(
        bn_parse_decimal("1000000000000000000000000000000"), bn_from_int(7)
    );
    q2: list[int] = bn_divmod(big, bn_from_int(86400000000000));
    _chks("(1e30+7) / ns-per-day", _dec(q2), "11574074074074074");
    _chks("(1e30+7) % ns-per-day", _dec(_BN_DIV_REM), "6400000000007");
    # Quotient truncates toward zero, like BigInt `/`.
    _chks("-7 / 2 truncates", _dec(bn_divmod(bn_from_int(-7), bn_from_int(2))), "-3");

    # ── Compare / sign ───────────────────────────────────────────────────────
    _chki("cmp a > b", bn_cmp(a, b), 1);
    _chki("cmp b < a", bn_cmp(b, a), -1);
    _chki("cmp equal", bn_cmp(a, bn_parse_decimal(A)), 0);
    _chki("cmp -5 < 3", bn_cmp(bn_from_int(-5), bn_from_int(3)), -1);
    _chki("sign positive", bn_sign(a), 1);
    _chki("sign negative", bn_sign(b), -1);
    _chki("sign zero", bn_sign(bn_zero()), 0);

    print("bignat: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail > 0 {
        fflush(0);
        _exit(1);
    }
}
