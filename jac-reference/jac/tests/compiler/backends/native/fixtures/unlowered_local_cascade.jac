"""Fixture: a binding that cannot lower, then reads of the name it never bound.

`eval` type-checks (it is a Python builtin) but has no native lowering, so the
emitter fails on the right-hand side and `probe` never gets a slot. Every later
mention of `probe` is a consequence of that one line: the compare, the bare
read in condition position and the ternary all have nothing to read.

A demotion report is only useful if it names the cause. Reporting the reads as
well turns one root cause into four diagnostics with three different expression
kinds, which is how a demotion gets attributed to the wrong subsystem.

`chained` pins that the poison propagates: `mirror` is bound from `probe`, so
it has no slot either and its own read is just as much a consequence.
`unpacked` pins the tuple form, where one failed call leaves two names unbound.
"""

obj C {
    """A sibling that cannot lower, so its callers cannot bind from it."""
    def pair(x: int) -> tuple[int, int] {
        z = eval("x");
        return (x, x + 1);
    }

    def cascaded(x: int) -> int {
        probe = eval("x + 1");
        if probe is not None {
            x = x + 1;
        }
        if probe {
            x = x + 2;
        }
        y = 1 if probe is None else 2;
        return x + y;
    }

    def chained(x: int) -> int {
        probe = eval("x + 1");
        mirror = probe;
        if mirror is not None {
            x = x + 1;
        }
        return x;
    }

    def unpacked(x: int) -> int {
        (lo, hi) = self.pair(x);
        if lo > hi {
            x = x + 1;
        }
        return x + lo;
    }

    def clean(x: int) -> int {
        return x + 1;
    }
}
