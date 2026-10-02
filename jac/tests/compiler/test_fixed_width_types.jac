"""Semantics of the fixed-width numeric types on the server lane (#8532).

Every row of the conformance table as an assertion: the ten names are real
classes, arithmetic traps on overflow, `wrap`/`wrapping_*` are modular,
`f32` rounds to binary32 after every operation, and plain `int`/`float`
are untouched. The `json`/`typing` imports pin this module to the server
codespace; the native and client lanes run the same rows through the
cross-backend conformance fixture.
"""

import json;
import from typing { get_type_hints }

# ── identity ─────────────────────────────────────────────────────
test "a sized value is a plain int or float and carries no wrapper class" {
    x: i8 = 5;
    assert type(x) is int;
    assert isinstance(x, int);
    assert type(i8(5)) is int;
    assert type(u64(7)) is int;
    f: f32 = 1.5;
    assert type(f) is float;
    assert isinstance(f, float);
    assert i8.__name__ == "i8";
    assert str(i8(5)) == "5" and repr(u16(9)) == "9";
    assert i8(5) == 5 and hash(i8(5)) == hash(5);
    assert {i8(1): "a"}[1] == "a";
}

test "MIN and MAX are the inclusive bounds" {
    assert i8.MIN == -128 and i8.MAX == 127;
    assert u8.MIN == 0 and u8.MAX == 255;
    assert u16.MAX == 65535;
    assert i32.MIN == -2147483648 and i32.MAX == 2147483647;
    assert u64.MAX == 18446744073709551615;
    assert i64.MIN == -9223372036854775808;
    assert type(i8.MIN) is int;
}

# ── casts and wrap ───────────────────────────────────────────────
test "T(x) is a checked cast: out of range traps, floats truncate toward zero" {
    assert u8(255) == 255;
    assert i8(-128) == -128;
    big: int = 300;
    neg: int = -1;
    with testraises(OverflowError, `match="integer overflow") {
        u8(big);
    }
    with testraises(OverflowError) {
        i8(big);
    }
    with testraises(OverflowError) {
        u8(neg);
    }
    assert u8(3.9) == 3;
    assert i8(-3.9) == -3;
    assert u8(True) == 1;
    assert i16(u8(200)) == 200;
    with testraises(OverflowError) {
        i8(u8(200));
    }
    text: any = "12";
    with testraises(TypeError) {
        u8(text);
    }
}

test "T.wrap(x) is two's-complement truncation and never traps" {
    assert u8.wrap(300) == 44;
    assert i8.wrap(200) == -56;
    assert u8.wrap(-1) == 255;
    assert i32.wrap(2147483648) == -2147483648;
    assert u64.wrap(-1) == 18446744073709551615;
    assert type(u8.wrap(300)) is int;
    assert i8.wrap(5.9) == 5;
}

test "f32 rounds to binary32 on construction and after every operation" {
    f: f32 = 0.1;
    assert float(f) == 0.10000000149011612;
    assert str(f) == "0.10000000149011612";
    assert float(f32(0.1) + f32(0.2)) == 0.30000001192092896;
    assert type(f32(0.1) + f32(0.2)) is float;
    d: f64 = 0.1;
    assert float(d) == 0.1;
    assert float(f64(0.1) + f64(0.2)) == 0.30000000000000004;
    assert f32(3e38) * f32(10.0) == float("inf");
    big: f64 = f32(1e30);
    assert float(big) == float(f32(1e30));
    assert type(-f32(1.5)) is float and -f32(1.5) == -1.5;
    assert abs(f32(-2.5)) == 2.5;
}

# ── traps ────────────────────────────────────────────────────────
test "sized arithmetic traps with OverflowError('integer overflow')" {
    a: i8 = 100;
    with testraises(OverflowError, `match="integer overflow") {
        _ = a + a;
    }
    with testraises(OverflowError) {
        _ = i8(-100) - i8(100);
    }
    with testraises(OverflowError) {
        _ = u8(16) * u8(16);
    }
    with testraises(OverflowError) {
        _ = u8(5) - u8(6);
    }
    with testraises(OverflowError) {
        _ = u8(255) + 1;
    }
    w: i32 = i32.MAX;
    with testraises(OverflowError) {
        w = w + 1;
    }
    assert w == i32.MAX;
    assert i8(100) + i8(27) == 127;
    assert type(i8(1) + i8(2)) is int;
}

