"""Native fixture: signedness, traps, casts and the modular family (#8532).

Every probe returns an int the test compares against the spec. Trap probes
return 1 when the expected OverflowError was raised and 0 otherwise.
"""

def:pub u8_add_traps -> int {
    a: u8 = 255;
    out: int = 0;
    try {
        b: u8 = a + 1;
        out = int(b);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u8_sub_traps -> int {
    a: u8 = 5;
    out: int = 0;
    try {
        b: u8 = a - 6;
        out = int(b);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u64_compares_unsigned -> int {
    big: u64 = u64(9223372036854775808);
    one: u64 = 1;
    if big > one {
        return 1;
    }
    return 0;
}

def:pub u64_max_above_zero -> int {
    return 1 if u64.MAX > u64(0) else 0;
}

def:pub u8_logical_shift -> int {
    a: u8 = 200;
    return int(a >> 1);
}

def:pub i8_arith_shift -> int {
    a: i8 = -2;
    return int(a >> 1);
}

def:pub u32_truediv_is_float -> float {
    a: u32 = 7;
    return a / 2;
}

def:pub u8_wrap_300 -> int {
    return int(u8.wrap(300));
}

def:pub i8_wrap_200 -> int {
    return int(i8.wrap(200));
}

def:pub u8_invert_zero -> int {
    a: u8 = 0;
    return int(~a);
}

def:pub u8_floordiv_mod -> int {
    a: u8 = 200;
    b: u8 = 3;
    return int(a // b) * 1000 + int(a % b);
}

def:pub i8_floor_semantics -> int {
    a: i8 = -7;
    b: i8 = 2;
    return int(a // b) * 1000 + int(a % b);
}

def:pub i8_min_div_m1_traps -> int {
    out: int = 0;
    try {
        q: i8 = i8.MIN // i8(-1);
        out = int(q);
    } except OverflowError {
        out = 1;
    }
    return out;
}

"""Only the quotient of MIN // -1 leaves the range. The remainder is 0, so
this returns a value rather than trapping (and the raw srem would fault)."""
def:pub i8_min_mod_m1 -> int {
    return int(i8.MIN % i8(-1)) + 7;
}

def:pub i8_neg_min_traps -> int {
    out: int = 0;
    try {
        n: i8 = -i8.MIN;
        out = int(n);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub i8_abs_min_traps -> int {
    out: int = 0;
    try {
        n: i8 = abs(i8.MIN);
        out = int(n);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub i32_max_plus_one_traps -> int {
    w: i32 = i32.MAX;
    out: int = 0;
    try {
        w = w + 1;
        out = int(w);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub i32_aug_traps -> int {
    w: i32 = i32.MAX;
    out: int = 0;
    try {
        w += 1;
        out = int(w);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u8_shl_overflow_traps -> int {
    a: u8 = 128;
    out: int = 0;
    try {
        b: u8 = a << 1;
        out = int(b);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u8_shift_count_traps -> int {
    a: u8 = 1;
    c: u8 = 8;
    out: int = 0;
    try {
        b: u8 = a << c;
        out = int(b);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u8_pow_traps -> int {
    out: int = 0;
    try {
        p: u8 = u8(2) ** 8;
        out = int(p);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub u8_pow_fits -> int {
    return int(u8(2) ** 7);
}

def:pub cast_u8_300_traps -> int {
    n: int = 300;
    out: int = 0;
    try {
        v: u8 = u8(n);
        out = int(v);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub cast_u8_negative_traps -> int {
    n: int = -1;
    out: int = 0;
    try {
        v: u8 = u8(n);
        out = int(v);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub cast_i8_from_u8_traps -> int {
    a: u8 = 200;
    out: int = 0;
    try {
        v: i8 = i8(a);
        out = int(v);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub cast_float_truncates -> int {
    f: float = -3.9;
    return int(i8(f));
}

def:pub cast_float_out_of_range_traps -> int {
    f: float = 300.5;
    out: int = 0;
    try {
        v: u8 = u8(f);
        out = int(v);
    } except OverflowError {
        out = 1;
    }
    return out;
}

def:pub widen_keeps_sign -> int {
    a: i8 = -5;
    w: i64 = a;
    return int(w);
}

def:pub widen_unsigned_zero_extends -> int {
    a: u8 = 200;
    w: i16 = a;
    n: int = a;
    return int(w) * 1000 + n;
}

def:pub wrapping_family -> int {
    a: i8 = 100;
    s = wrapping_add(a, a);
    d = wrapping_sub(u8(5), u8(6));
    m = wrapping_mul(u8(16), u8(16));
    n = wrapping_neg(i8.MIN);
    l = wrapping_shl(u8(1), 7);
    return int(s)
        + int(d) * 1000
        + int(m)
        + (1000000 if n == i8.MIN else 0)
        + int(l) * 10;
}

def:pub bounds -> int {
    return int(i8.MIN) + int(u16.MAX) + int(i32.MAX) // 1000000;
}

def:pub f32_rounds_per_op -> float {
    a: f32 = 0.1;
    b: f32 = 0.2;
    return a + b;
}

def:pub f32_literal_rounds -> float {
    f: f32 = 0.1;
    return f;
}

def:pub literal_adopts_i32 -> int {
    w: i32 = 1;
    w = w + 1;
    return int(w);
}

def:pub plain_int_is_not_sized -> int {
    big: int = 1 << 62;
    shifted = big << 2;
    m: int = -9223372036854775807 - 1;
    negated = -m;
    absolute = abs(m);
    p: int = 3;
    powered = p ** 41;
    ok = 0;
    if shifted == 0 {
        ok += 1;
    }
    if negated == m {
        ok += 1;
    }
    if absolute == m {
        ok += 1;
    }
    if powered != 0 {
        ok += 1;
    }
    return ok;
}


obj WordBuffer {
    has words: list[u32] = [u32(0xffffffff), u32(7)];
}

def:pub u32_list_read_preserves_width -> int {
    values: list[u32] = [u32(0xffffffff), u32(3)];
    value = wrapping_add(values[0], values[1]);
    values[1] = value;
    return int(values[1] ^ u32(7));
}

def:pub u32_field_list_read_preserves_width -> int {
    buffer = WordBuffer();
    return int(buffer.words[0] >> u32(31)) + int(wrapping_mul(buffer.words[1], u32(3)));
}

def:pub i8_list_read_preserves_sign -> int {
    values: list[i8] = [i8(-128), i8(1)];
    return int(values[0] >> i8(1)) + int(values[1]);
}
