def math_ctz_small(n: int) -> int {
    r: int = 0;
    if (n == 0) {
        return -1;
    }

    r = 0;
    while ((n & 1) == 0) {
        n >>= 1;
        r += 1;
    }

    return r;
}
