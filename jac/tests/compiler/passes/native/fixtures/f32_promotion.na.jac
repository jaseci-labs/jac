"""Regression fixtures (#7593 item 1): f32 operands promote to double in
arithmetic/comparisons; results narrow back at typed sinks."""

def mixed_add(a: f32, b: f64) -> f64 {
    return a + b;
}

def mixed_add_rev(a: f64, b: f32) -> f64 {
    return a + b;
}

def same_add(a: f32, b: f32) -> f64 {
    return a + b;
}

def same_add_narrow(a: f32, b: f32) -> f32 {
    return a + b;
}

def mixed_mul(a: f32, b: f64) -> f64 {
    return a * b;
}

def mixed_div(a: f32, b: f64) -> f64 {
    return a / b;
}

def mixed_mod(a: f32, b: f64) -> f64 {
    return a % b;
}

def mixed_floordiv(a: f32, b: f64) -> f64 {
    return a // b;
}

def f32_int_add(a: f32, n: int) -> f64 {
    return a + n;
}

def cmp_mixed_lt(a: f32, b: f64) -> bool {
    return a < b;
}

def cmp_same_lt(a: f32, b: f32) -> bool {
    return a < b;
}

def cmp_chain(a: f32, b: f64, c: f64) -> bool {
    return a < b < c;
}

def neg32(a: f32) -> f64 {
    return -a;
}

obj P {
    has x: f32 = 1.5;
}

def field_aug(delta: f64) -> f64 {
    p = P();
    p.x += delta;
    return p.x;
}
