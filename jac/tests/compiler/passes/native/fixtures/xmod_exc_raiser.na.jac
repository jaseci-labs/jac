"""Raises an OSError across a .na.jac module boundary (issue #7013).

The companion `xmod_exc_main.na.jac` imports `do_raise` and wraps the call in
its own `try`/`except`. Before the fix, the raiser's exception runtime used a
per-module `internal`-linkage `@__jac_current_handler` and per-module exception
type IDs, so the `longjmp` here could not reach the importer's handler — the
process SIGABRTed instead of unwinding.
"""

def:pub do_raise(x: int) -> int {
    if x < 0 {
        raise OSError("neg");
    }
    return x;
}
