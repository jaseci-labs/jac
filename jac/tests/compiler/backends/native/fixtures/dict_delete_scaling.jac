def erase_keys(n: int, reverse: bool) -> int {
    values: dict[int, int] = {};
    for i in range(n) {
        values[i] = i;
    }
    total = 0;
    for i in range(n) {
        key = n - i - 1 if reverse else i;
        total += values.pop(key);
    }
    assert len(values) == 0;
    return total;
}
