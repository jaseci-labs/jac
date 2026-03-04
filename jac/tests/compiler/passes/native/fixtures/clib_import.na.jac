"""Test fixture: C library import syntax produces extern declarations."""

import from "/usr/lib/libm.so.6" {
    def sqrt(x: f64) -> f64;
    def pow(base: f64, exp: f64) -> f64;
}

def hypotenuse(a: f64, b: f64) -> f64 {
    return sqrt(a * a + b * b);
}
