"""Move-vs-copy fixture driven by OwnershipFacts callee conventions.

`Holder` stores a fresh constructor result into its field: owned, so its refcount
moves into the field and the retain is elided. `Wrap.init` consumes its parameter
(it escapes into the sole field and is used nowhere else), so the whole call is a
move: the caller hands the owned `Counter(9)` straight in and `Wrap__new` stores it
without retaining. `Keep.init` also reads its parameter, so the parameter is only
borrowed: `Keep__new` retains on store and the caller releases its owned temporary
once the statement completes. All three balance -- nothing leaks or double-frees.
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

obj Keep {
    has c: Counter;
    has seed: int;

    def init(inner: Counter) {
        self.seed = inner.get();
        self.c = inner;
    }

    def total -> int {
        return (self.seed + self.c.get());
    }
}

def run_move -> int {
    h = Holder();
    w = Wrap(Counter(9));
    k = Keep(Counter(4));
    return ((h.peek() + w.peek()) + k.total());
}
