"""Cycle-collector effectiveness for cycles routed through a HETERO list.

Each `Box` owns a `list[int | Box]` lowered to `List.jacval`: elements are
tagged values, so the only way the trial-deletion collector can see across
the container is if the shared trace emitter visits the heap-tagged payload
of each live jacval slot. Two boxes store each other (alongside scalar
elements that the trace must skip), forming the cycle
`a -> a.slots -> b -> b.slots -> a` that plain reference counting can never
reclaim. A jacval container whose trace ignores tagged payloads stops the
trace cold: the cycle leaks even with collection on.

Driven on a fixed cadence via `__rc_collect_cycles()` so collection fires
deterministically. Run with `JAC_GC_CYCLES=1` for the reclaiming path.
"""

obj Box {
    has slots: list[int | Box] = [];
}

def make_cycle {
    a: Box = Box();
    b: Box = Box();
    a.slots.append(7);
    a.slots.append(b);
    b.slots.append(a);
    b.slots.append(11);
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
    print("hetero_cycle OK");
}
