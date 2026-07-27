"""Regression fixtures: sub-64-bit integer arithmetic (issue #7466-era
i32 width mismatch) and Python-congruent true division (int / int -> float)."""

def add32(a: i32, b: i32) -> i32 {
    return a + b;
}

def sub32(a: i32, b: i32) -> i32 {
    return a - b;
}

def mul32(a: i32, b: i32) -> i32 {
    return a * b;
}

def truediv(a: int, b: int) -> float {
    return a / b;
}

def floordiv(a: int, b: int) -> int {
    return a // b;
}
