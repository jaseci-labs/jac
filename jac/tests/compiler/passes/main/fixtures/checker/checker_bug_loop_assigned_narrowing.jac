"""Fixture for #LOOPNARROW : loop-assigned Optional local lost narrowing."""

def first_or_zero(items: list[int]) -> int {
    fb: int | None = None;
    for it in items {
        fb = it;
    }
    if fb is not None {
        return fb;          # error (before)
    }
    return 0;               # ok
}

def last_or_zero(items: list[int]) -> int {
    fb: int | None = None;
    i = 0;
    while i < len(items) {
        fb = items[i];
        i += 1;
    }
    if fb is not None {
        return fb;          # error (before)
    }
    return 0;               # ok
}

def sum_with(x: int | None, items: list[int]) -> int {
    total = 0;
    if x is not None {
        for it in items {
            total = total + x;  # ok
        }
    }
    return total;               # ok
}
