"""Fixture: one method fails the native emitter, a sibling is clean.

`C.bad` calls `eval`, which type-checks (a Python builtin) but has no native
lowering -- the analysis passes are clean, so the failure surfaces only inside
the emitter. The native backend must isolate that failure: demote `C.bad` to
Python-only and still natively compile the clean sibling `C.good` rather than
aborting the whole module's native compile. (The original fixture fed a void
call result into `+`, but the required analyses now reject that at check time
before codegen ever runs, so it no longer exercises the emit-time seam.)
"""

obj C {
    def good(x: int) -> int {
        return x + 1;
    }

    def bad(x: int) -> int {
        z = eval("x + 1");
        return x;
    }
}
