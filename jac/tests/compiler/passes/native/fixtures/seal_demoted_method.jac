"""Fixture: one method the native backend cannot lower, nothing calls it.

`Gauge.unlowerable` calls `eval`, which type-checks (it is a Python builtin)
but has no native lowering, so the failure surfaces inside the emitter and the
method is demoted to Python-only. In-process that is a speed cost and nothing
more. In a *sealed* artifact there is no Python left to fall back to, so the
demotion ships as an `abort()` stub that kills the process at the first call
with no diagnostic -- which is exactly what the seal-integrity gate must
refuse.

Nothing calls `unlowerable`: a call site would emit E5092 and fail the seal
through the ordinary error path, which is not the hole being pinned here.
"""

obj Gauge {
    has total: int = 0;

    def good(x: int) -> int {
        self.total += x;
        return self.total;
    }

    def unlowerable(x: int) -> int {
        z = eval("x + 1");
        return x;
    }
}

def add(a: int, b: int) -> int {
    return a + b;
}

def run(n: int) -> int {
    g = Gauge();
    i = 0;
    while i < n {
        g.good(add(i, 1));
        i += 1;
    }
    return g.total;
}
