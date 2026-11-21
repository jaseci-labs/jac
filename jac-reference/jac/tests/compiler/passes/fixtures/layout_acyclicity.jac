"""Layouts whose acyclicity the walk has to get right.

`Leaf` and `Pair` hold only scalars and other acyclic archetypes, so both are
genuinely acyclic. `SelfRef`, `Ring*` and `BoxedRing` are genuinely cyclic --
directly, through a two-step cycle, and through a container element -- and a
walk that classifies any of them acyclic would drop their trace function and
let the collector miss a real cycle. `Opaque` holds an `any`, whose mangled
key names nothing the registry knows, which the walk has to keep answering
conservatively.
"""

obj Leaf {
    has n: int = 0,
        label: str = "";
}


obj Pair {
    has left: Leaf = Leaf(),
        right: Leaf = Leaf(),
        weight: float = 0.0;
}


obj SelfRef {
    has n: int = 0,
        next: (SelfRef | None) = None;
}


obj RingA {
    has b: (RingB | None) = None;
}


obj RingB {
    has a: (RingA | None) = None;
}


obj BoxedRing {
    has kids: list[BoxedRing] = [];
}


obj Opaque {
    has payload: any = None;
}


with entry:__main__ {
    print(Leaf().n);
    print(Pair().weight);
    print(SelfRef().n);
    print(len(BoxedRing().kids));
    print(RingA() is not None);
    print(RingB() is not None);
    print(Opaque() is not None);
}
