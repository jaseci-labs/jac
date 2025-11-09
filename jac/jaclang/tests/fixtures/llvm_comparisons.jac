"""Test fixture for LLVM comparison operations."""

def int_equals(a: int, b: int) -> bool {
    return a == b;
}

def int_not_equals(a: int, b: int) -> bool {
    return a != b;
}

def int_less_than(a: int, b: int) -> bool {
    return a < b;
}

def int_greater_than(a: int, b: int) -> bool {
    return a > b;
}

def float_equals(a: float, b: float) -> bool {
    return a == b;
}

def complex_comparison(x: int, y: int) -> bool {
    a: bool = x > y;
    b: bool = x < 10;
    return a;
}
