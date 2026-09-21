"""A range held in a variable: iterated, measured, and re-measured empty."""

def walk_up(n: int) -> int {
    r = range(0, n, 2);
    total = 0;
    for x in r {
        total += x;
    }
    return total * 100 + len(r);
}

def walk_down(n: int) -> int {
    r = range(n, 0, -3);
    total = 0;
    for x in r {
        total += x;
    }
    return total * 100 + len(r);
}

def measure(n: int) -> int {
    return len(range(n)) * 1000
        + len(range(5, 5)) * 100
        + len(range(3, 1)) * 10
        + len(range(1, 8, 3));
}
