def math_pow2_check(n: int) -> int {
    if (n == 0) {
        return 0;
    }

    return ((n & (n - 1)) == 0);
}
