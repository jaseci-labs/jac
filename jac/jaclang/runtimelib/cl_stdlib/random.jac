def:pub randint(a: int, b: int) -> int {
    if a >= b {
        return a;
    }
    return a + (b - a) // 2;
}
