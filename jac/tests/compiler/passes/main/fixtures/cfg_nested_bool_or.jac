def deep_or(a: int, b: int, c: int, d: int) -> int {
    if a > 0 or (b > 0 or (c > 0 and d > 0)) {
        return 1;
    }
    return 0;
}
