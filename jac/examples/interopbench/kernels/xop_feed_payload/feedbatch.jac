def:pub feed_batch(seed: int, n: int) -> list[int] {
    out: list[int] = [];
    value = seed;
    for i in range(n) {
        value = (value * 1103515245 + 12345 + i) % 2147483648;
        out.append(value);
    }
    return out;
}
