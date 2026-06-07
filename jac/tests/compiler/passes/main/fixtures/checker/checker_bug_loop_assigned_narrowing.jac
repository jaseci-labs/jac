"""Fixture for #LOOPNARROW : loop-assigned Optional local lost narrowing."""

# for-loop, direct assignment in body
def first_or_zero(items: list[int]) -> int {
    fb: int | None = None;
    for it in items {
        fb = it;
    }
    if fb is not None {
        return fb;
    }
    return 0;
}

# while-loop, assignment in body
def last_or_zero(items: list[int]) -> int {
    fb: int | None = None;
    i = 0;
    while i < len(items) {
        fb = items[i];
        i += 1;
    }
    if fb is not None {
        return fb;
    }
    return 0;
}

# pre-loop narrowing must survive into a read-only loop body
def sum_with(x: int | None, items: list[int]) -> int {
    total = 0;
    if x is not None {
        for it in items {
            total = total + x;
        }
    }
    return total;
}
