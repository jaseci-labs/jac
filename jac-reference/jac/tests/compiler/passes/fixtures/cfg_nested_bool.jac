def deep(a: int, b: int, c: int, d: int) -> int {
    if a > 0 and (b > 0 and (c > 0 or d > 0)) {
        return 1;
    }
    return 0;
}
