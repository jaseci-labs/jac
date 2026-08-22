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

def _gcd_long(a: int, b: int) -> int {
    a = _abs_long(a);
    b = _abs_long(b);
    while (b != 0) {
        t: int = b;
        b = c_imod(a, b);
        a = t;
    }

    return a;
}

def math_lcm_long(a: int, b: int) -> int {
    g: int = 0;
    if ((a == 0) or (b == 0)) {
        return 0;
    }

    g = _gcd_long(a, b);
    a = _abs_long(a);
    b = _abs_long(b);
    return (c_idiv(a, g) * b);
}
