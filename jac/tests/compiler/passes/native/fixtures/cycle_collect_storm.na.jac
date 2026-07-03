"""Cycle-collector effectiveness under load.

Builds and drops many two-node `A <-> B` cycles.  Each pair is mutually
referential, so plain reference counting can NEVER reclaim it: when a local
goes out of scope its node's refcount drops from 2 to 1 (the sibling still
points at it) and stops there.  The only thing that frees these pairs is the
trial-deletion cycle collector, which fires from `__rc_push_root` once the
purple-root buffer crosses RC_CYCLE_THRESHOLD.

Because RC alone cannot touch these objects, the GC-vs-no-GC RSS delta measured
by the test is attributable entirely to the cycle collector: if collection were
broken or never triggered, the GC-enabled run would leak every pair just like
`JAC_NO_GC=1` and the delta would collapse.
"""

obj Node {
    has next: Node | None = None;
}

"""Allocate one A<->B cycle and let both locals fall out of scope.

Scope cleanup releases `a` and `b`; each survives with refcount 1 (held by its
sibling) and is buffered as a purple cycle-root candidate.
"""
def make_cycle {
    a: Node = Node();
    b: Node = Node();
    a.next = b;
    b.next = a;
}

with entry {
    i: int = 0;
    # 300k pairs -> 600k root candidates -> ~600 collection sweeps, and ~600k
    # leaked nodes (tens of MB) if the collector fails to reclaim them.
    while i < 300000 {
        make_cycle();
        i = i + 1;
    }
    print("cycle_collect OK");
}
