"""Test fixture for LLVM type coercion."""

def int_to_float(x: int) -> float {
    result: float = x + 2.5;
    return result;
}

def float_to_int(x: float) -> int {
    result: int = x;
    return result;
}

def mixed_arithmetic(a: int, b: float) -> float {
    return a * b + 10;
}

def bool_test(x: int) -> bool {
    return x > 5;
}
