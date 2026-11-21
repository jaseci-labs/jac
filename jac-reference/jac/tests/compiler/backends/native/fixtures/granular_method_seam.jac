"""Fixture: one method's capability violation, siblings clean.

`Calc.bad` imports `collections` in its body -- a Python-only module the
native pathway statically refuses (E5090 from the capability authority,
not an emit-time failure). Granular demotion must turn exactly that
method into a seam and leave `Calc.good` natively lowered.
"""

obj Calc {
    def good(x: int) -> int {
        return x * 2;
    }

    def bad(x: int) -> int {
        import collections;
        d = collections.OrderedDict();
        return x + len(d);
    }
}

with entry {
    print(Calc().good(3));
}
