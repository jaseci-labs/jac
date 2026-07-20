def:pub charge_card(seed: int, work: int) -> int {
    value = seed;
    for i in range(work) {
        value = (value * 1103515245 + 12345 + i) % 2147483648;
    }
    return value;
}
