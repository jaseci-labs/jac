def math_gcd_iter(a: int, b: int) -> int {
    t: int = 0;
    while (b != 0) {
        t = a % b;
        a = b;
        b = t;
    }

    return a;
}
