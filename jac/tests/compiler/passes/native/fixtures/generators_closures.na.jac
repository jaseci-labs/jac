"""Capturing lambdas inside generator frames (#7626 A2).

A generator's locals live in a heap frame, not stack allocas, so closure
cells must be allocated in the creation function and their handles stored
in frame slots -- the resume fn reloads them instead of re-allocating per
resume. These shapes pin that: a lambda escaping into a list value inside
a generator body, and a capturing lambda passed to the lazy map adapter.
"""

def gen_scaled(k: int) -> Iterator[int] {
    f = lambda (x: int) -> int { x * k; };
    fns: list[Callable[[int], int]] = [f];
    g = fns[0];
    yield g(1);
    yield g(2);
}

def sum_gen_scaled(k: int) -> int {
    t = 0;
    for v in gen_scaled(k) {
        t += v;
    }
    return t;
}

def gen_mixed(k: int, base: int) -> Iterator[int] {
    f = lambda (x: int) -> int { x * k; };
    fns: list[Callable[[int], int]] = [f];
    g = fns[0];
    yield g(base);
    yield g(base + 1);
}

def sum_gen_mixed(k: int, base: int) -> int {
    t = 0;
    for v in gen_mixed(k, base) {
        t += v;
    }
    return t;
}

def gen_mapped(k: int) -> Iterator[int] {
    for v in map(lambda (x: int) -> int { x + k; }, [1, 2, 3]) {
        yield v;
    }
}

def sum_gen_mapped(k: int) -> int {
    t = 0;
    for v in gen_mapped(k) {
        t += v;
    }
    return t;
}
