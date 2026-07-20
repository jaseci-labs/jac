"""Generator functions lowered as resumable state machines.

A `def` containing `yield` compiles to (a) a creation function returning a
`JacIter` whose state is an RC-managed frame holding the resume point,
parameters, and every local (all frame slots, so resuming mid-loop is
sound), and (b) a private resume function `i1(i8* frame, i8* out)` that
switches on the resume point. Consumers (`for`, first-class `next()`, the
lazy adapters) speak the existing JacIter ABI, so nothing changes on the
consumption side.
"""

def counter(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i = i + 1;
    }
}

def total_of(n: int) -> int {
    total = 0;
    for v in counter(n) {
        total = total + v;
    }
    return total;
}

def early_break(n: int, stop: int) -> int {
    seen = 0;
    for v in counter(n) {
        if v >= stop {
            break;
        }
        seen = seen + 1;
    }
    return seen;
}

def manual_next(n: int) -> int {
    it = counter(n);
    a = next(it);
    b = next(it);
    return a * 10 + b;
}

def two_streams(n: int) -> int {
    s = 0;
    for a in counter(n) {
        for b in counter(n) {
            s = s + a * b;
        }
    }
    return s;
}

def for_yield(n: int) -> Iterator[int] {
    for i in range(n) {
        yield i * 2;
    }
}

def total_for_yield(n: int) -> int {
    t = 0;
    for v in for_yield(n) {
        t = t + v;
    }
    return t;
}

def stop_early(n: int, cutoff: int) -> Iterator[int] {
    i = 0;
    while i < n {
        if i >= cutoff {
            return;
        }
        yield i;
        i = i + 1;
    }
}

def total_stop_early(n: int, cutoff: int) -> int {
    t = 0;
    for v in stop_early(n, cutoff) {
        t = t + v;
    }
    return t;
}

def echo_n(s: str, n: int) -> Iterator[str] {
    i = 0;
    while i < n {
        yield s;
        i = i + 1;
    }
}

def echo_len(s: str) -> int {
    t = 0;
    for w in echo_n(s, 3) {
        t = t + len(w);
    }
    return t;
}

def doubled_total(n: int) -> int {
    t = 0;
    for v in map(lambda (x: int) { x * 2; }, counter(n)) {
        t = t + v;
    }
    return t;
}