test "floor division, modulo and negation trap only at the signed edge" {
    assert i8(-7) // i8(2) == -4;
    assert i8(-7) % i8(2) == 1;
    assert u8(200) % u8(3) == 2;
    assert u8(200) // u8(3) == 66;
    with testraises(OverflowError) {
        _ = i8.MIN // i8(-1);
    }
    with testraises(OverflowError) {
        _ = -i8.MIN;
    }
    with testraises(OverflowError) {
        _ = abs(i8.MIN);
    }
    with testraises(ZeroDivisionError) {
        _ = u8(1) // u8(0);
    }
    with testraises(ZeroDivisionError) {
        _ = u8(1) % u8(0);
    }
    with testraises(ZeroDivisionError) {
        _ = u8(1) / u8(0);
    }
    assert -i8(5) == -5 and type(-i8(5)) is int;
    assert abs(i8(-5)) == 5;
}

test "true division yields float for int-kinds and the sized float otherwise" {
    q = u32(7) / u32(2);
    assert q == 3.5 and type(q) is float;
    assert type(f32(1.0) / f32(4.0)) is float;
    assert f32(1.0) / f32(4.0) == 0.25;
}

test "power keeps the type for a non-negative int exponent and traps on overflow" {
    assert u8(2) ** 7 == 128;
    assert type(u8(2) ** 7) is int;
    with testraises(OverflowError) {
        _ = u8(2) ** 8;
    }
    with testraises(OverflowError) {
        _ = i64(3) ** 1000000;
    }
    assert i8(2) ** -1 == 0.5;
    assert type(f32(2.0) ** f32(0.5)) is float;
}

