"""Iterator-protocol for-loops inside a generator body.

The loop's iterator lives in a frame slot so it survives every suspension,
and the frame's drop function releases whatever that slot still holds. The
slot must therefore own exactly one reference while the loop runs and be
cleared when the loop releases it on exit; otherwise the drop releases the
iterator a second time (an owned adapter such as `enumerate(...)` is freed
twice), or releases a reference it never took (a borrowed iterator).
"""

def counter(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i = i + 1;
    }
}

def pick(values: list[int], at: int) -> Iterator[int] {
    for (index, value) in enumerate(values) {
        if index == at {
            yield value;
        }
    }
}

def pick_pairs(values: list[int], at: int) -> Iterator[int] {
    for pair in enumerate(values) {
        if pair[0] == at {
            yield pair[1];
        }
    }
}

def total_picked(rounds: int) -> int {
    values = [10, 20, 30];
    total = 0;
    for round in range(rounds) {
        for got in pick(values, 1) {
            total = total + got;
        }
        for got in pick_pairs(values, 2) {
            total = total + got;
        }
    }
    return total;
}

def make_counter(n: int) -> Iterator[int] {
    return counter(n);
}

def alias(it: Iterator[int]) -> Iterator[int] {
    return it;
}

def relay_owned(it: Iterator[int]) -> Iterator[int] {
    for value in alias(it) {
        yield value;
    }
}

def relay_borrowed(it: Iterator[int]) -> Iterator[int] {
    for value in it {
        yield value;
    }
}

def drain_owned(it: Iterator[int]) -> int {
    total = 0;
    for value in relay_owned(it) {
        total = total + value;
    }
    return total;
}

def drain_borrowed(it: Iterator[int]) -> int {
    total = 0;
    for value in relay_borrowed(it) {
        total = total + value;
    }
    return total;
}

def first_borrowed(it: Iterator[int]) -> int {
    for value in relay_borrowed(it) {
        return value;
    }
    return -1;
}
