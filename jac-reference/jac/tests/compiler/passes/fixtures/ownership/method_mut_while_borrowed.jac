obj Counter {
    has n: int = 0;

    def inc { self.n += 1; }
}

def show(c: &Counter) -> int { return c.n; }

with entry {
    c: own Counter = Counter();
    v: &Counter = &c;
    c.inc();
    print(show(v));
}