test "shifts: arithmetic for signed, logical for unsigned, counts range-checked" {
    assert u8(255) >> 1 == 127;
    assert i8(-2) >> 1 == -1;
    assert u8(1) << 7 == 128;
    assert type(u8(1) << 7) is int;
    with testraises(OverflowError, `match="integer overflow") {
        _ = u8(128) << 1;
    }
    with testraises(OverflowError, `match="shift count") {
        _ = u8(1) << 8;
    }
    with testraises(OverflowError, `match="shift count") {
        _ = u8(1) >> u8(8);
    }
    with testraises(OverflowError, `match="shift count") {
        _ = i8(1) << i8(-1);
    }
    n: int = 3;
    assert u8(1) << n == 8;
    assert type(u8(1) << n) is int;
    big_count: int = 8;
    with testraises(OverflowError, `match="shift count") {
        _ = u8(1) << big_count;
    }
    assert u64(1) << 63 == 9223372036854775808;
}

test "bitwise operators keep the width and ~ is the width mask on unsigned" {
    assert ~u8(0) == 255;
    assert ~u8(255) == 0;
    assert ~i8(0) == -1;
    assert type(~u8(0)) is int;
    assert u8(240) & u8(15) == 0;
    assert u8(240) | u8(15) == 255;
    assert u8(255) ^ u8(15) == 240;
    assert type(u8(240) & u8(15)) is int;
    assert i8(-1) & i8(127) == 127;
}

test "unsigned values compare as unsigned above the signed range" {
    assert u64(9223372036854775808) > u64(1);
    assert u64.MAX > u64(0);
    assert u8(200) > u8(100);
    assert i8(-1) < i8(0);
}

# ── modular family ───────────────────────────────────────────────
test "wrapping_* never trap and keep the operand type" {
    assert wrapping_add(i8(100), i8(100)) == -56;
    assert type(wrapping_add(i8(100), i8(100))) is int;
    assert wrapping_sub(u8(5), u8(6)) == 255;
    assert wrapping_mul(u8(16), u8(16)) == 0;
    assert wrapping_neg(i8.MIN) == i8.MIN;
    assert wrapping_neg(u8(1)) == 255;
    assert wrapping_shl(u8(1), 7) == 128;
    assert wrapping_shl(u8(1), 8) == 1;
    assert wrapping_shl(u8(255), 1) == 254;
    assert wrapping_add(u64.MAX, 1) == 0;
    a: i8 = 100;
    assert wrapping_add(a, 100) == -56;
}

# ── mixing with plain int and float ──────────────────────────────
test "a sized operand against a plain one yields the plain type and never traps" {
    a: i8 = 100;
    n: int = 200;
    r = n + a;
    assert r == 300 and type(r) is int;
    s = a + n;
    assert s == 300 and type(s) is int;
    x: any = i8(100);
    y: any = 200;
    assert y + x == 300 and type(y + x) is int;
    assert x + y == 300 and type(x + y) is int;
    assert x * 1000 == 100000;
    b: bool = True;
    assert type(b + a) is int and b + a == 101;
    assert type(a + b) is int;
    f: float = 1.5;
    g: f32 = 0.5;
    assert f + g == 2.0 and type(f + g) is float;
    assert type(g + f) is float;
    assert int(u64.MAX) == 18446744073709551615 and type(int(u64.MAX)) is int;
    assert float(i8(3)) == 3.0 and type(float(i8(3))) is float;
    assert not bool(u8(0)) and bool(u8(2));
}

test "a lattice widening produces a value of the wider type" {
    a: i8 = -5;
    w: i64 = a;
    assert type(w) is int and w == -5;
    u: u8 = 200;
    s: i16 = u;
    assert type(s) is int and s == 200;
    f: f32 = 1.5;
    d: f64 = f;
    assert type(d) is float and d == 1.5;
    p: float = f;
    assert type(p) is float;
    n: int = u;
    assert type(n) is int;
    mixed = a + w;
    assert type(mixed) is int and mixed == -10;
    half = u + 1;
    assert type(half) is int and half == 201;
}

def accumulate(v: f64) -> f64 {
    total = 0.0;
    total += v;
    total += v;
    return total;
}

test "an augmented assignment widens its target without coercing the store" {
    assert accumulate(f64(1.25)) == 2.5;
}

test "literal adoption makes the literal the sized type" {
    x: i8 = 1;
    assert type(x) is int;
    y: u16 = 65535;
    assert type(y) is int;
    z: f32 = 0.1;
    assert type(z) is float;
    assert type(x + 1) is int;
    assert type(1 + x) is int;
    assert type(x << 1) is int;
}

def takes_i64(v: i64) -> i64 {
    return v;
}

def gives_u8 -> u8 {
    return 7;
}

def pixel_default(v: u8 = 9) -> u8 {
    return v;
}

test "call, return and default boundaries carry the target type" {
    a: i8 = 3;
    r = takes_i64(a);
    assert type(r) is int and r == 3;
    g = gives_u8();
    assert type(g) is int and g == 7;
    assert type(pixel_default()) is int;
    assert type(pixel_default(u8(1))) is int;
}

# ── archetypes and serialization ─────────────────────────────────
obj Pixel {
    has r: u8 = 0,
        g: u8 = 255,
        scale: f32 = 1.0;
}

test "has fields with sized types resolve hints, serialize, and keep their class" {
    p = Pixel();
    assert type(p.r) is int and type(p.g) is int and type(p.scale) is float;
    hints = get_type_hints(Pixel);
    assert hints["r"] is u8 and hints["scale"] is f32;
    assert json.dumps({"r": p.r, "g": p.g, "s": p.scale})
        == '{"r": 0, "g": 255, "s": 1.0}';
    p.r = u8(200);
    with testraises(OverflowError) {
        p.r = p.r + p.g;
    }
    assert p.r == 200;
}

test "augmented assignment is checked on names, fields and subscripts" {
    obj Cell {
        has v: i32 = 0;
    }
    w: i32 = i32.MAX;
    with testraises(OverflowError) {
        w += 1;
    }
    c = Cell(v=i32.MAX);
    with testraises(OverflowError) {
        c.v += 1;
    }
    lst: list[i32] = [i32.MAX];
    with testraises(OverflowError) {
        lst[0] += 1;
    }
    ok: i32 = i32(5);
    ok += 3;
    ok *= 2;
    ok -= 1;
    ok <<= 1;
    assert ok == 30 and type(ok) is int;
    fl: f32 = f32(0.1);
    fl += f32(0.2);
    assert fl == 0.30000001192092896;
    u: u8 = u8(1);
    with testraises(OverflowError) {
        u -= 2;
    }
}
