import time;

def erase_keys(n: int, reverse: bool) -> float {
    values: dict[int, int] = {};
    for i in range(n) {
        values[i] = i;
    }
    total = 0;
    started = time.perf_counter();
    for i in range(n) {
        key = n - i - 1 if reverse else i;
        total += values.pop(key);
    }
    elapsed = time.perf_counter() - started;
    assert len(values) == 0;
    assert total == n * (n - 1) // 2;
    return elapsed;
}
