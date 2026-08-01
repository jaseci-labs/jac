"""yield inside finally (#7626 A6).

A finally block runs exactly once but is reachable from two
continuations (normal completion and the dispatch path), so a suspension
point inside one records its pending continuation in a frame slot and
the resume re-arm generalizes from the try machinery. Full iteration
yields the try value then the finally value ([n, n+1], CPython parity).
Early abandonment simply drops the frame (native drop releases slots; it
does not resume the finally, so no CPython-style "generator ignored
GeneratorExit" noise).
"""

def yf(n: int) -> Iterator[int] {
    try {
        yield n;
    } finally {
        yield n + 1;
    }
}

def sum_yf(n: int) -> int {
    t = 0;
    for x in yf(n) {
        t += x;
    }
    return t;
}

def first_yf(n: int) -> int {
    for x in yf(n) {
        return x;
    }
    return -1;
}
