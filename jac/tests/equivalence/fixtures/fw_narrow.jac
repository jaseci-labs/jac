"""Sub-64-bit fixed-width conformance (#8544).

The lanes that do not ride on 64-bit storage take their own path: the client
computes these widths in Numbers rather than BigInt, and the server reads a
memoized scalar table. This fixture pins the edges those paths turn on, so the
three lanes stay identical wherever a narrower width is involved.
"""

def narrow_py -> dict[str, any] {
    min_floordiv_trap: int = 0;
    try {
        q: i32 = i32.MIN // i32(-1);
        min_floordiv_trap = int(q);
    } except OverflowError {
        min_floordiv_trap = 1;
    }

    mul_trap: int = 0;
    try {
        m: u32 = u32(65536) * u32(65536);
        mul_trap = int(m);
    } except OverflowError {
        mul_trap = 1;
    }

    shl_trap: int = 0;
    try {
        h: u32 = u32(2147483648) << u32(1);
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    abs_min_trap: int = 0;
    try {
        am: i32 = abs(i32.MIN);
        abs_min_trap = int(am);
    } except OverflowError {
        abs_min_trap = 1;
    }

    i16_shl_trap: int = 0;
    try {
        sh: i16 = i16(16384) << i16(1);
        i16_shl_trap = int(sh);
    } except OverflowError {
        i16_shl_trap = 1;
    }

    return {
        "min_floordiv_trap": min_floordiv_trap,
        "min_mod": int(i32.MIN % i32(-1)),
        "mul_trap": mul_trap,
        "shl_trap": shl_trap,
        "abs_min_trap": abs_min_trap,
        "i16_shl_trap": i16_shl_trap,
        "u32_max_add": int(u32.MAX + u32(0)),
        "u32_floordiv": int(u32.MAX // u32(7)),
        "u32_mod": int(u32.MAX % u32(7)),
        "i32_neg_floordiv": int(i32(-7) // i32(2)),
        "i32_neg_mod": int(i32(-7) % i32(2)),
        "u32_lshr": int(u32.MAX >> u32(1)),
        "i32_ashr": int(i32(-2) >> i32(1)),
        "u32_shl_ok": int(u32(1) << u32(31)),
        "u32_and": int(u32.MAX & u32(1)),
        "u32_or": int(u32(2147483648) | u32(1)),
        "u32_xor": int(u32.MAX ^ u32(1)),
        "u32_invert": int(~u32(0)),
        "i32_invert": int(~i32(0)),
        "wrap_mul_u32": int(wrapping_mul(u32(65536), u32(65536))),
        "wrap_mul_i32": int(wrapping_mul(i32(123456789), i32(987654321))),
        "wrap_add_u32": int(wrapping_add(u32.MAX, u32(1))),
        "wrap_shl_u32": int(wrapping_shl(u32(1), u32(31))),
        "wrap_neg_i32": int(wrapping_neg(i32.MIN)),
        "wrap_mul_u8": int(wrapping_mul(u8(200), u8(3))),
        "wrap_neg_one_u32": int(u32.wrap(-1)),
        "cast_trunc_pos": int(i32(3.9)),
        "cast_trunc_neg": int(i32(-3.9)),
        "cast_float_zero": int(u32(0.9)),
        "u16_edge": int(u16.MAX + u16(0))
    };
}

def narrow_cl -> dict[str, any] {
    min_floordiv_trap: int = 0;
    try {
        q: i32 = i32.MIN // i32(-1);
        min_floordiv_trap = int(q);
    } except OverflowError {
        min_floordiv_trap = 1;
    }

    mul_trap: int = 0;
    try {
        m: u32 = u32(65536) * u32(65536);
        mul_trap = int(m);
    } except OverflowError {
        mul_trap = 1;
    }

    shl_trap: int = 0;
    try {
        h: u32 = u32(2147483648) << u32(1);
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    abs_min_trap: int = 0;
    try {
        am: i32 = abs(i32.MIN);
        abs_min_trap = int(am);
    } except OverflowError {
        abs_min_trap = 1;
    }

    i16_shl_trap: int = 0;
    try {
        sh: i16 = i16(16384) << i16(1);
        i16_shl_trap = int(sh);
    } except OverflowError {
        i16_shl_trap = 1;
    }

    return {
        "min_floordiv_trap": min_floordiv_trap,
        "min_mod": int(i32.MIN % i32(-1)),
        "mul_trap": mul_trap,
        "shl_trap": shl_trap,
        "abs_min_trap": abs_min_trap,
        "i16_shl_trap": i16_shl_trap,
        "u32_max_add": int(u32.MAX + u32(0)),
        "u32_floordiv": int(u32.MAX // u32(7)),
        "u32_mod": int(u32.MAX % u32(7)),
        "i32_neg_floordiv": int(i32(-7) // i32(2)),
        "i32_neg_mod": int(i32(-7) % i32(2)),
        "u32_lshr": int(u32.MAX >> u32(1)),
        "i32_ashr": int(i32(-2) >> i32(1)),
        "u32_shl_ok": int(u32(1) << u32(31)),
        "u32_and": int(u32.MAX & u32(1)),
        "u32_or": int(u32(2147483648) | u32(1)),
        "u32_xor": int(u32.MAX ^ u32(1)),
        "u32_invert": int(~u32(0)),
        "i32_invert": int(~i32(0)),
        "wrap_mul_u32": int(wrapping_mul(u32(65536), u32(65536))),
        "wrap_mul_i32": int(wrapping_mul(i32(123456789), i32(987654321))),
        "wrap_add_u32": int(wrapping_add(u32.MAX, u32(1))),
        "wrap_shl_u32": int(wrapping_shl(u32(1), u32(31))),
        "wrap_neg_i32": int(wrapping_neg(i32.MIN)),
        "wrap_mul_u8": int(wrapping_mul(u8(200), u8(3))),
        "wrap_neg_one_u32": int(u32.wrap(-1)),
        "cast_trunc_pos": int(i32(3.9)),
        "cast_trunc_neg": int(i32(-3.9)),
        "cast_float_zero": int(u32(0.9)),
        "u16_edge": int(u16.MAX + u16(0))
    };
}

def narrow_na -> dict[str, any] {
    min_floordiv_trap: int = 0;
    try {
        q: i32 = i32.MIN // i32(-1);
        min_floordiv_trap = int(q);
    } except OverflowError {
        min_floordiv_trap = 1;
    }

    mul_trap: int = 0;
    try {
        m: u32 = u32(65536) * u32(65536);
        mul_trap = int(m);
    } except OverflowError {
        mul_trap = 1;
    }

    shl_trap: int = 0;
    try {
        h: u32 = u32(2147483648) << u32(1);
        shl_trap = int(h);
    } except OverflowError {
        shl_trap = 1;
    }

    abs_min_trap: int = 0;
    try {
        am: i32 = abs(i32.MIN);
        abs_min_trap = int(am);
    } except OverflowError {
        abs_min_trap = 1;
    }

    i16_shl_trap: int = 0;
    try {
        sh: i16 = i16(16384) << i16(1);
        i16_shl_trap = int(sh);
    } except OverflowError {
        i16_shl_trap = 1;
    }

    return {
        "min_floordiv_trap": min_floordiv_trap,
        "min_mod": int(i32.MIN % i32(-1)),
        "mul_trap": mul_trap,
        "shl_trap": shl_trap,
        "abs_min_trap": abs_min_trap,
        "i16_shl_trap": i16_shl_trap,
        "u32_max_add": int(u32.MAX + u32(0)),
        "u32_floordiv": int(u32.MAX // u32(7)),
        "u32_mod": int(u32.MAX % u32(7)),
        "i32_neg_floordiv": int(i32(-7) // i32(2)),
        "i32_neg_mod": int(i32(-7) % i32(2)),
        "u32_lshr": int(u32.MAX >> u32(1)),
        "i32_ashr": int(i32(-2) >> i32(1)),
        "u32_shl_ok": int(u32(1) << u32(31)),
        "u32_and": int(u32.MAX & u32(1)),
        "u32_or": int(u32(2147483648) | u32(1)),
        "u32_xor": int(u32.MAX ^ u32(1)),
        "u32_invert": int(~u32(0)),
        "i32_invert": int(~i32(0)),
        "wrap_mul_u32": int(wrapping_mul(u32(65536), u32(65536))),
        "wrap_mul_i32": int(wrapping_mul(i32(123456789), i32(987654321))),
        "wrap_add_u32": int(wrapping_add(u32.MAX, u32(1))),
        "wrap_shl_u32": int(wrapping_shl(u32(1), u32(31))),
        "wrap_neg_i32": int(wrapping_neg(i32.MIN)),
        "wrap_mul_u8": int(wrapping_mul(u8(200), u8(3))),
        "wrap_neg_one_u32": int(u32.wrap(-1)),
        "cast_trunc_pos": int(i32(3.9)),
        "cast_trunc_neg": int(i32(-3.9)),
        "cast_float_zero": int(u32(0.9)),
        "u16_edge": int(u16.MAX + u16(0))
    };
}
