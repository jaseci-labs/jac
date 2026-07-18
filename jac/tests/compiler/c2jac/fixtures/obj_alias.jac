"""Reference-local aliasing fixture driven by OwnershipFacts.

`run_alias` copies a reference into a second local that co-owns it: the source
is used again afterward, so the copy must retain and both locals release once
(balanced -- without the retain this would double-free). `run_transfer` copies
at the source's last use: ownership moves, the retain is elided, and the source
is not released.
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

def run_alias -> int {
    a = Counter(3);
    b = a;
    return (a.get() + b.get());
}

def run_transfer -> int {
    a = Counter(7);
    b = a;
    return b.get();
}
