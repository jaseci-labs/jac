"""A `self: own T` method consumes its receiver: the callee owns and drops it,
the caller's binding is dead afterwards (#8984 rule 2)."""

obj Counter {
    has n: int = 0;

    def inc { self.n += 1; }
    def get -> int { return self.n; }
    def into_total(self: own Counter) -> int { return self.n * 10; }
    def drop { print("drop counter " + str(self.n)); }
}

def run -> int {
    c: own Counter = Counter();
    c.inc();
    c.inc();
    base = c.get();
    return base + c.into_total();
}

with entry { print(run()); print("done"); }
