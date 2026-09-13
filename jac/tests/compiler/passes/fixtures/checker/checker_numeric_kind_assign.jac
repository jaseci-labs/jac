"""Numeric assignability along the fixed-width lattice.

Fixed-width primitives (i8..u64, f32, f64) are real types: a conversion is
implicit only when it is value-preserving (widening, unsigned into a
strictly wider signed, exactly-representable int-kind into float-kind).
Narrowing and sign changes are explicit casts; FloatKind -> IntKind stays
banned and is covered by checker_numeric_kind_disallowed.jac.
"""

# ---------- Literal -> primitive ----------
def to_f64 -> f64 {
    x: f64 = 3.14;
    return x;
}

def to_i32 -> i32 {
    x: i32 = 42;
    return x;
}

def to_f32 -> f32 {
    x: f32 = 1.5;
    return x;
}

def to_u8 -> u8 {
    x: u8 = 7;
    return x;
}

# ---------- Cross-width same-kind ----------
def f32_to_f64(x: f32) -> f64 {
    return x;
}

def f64_to_f32(x: f64) -> f32 {
    return f32(x);
}

def i8_to_i64(x: i8) -> i64 {
    return x;
}

def i64_to_u32(x: i64) -> u32 {
    return u32(x);
}

def u16_to_i32(x: u16) -> i32 {
    return x;
}

# ---------- IntKind -> FloatKind ----------
def i32_to_f64(x: i32) -> f64 {
    return x;
}

# ---------- Arithmetic overload resolution (E1055) ----------
def add_i32(a: i32, b: i32) -> i32 {
    return a + b;
}

def add_i32_int_literal(a: i32) -> i32 {
    return a + 1;
}

def bit_and_i32(a: i32, b: i32) -> i32 {
    return a & b;
}

def mixed_width_add(a: i32, b: i64) -> i64 {
    return a + b;
}
