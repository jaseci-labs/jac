"""Regression: CPython floor semantics for negative // and %."""

def floordiv(a: int, b: int) -> int {
    return a // b;
}

def intmod(a: int, b: int) -> int {
    return a % b;
}

def float_floordiv(a: float, b: float) -> float {
    return a // b;
}

def float_mod(a: float, b: float) -> float {
    return a % b;
}

def divmod_quot(a: int, b: int) -> int {
    return divmod(a, b)[0];
}

def divmod_rem(a: int, b: int) -> int {
    return divmod(a, b)[1];
}
