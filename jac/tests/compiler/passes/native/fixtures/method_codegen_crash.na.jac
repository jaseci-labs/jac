"""Fixture: one method crashes the native emitter, a sibling is clean.

`C.bad` feeds a void-typed call result into a binary op, which raises a hard
TypeError deep in IR building (i64 vs void) -- a path that bypasses the
value-binding guard. The native backend must isolate that failure: demote
`C.bad` to Python-only and still natively compile the clean sibling `C.good`
rather than aborting the whole module's native compile.
"""

def sink(x: int) -> None { }

obj C {
    def good(x: int) -> int {
        return x + 1;
    }

    def bad(x: int) -> int {
        z = sink(x) + 1;
        return z;
    }
}
