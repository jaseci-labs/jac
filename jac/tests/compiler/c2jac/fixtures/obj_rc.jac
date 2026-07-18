"""Reference-object fixture for the jac2c runtime-ABI backend.

Exercises heap allocation via the RC runtime, an `init` constructor, instance
methods with an explicit `self`, member access through the object pointer, a
reference-typed field (retain on store, release in the destructor), and
release of owned locals at scope exit.
"""

obj Counter {
    has n: int;

    def init(start: int) {
        self.n = start;
    }

    def bump -> int {
        self.n = self.n + 1;
        return self.n;
    }

    def get -> int {
        return self.n;
    }
}

obj Box {
    has c: Counter;

    def init(inner: Counter) {
        self.c = inner;
    }

    def peek -> int {
        return self.c.get();
    }
}

def run_counter -> int {
    c = Counter(10);
    a = c.bump();
    b = c.bump();
    return (a + b);
}

def run_box -> int {
    inner = Counter(41);
    box = Box(inner);
    return box.peek();
}
