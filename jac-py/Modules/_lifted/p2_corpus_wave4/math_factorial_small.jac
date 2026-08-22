def math_factorial_small(n: int) -> int {
    result: int = 1;
    i: int = 2;
    if (n <= 1) {
        return 1;
    }

    while (i <= n) {
        result *= i;
        i = i + 1;
    }

    return result;
}
