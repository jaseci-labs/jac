"""Numeric-kind assignability: FloatKind -> IntKind stays banned.

Same-kind allowance must not erase the existing float -> int ban. Each
of these assignments / returns must remain a type error.
"""

def f64_to_i32(x: f64) -> i32 {
    return x;  # <-- Error
}

def f32_to_i64(x: f32) -> i64 {
    return x;  # <-- Error
}

def float_to_u8(x: float) -> u8 {
    return x;  # <-- Error
}

def assign_f_to_i() -> int {
    y: float = 3.14;
    x: int = y;  # <-- Error
    return x;
}
