"""Test fixture: C struct value-type coercion at call boundaries.

Declares C structs and extern functions that take/return them by value.
The compiler should:
  - Use value types in extern 'declare' statements
  - Use ABI-coerced integer types for small integer-only structs
  - Use pointer types for Jac-side functions
  - Auto-coerce pointer->value (Jac->C) and value->pointer (C->Jac)
"""

import from "/usr/lib/libm.so.6" {
    # Large struct (128-bit, float fields) -- passed as struct by value
    obj Vec2 {
        has x: f64,
            y: f64;
    }

    # Small struct (32-bit, integer fields) -- ABI-coerced to i32
    obj Color {
        has r: u8,
            g: u8,
            b: u8,
            a: u8;
    }

    def sqrt(x: f64) -> f64;
    def draw(x: i32, y: i32, color: Color) -> None;
}

def make_vec(x: float, y: float) -> Vec2 {
    v = Vec2(x=x, y=y);
    return v;
}

def vec_length(v: Vec2) -> float {
    return sqrt(v.x * v.x + v.y * v.y);
}

def test_draw() -> None {
    c = Color(r=255, g=0, b=0, a=255);
    draw(10, 20, c);
}
