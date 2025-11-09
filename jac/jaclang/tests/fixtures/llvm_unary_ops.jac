"""Test fixture for LLVM unary operations."""

def negate_int(x: int) -> int {
    return -x;
}

def negate_float(x: float) -> float {
    return -x;
}

def logical_not(x: bool) -> bool {
    return not x;
}

def double_negate(x: int) -> int {
    return -(-x);
}

def unary_plus(x: int) -> int {
    return +x;
}
