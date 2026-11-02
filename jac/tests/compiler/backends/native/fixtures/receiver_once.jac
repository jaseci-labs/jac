"""A method call evaluates a literal receiver once."""

obj Counter {
    has calls: int = 0;
}

def tick(counter: Counter, n: int) -> int {
    counter.calls += 1;
    return n;
}

def run -> int {
    counter = Counter();
    total = 0;
    for i in range(50) {
        total += len(f"x{tick(counter, i)}".upper());
        total += len(f"y{i}".encode("utf-8"));
        total += len(b"abc".decode("utf-8"));
    }
    return total * 1000 + counter.calls;
}

with entry {
    print(run());
}
