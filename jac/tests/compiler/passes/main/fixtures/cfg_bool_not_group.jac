def mixed(a: int, b: int, c: int) -> int {
    if a > 0 and not (b > 0 or c > 0) {
        return 1;
    }
    return 0;
}
