def math_popcount_u(n: int) -> int {
    c: int = 0;
    c = 0;
    while (n != 0) {
        c += n & 1;
        n >>= 1;
    }

    return c;
}
