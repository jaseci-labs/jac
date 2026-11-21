"""The residual generator shapes: yield from, bare yield, return <value>,
yield inside try, and yielding bodies inside indexed for-loops.

`yield from <iterable>` lowers as an iterator-driven loop that suspends per
element (the inner iterable goes through the same `_build_iter_from_expr`
seam as for-loops, so generators, containers, strings, and adapters all
work). Bare `yield` suspends with the element type's unit value (None on
the Python surface has no native carrier; consumers observe the iteration,
not the value). `return <expr>` in a generator evaluates the expression and
stops iteration; the StopIteration value channel has no consumer on the
JacIter ABI, so the value is discarded by design. A yield inside `try`
pops this frame's handler chain before suspending and re-arms it (fresh
setjmp in the new invocation) on resume, so exceptions raised between
yields keep resolving to the generator's own handlers, while exceptions in
the consumer never falsely land in a suspended generator's try. Finally
blocks run on normal completion and exception paths, not on mid-suspension
abandonment. Yielding loop bodies over lists/dicts/strings keep the
collection and its length in frame slots so the loop can resume mid-flight.
"""

def counter(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i = i + 1;
    }
}

def chain(n: int) -> Iterator[int] {
    yield from counter(n);
    yield from [100, 200];
    yield 999;
}

def total_chain(n: int) -> int {
    t = 0;
    for v in chain(n) {
        t = t + v;
    }
    return t;
}

def spell(s: str) -> Iterator[str] {
    yield from s;
}

def count_chars(s: str) -> int {
    t = 0;
    for c in spell(s) {
        t = t + len(c);
    }
    return t;
}

def pacer(n: int) -> Iterator[None] {
    i = 0;
    while i < n {
        yield ;
        i = i + 1;
    }
}

def count_pacer(n: int) -> int {
    t = 0;
    for step in pacer(n) {
        t = t + 1;
    }
    return t;
}

def upto_return(n: int) -> Iterator[int] {
    yield 1;
    yield 2;
    return n * 10;
}

def total_upto_return(n: int) -> int {
    t = 0;
    for v in upto_return(n) {
        t = t + v;
    }
    return t;
}

def doubles(xs: list[int]) -> Iterator[int] {
    for x in xs {
        yield x * 2;
    }
}

def total_doubles -> int {
    xs = [1, 2, 3];
    t = 0;
    for v in doubles(xs) {
        t = t + v;
    }
    return t;
}

def keys_of(d: dict[str, int]) -> Iterator[str] {
    for k in d {
        yield k;
    }
}

def count_keys -> int {
    d = {"a": 1, "bb": 2};
    t = 0;
    for k in keys_of(d) {
        t = t + len(k);
    }
    return t;
}

def per_char(s: str) -> Iterator[str] {
    for c in s {
        yield c;
    }
}

def count_per_char(s: str) -> int {
    t = 0;
    for c in per_char(s) {
        t = t + len(c);
    }
    return t;
}

def resilient(n: int) -> Iterator[int] {
    try {
        yield 1;
        if n > 0 {
            raise ValueError("boom");
        }
        yield 2;
    } except ValueError {
        yield 3;
    }
    yield 4;
}

def total_resilient(n: int) -> int {
    t = 0;
    for v in resilient(n) {
        t = t + v;
    }
    return t;
}
