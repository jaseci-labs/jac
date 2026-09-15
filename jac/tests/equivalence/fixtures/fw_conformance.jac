"""Fixed-width numeric conformance (#8532).

Cross-backend equivalence fixture: every row of the semantic contract as a
dict entry, so the server, native and client lanes are pinned to the same
values and the same traps. Trap rows hold 1 when the expected OverflowError
was raised.
"""

def fw_py -> dict[str, any] {
    a: i8 = 100;
    overflow_add: int = 0;
    try {
        s: i8 = a + a;
        overflow_add = int(s);
    } except OverflowError {
        overflow_add = 1;
    }

    w: i32 = i32.MAX;
    overflow_max: int = 0;
    try {
        w = w + 1;
        overflow_max = int(w);
    } except OverflowError {
        overflow_max = 1;
    }

    u: u8 = 5;
    underflow: int = 0;
    try {
        d: u8 = u - 6;
        underflow = int(d);
    } except OverflowError {
        underflow = 1;
    }

    big: int = 300;
    cast_trap: int = 0;
    try {
        c: u8 = u8(big);
        cast_trap = int(c);
    } except OverflowError {
        cast_trap = 1;
    }

    neg_min: int = 0;
    try {
        m: i8 = -i8.MIN;
        neg_min = int(m);
    } except OverflowError {
        neg_min = 1;
    }

    shl_trap: int = 0;
    try {
        h: u8 = u8(128) << 1;
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    f: f32 = 0.1;
    g: f32 = 0.2;
    fd: f64 = f;
    ub: u8 = 200;
    widened: i16 = ub;
    bigu: u64 = u64(9223372036854775808);
    lit: i32 = 1;
    lit = lit + 1;

    i16_trap: int = 0;
    try {
        i16_over: i16 = i16.MAX + i16(1);
        i16_trap = int(i16_over);
    } except OverflowError {
        i16_trap = 1;
    }

    u32_trap: int = 0;
    try {
        u32_over: u32 = u32.MAX + u32(1);
        u32_trap = int(u32_over);
    } except OverflowError {
        u32_trap = 1;
    }

    i64_trap: int = 0;
    try {
        i64_over: i64 = i64.MAX + i64(1);
        i64_trap = int(i64_over);
    } except OverflowError {
        i64_trap = 1;
    }

    u64_trap: int = 0;
    try {
        u64_over: u64 = u64.MAX + u64(1);
        u64_trap = int(u64_over);
    } except OverflowError {
        u64_trap = 1;
    }

    return {
        "i16_min": int(i16.MIN),
        "i16_mul": int(i16(300) * i16(100)),
        "i16_trap": i16_trap,
        "u16_wrap": int(u16.wrap(65536)),
        "u16_shr": int(u16(65535) >> 8),
        "u16_inv": int(~u16(0)),
        "i32_min": int(i32.MIN),
        "i32_mod": int(i32(-7) % i32(3)),
        "i32_neg": int(-i32(2147483647)),
        "u32_inv": int(~u32(0)),
        "u32_trap": u32_trap,
        "u32_and": int(u32(4026531840) & u32(4294901760)),
        "i64_mul": int(i64(1000000) * i64(1000)),
        "i64_min_shr": int(i64.MIN >> i64(32)),
        "i64_trap": i64_trap,
        "u64_max_shr": int(u64.MAX >> u64(32)),
        "u64_trap": u64_trap,
        "u64_floordiv": int(u64(9007199254740993) // u64(3)),
        "f64_div": f64(1.0) / f64(4.0),
        "f64_floor": f64(-7.5) // f64(2.0),
        "f32_div": float(f32(1.0) / f32(4.0)),
        "f32_neg": float(-f32(1.5)),
        "i8_max": int(i8.MAX),
        "u8_min": int(u8.MIN),
        "overflow_add": overflow_add,
        "overflow_max": overflow_max,
        "underflow": underflow,
        "cast_trap": cast_trap,
        "neg_min": neg_min,
        "shl_trap": shl_trap,
        "wrap_300": int(u8.wrap(300)),
        "wrap_i8_200": int(i8.wrap(200)),
        "wrapping_add": int(wrapping_add(i8(100), i8(100))),
        "wrapping_sub": int(wrapping_sub(u8(5), u8(6))),
        "wrapping_mul": int(wrapping_mul(u8(16), u8(16))),
        "wrapping_shl": int(wrapping_shl(u8(1), 7)),
        "lshr": int(u8(255) >> 1),
        "ashr": int(i8(-2) >> 1),
        "u64_gt": 1 if bigu > u64(1) else 0,
        "u8_floordiv": int(ub // u8(3)),
        "u8_mod": int(ub % u8(3)),
        "i8_floordiv": int(i8(-7) // i8(2)),
        "i8_mod": int(i8(-7) % i8(2)),
        "u32_truediv": u32(7) / u32(2),
        "invert_u8": int(~u8(0)),
        "pow_u8": int(u8(2) ** 7),
        "f32_literal": float(f),
        "f32_sum": float(f + g),
        "f32_to_f64": float(fd),
        "i8_min": int(i8.MIN),
        "u16_max": int(u16.MAX),
        "widened_u8": int(widened),
        "literal_adopt": int(lit),
        "cast_float_trunc": int(i8(-3.9)),
        "abs_i8": int(abs(i8(-5)))
    };
}

def fw_cl -> dict[str, any] {
    a: i8 = 100;
    overflow_add: int = 0;
    try {
        s: i8 = a + a;
        overflow_add = int(s);
    } except OverflowError {
        overflow_add = 1;
    }

    w: i32 = i32.MAX;
    overflow_max: int = 0;
    try {
        w = w + 1;
        overflow_max = int(w);
    } except OverflowError {
        overflow_max = 1;
    }

    u: u8 = 5;
    underflow: int = 0;
    try {
        d: u8 = u - 6;
        underflow = int(d);
    } except OverflowError {
        underflow = 1;
    }

    big: int = 300;
    cast_trap: int = 0;
    try {
        c: u8 = u8(big);
        cast_trap = int(c);
    } except OverflowError {
        cast_trap = 1;
    }

    neg_min: int = 0;
    try {
        m: i8 = -i8.MIN;
        neg_min = int(m);
    } except OverflowError {
        neg_min = 1;
    }

    shl_trap: int = 0;
    try {
        h: u8 = u8(128) << 1;
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    f: f32 = 0.1;
    g: f32 = 0.2;
    fd: f64 = f;
    ub: u8 = 200;
    widened: i16 = ub;
    bigu: u64 = u64(9223372036854775808);
    lit: i32 = 1;
    lit = lit + 1;

    i16_trap: int = 0;
    try {
        i16_over: i16 = i16.MAX + i16(1);
        i16_trap = int(i16_over);
    } except OverflowError {
        i16_trap = 1;
    }

    u32_trap: int = 0;
    try {
        u32_over: u32 = u32.MAX + u32(1);
        u32_trap = int(u32_over);
    } except OverflowError {
        u32_trap = 1;
    }

    i64_trap: int = 0;
    try {
        i64_over: i64 = i64.MAX + i64(1);
        i64_trap = int(i64_over);
    } except OverflowError {
        i64_trap = 1;
    }

    u64_trap: int = 0;
    try {
        u64_over: u64 = u64.MAX + u64(1);
        u64_trap = int(u64_over);
    } except OverflowError {
        u64_trap = 1;
    }

    return {
        "i16_min": int(i16.MIN),
        "i16_mul": int(i16(300) * i16(100)),
        "i16_trap": i16_trap,
        "u16_wrap": int(u16.wrap(65536)),
        "u16_shr": int(u16(65535) >> 8),
        "u16_inv": int(~u16(0)),
        "i32_min": int(i32.MIN),
        "i32_mod": int(i32(-7) % i32(3)),
        "i32_neg": int(-i32(2147483647)),
        "u32_inv": int(~u32(0)),
        "u32_trap": u32_trap,
        "u32_and": int(u32(4026531840) & u32(4294901760)),
        "i64_mul": int(i64(1000000) * i64(1000)),
        "i64_min_shr": int(i64.MIN >> i64(32)),
        "i64_trap": i64_trap,
        "u64_max_shr": int(u64.MAX >> u64(32)),
        "u64_trap": u64_trap,
        "u64_floordiv": int(u64(9007199254740993) // u64(3)),
        "f64_div": f64(1.0) / f64(4.0),
        "f64_floor": f64(-7.5) // f64(2.0),
        "f32_div": float(f32(1.0) / f32(4.0)),
        "f32_neg": float(-f32(1.5)),
        "i8_max": int(i8.MAX),
        "u8_min": int(u8.MIN),
        "overflow_add": overflow_add,
        "overflow_max": overflow_max,
        "underflow": underflow,
        "cast_trap": cast_trap,
        "neg_min": neg_min,
        "shl_trap": shl_trap,
        "wrap_300": int(u8.wrap(300)),
        "wrap_i8_200": int(i8.wrap(200)),
        "wrapping_add": int(wrapping_add(i8(100), i8(100))),
        "wrapping_sub": int(wrapping_sub(u8(5), u8(6))),
        "wrapping_mul": int(wrapping_mul(u8(16), u8(16))),
        "wrapping_shl": int(wrapping_shl(u8(1), 7)),
        "lshr": int(u8(255) >> 1),
        "ashr": int(i8(-2) >> 1),
        "u64_gt": 1 if bigu > u64(1) else 0,
        "u8_floordiv": int(ub // u8(3)),
        "u8_mod": int(ub % u8(3)),
        "i8_floordiv": int(i8(-7) // i8(2)),
        "i8_mod": int(i8(-7) % i8(2)),
        "u32_truediv": u32(7) / u32(2),
        "invert_u8": int(~u8(0)),
        "pow_u8": int(u8(2) ** 7),
        "f32_literal": float(f),
        "f32_sum": float(f + g),
        "f32_to_f64": float(fd),
        "i8_min": int(i8.MIN),
        "u16_max": int(u16.MAX),
        "widened_u8": int(widened),
        "literal_adopt": int(lit),
        "cast_float_trunc": int(i8(-3.9)),
        "abs_i8": int(abs(i8(-5)))
    };
}

def fw_na -> dict[str, any] {
    a: i8 = 100;
    overflow_add: int = 0;
    try {
        s: i8 = a + a;
        overflow_add = int(s);
    } except OverflowError {
        overflow_add = 1;
    }

    w: i32 = i32.MAX;
    overflow_max: int = 0;
    try {
        w = w + 1;
        overflow_max = int(w);
    } except OverflowError {
        overflow_max = 1;
    }

    u: u8 = 5;
    underflow: int = 0;
    try {
        d: u8 = u - 6;
        underflow = int(d);
    } except OverflowError {
        underflow = 1;
    }

    big: int = 300;
    cast_trap: int = 0;
    try {
        c: u8 = u8(big);
        cast_trap = int(c);
    } except OverflowError {
        cast_trap = 1;
    }

    neg_min: int = 0;
    try {
        m: i8 = -i8.MIN;
        neg_min = int(m);
    } except OverflowError {
        neg_min = 1;
    }

    shl_trap: int = 0;
    try {
        h: u8 = u8(128) << 1;
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    f: f32 = 0.1;
    g: f32 = 0.2;
    fd: f64 = f;
    ub: u8 = 200;
    widened: i16 = ub;
    bigu: u64 = u64(9223372036854775808);
    lit: i32 = 1;
    lit = lit + 1;

    i16_trap: int = 0;
    try {
        i16_over: i16 = i16.MAX + i16(1);
        i16_trap = int(i16_over);
    } except OverflowError {
        i16_trap = 1;
    }

    u32_trap: int = 0;
    try {
        u32_over: u32 = u32.MAX + u32(1);
        u32_trap = int(u32_over);
    } except OverflowError {
        u32_trap = 1;
    }

    i64_trap: int = 0;
    try {
        i64_over: i64 = i64.MAX + i64(1);
        i64_trap = int(i64_over);
    } except OverflowError {
        i64_trap = 1;
    }

    u64_trap: int = 0;
    try {
        u64_over: u64 = u64.MAX + u64(1);
        u64_trap = int(u64_over);
    } except OverflowError {
        u64_trap = 1;
    }

    return {
        "i16_min": int(i16.MIN),
        "i16_mul": int(i16(300) * i16(100)),
        "i16_trap": i16_trap,
        "u16_wrap": int(u16.wrap(65536)),
        "u16_shr": int(u16(65535) >> 8),
        "u16_inv": int(~u16(0)),
        "i32_min": int(i32.MIN),
        "i32_mod": int(i32(-7) % i32(3)),
        "i32_neg": int(-i32(2147483647)),
        "u32_inv": int(~u32(0)),
        "u32_trap": u32_trap,
        "u32_and": int(u32(4026531840) & u32(4294901760)),
        "i64_mul": int(i64(1000000) * i64(1000)),
        "i64_min_shr": int(i64.MIN >> i64(32)),
        "i64_trap": i64_trap,
        "u64_max_shr": int(u64.MAX >> u64(32)),
        "u64_trap": u64_trap,
        "u64_floordiv": int(u64(9007199254740993) // u64(3)),
        "f64_div": f64(1.0) / f64(4.0),
        "f64_floor": f64(-7.5) // f64(2.0),
        "f32_div": float(f32(1.0) / f32(4.0)),
        "f32_neg": float(-f32(1.5)),
        "i8_max": int(i8.MAX),
        "u8_min": int(u8.MIN),
        "overflow_add": overflow_add,
        "overflow_max": overflow_max,
        "underflow": underflow,
        "cast_trap": cast_trap,
        "neg_min": neg_min,
        "shl_trap": shl_trap,
        "wrap_300": int(u8.wrap(300)),
        "wrap_i8_200": int(i8.wrap(200)),
        "wrapping_add": int(wrapping_add(i8(100), i8(100))),
        "wrapping_sub": int(wrapping_sub(u8(5), u8(6))),
        "wrapping_mul": int(wrapping_mul(u8(16), u8(16))),
        "wrapping_shl": int(wrapping_shl(u8(1), 7)),
        "lshr": int(u8(255) >> 1),
        "ashr": int(i8(-2) >> 1),
        "u64_gt": 1 if bigu > u64(1) else 0,
        "u8_floordiv": int(ub // u8(3)),
        "u8_mod": int(ub % u8(3)),
        "i8_floordiv": int(i8(-7) // i8(2)),
        "i8_mod": int(i8(-7) % i8(2)),
        "u32_truediv": u32(7) / u32(2),
        "invert_u8": int(~u8(0)),
        "pow_u8": int(u8(2) ** 7),
        "f32_literal": float(f),
        "f32_sum": float(f + g),
        "f32_to_f64": float(fd),
        "i8_min": int(i8.MIN),
        "u16_max": int(u16.MAX),
        "widened_u8": int(widened),
        "literal_adopt": int(lit),
        "cast_float_trunc": int(i8(-3.9)),
        "abs_i8": int(abs(i8(-5)))
    };
}

"""The JSON boundary, once per lane.

Both bodies build the same values; the equivalence test encodes each one with
its own lane's encoder and asserts the two produce identical JSON, so the wire
rule cannot drift between the server and the client again.
"""
def fw_json_cl -> dict[str, any] {
    big: u64 = u64(9223372036854775808);
    small: u64 = 5;
    return {"big": big, "small": small, "neg": i64(-7)};
}

obj FwScope {
    has plain: int = 0,
        narrow: u32 = 0,
        small64: i64 = 0,
        wide64: u64 = 0;
}

obj FwWire {
    has big: u64 = 0,
        small: u64 = 0,
        neg: i64 = 0;
}

def fw_json_py -> FwWire {
    return FwWire(big=u64(9223372036854775808), small=u64(5), neg=i64(-7));
}
