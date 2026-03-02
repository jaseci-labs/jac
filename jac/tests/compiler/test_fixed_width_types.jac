"""Tests for fixed-width integer and float types as language-level types."""

# ── Type annotations ────────────────────────────────────────
test "fixed-width integer types can be used as annotations" {
    a: i8 = 1;
    b: u8 = 2;
    c: i16 = 3;
    d: u16 = 4;
    e: i32 = 5;
    f: u32 = 6;
    g: i64 = 7;
    h: u64 = 8;
    assert a + b + c + d + e + f + g + h == 36;
}

test "fixed-width float types can be used as annotations" {
    x: f32 = 1.5;
    y: f64 = 2.5;
    assert x + y == 4.0;
}

# ── Function signatures ─────────────────────────────────────
def add_i32(a: i32, b: i32) -> i32 {
    return a + b;
}

def scale_f32(val: f32, factor: f64) -> float {
    return val * factor;
}

test "fixed-width types work in function signatures" {
    assert add_i32(10, 20) == 30;
    assert scale_f32(2.0, 3.0) == 6.0;
}
