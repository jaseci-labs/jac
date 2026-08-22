def math_isqrt_small(n: int) -> int {
    x: int = 0;
    y: int = 0;
    if (n <= 1) {
        return n;
    }

    x = n;
    while True {
        y = (x + (n // x)) / 2;
        if (y >= x) {
            return x;
        }

        x = y;
    }
}
