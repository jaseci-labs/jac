"""Fixture: a genuine type error inside a loop body must not be swallowed by the
fixed-point iteration.

Resolving a loop variable's narrowed type re-evaluates the body speculatively
against the loop's provisional guess. Those speculative evaluations must be
throwaway: their diagnostics are suppressed and their results must not be cached,
so the real check pass re-evaluates every node and surfaces any real error. A
regression here would let the speculative pass cache the node's type and swallow
its diagnostic permanently.

`cur.step(999)` sits on the loop back-edge (it is what reassigns `cur`), so it is
exactly the node evaluated speculatively during the fixed point. Its argument
error must still be reported.
"""

obj Item {
    has next: Item | None = None;

    def step() -> Item {
        return self;
    }
}

def walk(cur: Item | None) -> None {
    while cur is not None {
        cur = cur.step(999);
    }
}
