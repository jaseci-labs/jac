"""Cycle-collector effectiveness under load.

Builds and drops many two-node `A <-> B` cycles.  Each pair is mutually
referential, so plain reference counting can NEVER reclaim it: when a local
goes out of scope its node's refcount drops from 2 to 1 (the sibling still
points at it) and stops there.  The only thing that frees these pairs is the
trial-deletion cycle collector.  This fixture drives it deterministically by
calling the `__rc_collect_cycles()` test hook on a fixed cadence (rather than
relying on the purple-root buffer organically crossing RC_CYCLE_THRESHOLD).

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
    since_collect: int = 0;
    # 300k pairs -> 600k root candidates -> tens of MB leaked if the collector
    # fails to reclaim them. `__rc_collect_cycles()` forces a trial-deletion sweep
    # every 10k pairs so collection fires deterministically rather than depending
    # on the RC_CYCLE_THRESHOLD auto-trigger overflowing under load (which is what
    # made "did it even collect?" the flaky part of this test).
    while i < 300000 {
        make_cycle();
        since_collect = since_collect + 1;
        if since_collect >= 10000 {
            __rc_collect_cycles();
            since_collect = 0;
        }
        i = i + 1;
    }
    __rc_collect_cycles();
    print("cycle_collect OK");
}
