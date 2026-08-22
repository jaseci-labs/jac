def math_ilog2_small(n: int) -> int {
    r: int = 0;
    if (n == 0) {
        return -1;
    }

    r = 0;
    while (n > 1) {
        n >>= 1;
        r += 1;
    }

    return r;
}
