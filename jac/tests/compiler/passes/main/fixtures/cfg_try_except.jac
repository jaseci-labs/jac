def risky(x: int) -> int {
    try {
        y = 10 / x;
    } except Exception {
        y = 0;
    } finally {
        print(y);
    }
    return y;
}
