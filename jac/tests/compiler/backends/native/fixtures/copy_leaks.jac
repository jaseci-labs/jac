"""Every copy `copy.copy` / `copy.deepcopy` makes is released: after the work
runs and the cycle collector sweeps, the RC debug build's live-object dump at
exit must be empty. Covers archetype copies (with a subclass behind a base),
optional and list fields, container copies, deep copies with shared
references, and a deep-copied cycle, each repeated so a per-copy imbalance
would show up as many leaked objects rather than one."""

import copy;

obj Tag {
    has name: str = "t",
        refs: list[str] = [];
}

obj Tagged(Tag) {
    has weight: int = 1,
        label: str | None = None;
}

obj Box {
    has tag: Tag = Tag(),
        spare: Tag | None = None,
        tags: list[Tag] = [],
        index: dict[str, list[int]] = {},
        seen: set[str] = set();
}

obj Ring {
    has v: int = 0,
        nxt: Ring | None = None;
}

def shallow_round(i: int) -> int {
    t: Tag = Tagged(name="n" + str(i), refs=["r"], weight=i, label="l" + str(i));
    c = copy.copy(t);
    c.name = "c" + str(i);
    b = Box(tag=t, spare=c, tags=[t, c], index={"k": [i]}, seen={"s"});
    b2 = copy.copy(b);
    lst = copy.copy(b.tags);
    dct = copy.copy(b.index);
    st = copy.copy(b.seen);
    return len(b2.tags) + len(lst) + len(dct) + len(st) + len(c.refs);
}

def deep_round(i: int) -> int {
    shared = Tag(name="s" + str(i), refs=["a", "b"]);
    b = Box(tag=shared, spare=shared, tags=[shared, Tagged(weight=i, label="d" + str(i))], index={"k": [i, i]});
    b2 = copy.deepcopy(b);
    nested = [[i], [i, i]];
    n2 = copy.deepcopy(nested);
    total = len(b2.tags) + len(n2) + len(b2.index["k"]);
    if b2.spare is b2.tag {
        total = total + 1;
    }
    return total;
}

def ring_round(i: int) -> int {
    a = Ring(v=i);
    z = Ring(v=i + 1, nxt=a);
    a.nxt = z;
    a2 = copy.deepcopy(a);
    a.nxt = None;
    return a2.v;
}

def run_all -> int {
    total = 0;
    for i in range(20) {
        total = total + shallow_round(i) + deep_round(i) + ring_round(i);
    }
    return total;
}

with entry {
    print(run_all());
    __rc_collect_cycles();
    __rc_debug_enable();
}
