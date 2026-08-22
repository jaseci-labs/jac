"""Fixture: a module the native backend lowers in full.

Every method here has a native lowering, so an AOT seal of this module must
produce a shared library with no abort stubs in it. It is the control case for
the seal-integrity gate: a clean closure still seals, and the emitted artifact
passes the dlopen + canary smoke.
"""

obj Counter {
    has total: int = 0;

    def bump(n: int) -> int {
        self.total += n;
        return self.total;
    }
}

def add(a: int, b: int) -> int {
    return a + b;
}

def run(n: int) -> int {
    c = Counter();
    i = 0;
    while i < n {
        c.bump(add(i, 1));
        i += 1;
    }
    return c.total;
}
