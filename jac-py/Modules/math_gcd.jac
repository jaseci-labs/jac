def c_idiv(a: int, b: int) -> int {
    q = a // b;
    return q + (1 if (a % b != 0) and ((a < 0) != (b < 0)) else 0);
}

def c_imod(a: int, b: int) -> int {
    return a - c_idiv(a, b) * b;
}

def _abs_long(x: int) -> int {
    if (x < 0) {
        return -x;
    }

    return x;
}

def math_gcd_long(a: int, b: int) -> int {
    a = _abs_long(a);
    b = _abs_long(b);
    while (b != 0) {
        t: int = b;
        b = c_imod(a, b);
        a = t;
    }

    return a;
}
