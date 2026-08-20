"""The callee half of a demotion/emission ordering cycle.

`cycle_bad_fmt` uses `str % int`, which the native backend cannot lower
(`MOD on i8* vs i64` -- the exact shape that demotes
`helpers.jac::pretty_print_source_location`), so its demotion verdict lands
only when THIS module's codegen runs. The `import type` below is the cycle
edge: it puts the caller module inside this module's import walk, so the
caller compiles while this module is still inflight -- the configuration
where the caller cannot ask for the verdict and used to assume "live".
"""

import type from .demote_cycle_caller { CycleReporter }

def cycle_bad_fmt(n: int) -> str {
    return ("%03d" % n);
}

def cycle_ok(n: int) -> int {
    return n + 1;
}
