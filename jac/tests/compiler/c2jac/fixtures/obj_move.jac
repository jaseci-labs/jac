"""Move-vs-copy fixture driven by OwnershipFacts.

`Holder` stores a fresh constructor result into its field: the value is owned, so
its refcount moves into the field and the retain is elided. `Wrap` stores a
borrowed constructor parameter: the value is aliased, so it is copied and
retained. Both are released once by the destructor, so neither leaks nor
double-frees.
"""

obj Counter {
    has n: int;

    def init(v: int) {
        self.n = v;
    }

    def get -> int {
        return self.n;
    }
}

obj Holder {
    has c: Counter;

    def init {
        self.c = Counter(5);
    }

    def peek -> int {
        return self.c.get();
    }
}

obj Wrap {
    has c: Counter;

    def init(inner: Counter) {
        self.c = inner;
    }

    def peek -> int {
        return self.c.get();
    }
}

def run_move -> int {
    h = Holder();
    w = Wrap(Counter(9));
    return (h.peek() + w.peek());
}
