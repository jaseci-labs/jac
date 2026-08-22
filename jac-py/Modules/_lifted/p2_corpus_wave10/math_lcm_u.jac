def math_gcd_u(a: int, b: int) -> int {
    t: int = 0;
    while (b != 0) {
        t = a % b;
        a = b;
        b = t;
    }

    return a;
}

def math_lcm_u(a: int, b: int) -> int {
    g: int = 0;
    if ((a == 0) or (b == 0)) {
        return 0;
    }

    g = math_gcd_u(a, b);
    return ((a // g) * b);
}
