"""Tuple binding patterns retain their types for native consumers."""

def comprehension -> int {
    values: dict[str, int] = {"a": 3, "bb": 7};
    inverse = {v: k for (k, v) in values.items()};
    lengths = [len(k) * v for (k, v) in values.items()];
    unique = {v for (k, v) in values.items()};
    return len(inverse[7]) + lengths[0] + lengths[1] + len(unique);
}

def loop -> int {
    values: dict[str, int] = {"a": 3, "bb": 7};
    result = 0;
    for (k, v) in values.items() {
        result += len(k) * v;
    }
    return result;
}
