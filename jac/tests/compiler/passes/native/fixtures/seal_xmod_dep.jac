"""Fixture: a native cross-module dependency carrying an un-lowerable method.

`Meter.unlowerable` calls `eval`, which type-checks but has no native lowering,
so it is demoted and emitted as an `abort()` stub. Nothing calls it. The
importing root (`seal_xmod_root.jac`) is the module actually sealed, so this
demotion lives one hop out in the sealed closure -- exactly the position that a
warm native IR cache hides, because a cache hit for this module skips
`NaIRGenPass` entirely and so records nothing in the native coverage.
"""

obj Meter {
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

def dep_scale(x: int) -> int {
    m = Meter();
    return m.good(x) * 2;
}
