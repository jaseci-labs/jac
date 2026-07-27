"""Cycle-collector effectiveness for cycles routed through a CONTAINER.

Each `Box` owns a `list[Box]`; two boxes append each other, forming the cycle
`a -> a.items -> b -> b.items -> a`. Plain reference counting can never reclaim
it (each box's refcount stays at 1, pinned by the sibling's list), so the only
thing that frees these pairs is the trial-deletion collector — and the ONLY way
the collector can see across the boundary is if the list itself carries a trace
function that visits its managed elements. Before that trace fn existed the box
trace reached the list, found no trace fn on it, and stopped: the cycle leaked
even with collection on. This fixture is the regression guard for that gap.

Driven on a fixed cadence via `__rc_collect_cycles()` so collection fires
deterministically. Run with `JAC_GC_CYCLES=1` for the reclaiming path.
"""

obj Box {
    has items: list[Box] = [];
}

def make_cycle {
    a: Box = Box();
    b: Box = Box();
    a.items.append(b);
    b.items.append(a);
}

with entry {
    i: int = 0;
    since_collect: int = 0;
    while i < 200000 {
        make_cycle();
        since_collect = since_collect + 1;
        if since_collect >= 10000 {
            __rc_collect_cycles();
            since_collect = 0;
        }
        i = i + 1;
    }
    __rc_collect_cycles();
    print("container_cycle OK");
}
