def evens(n: int) -> Iterator[int] {
    for i in range(n) {
        yield i * 2;
    }
}

def chained(n: int) -> Iterator[int] {
    yield from evens(n);
    yield 100;
}

def total(n: int) -> int {
    t = 0;
    for v in chained(n) {
        t = t + v;
    }
    return t;
}

with entry {
    print("total:", total(4));
}
