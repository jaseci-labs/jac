"""Cross-backend OSP equivalence fixture: a typed connect that names the edge by
BARE TYPE, `a +>: E :+> b` (no `()`), must record the edge -- the same as
`a +>: E() :+> b`. Native used to silently DROP the bare-type form (codegen of a
bare archetype name yielded no value, so the connect was skipped), so the walk
found no edges. The engine and the @sv/cl pathways accept the bare form, so na
must too (issue #6642 follow-up).

a -E-> b, a -E-> c (bare), plus one b -E-> d via the `()` form for contrast. The
walker counts outgoing E edges at each visited node: a=2, b=1, c=0, d=0 -> 3.
"""

node N { has v: int = 0; }
edge E { has w: int = 0; }

walker Counter {
    has hits: int = 0;
    can step with N entry {
        self.hits += len([here ->:E:->]);
        visit [here ->:E:->];
    }
}

def bare_edge_py() -> dict[str, any] {
    a = N(v=1); b = N(v=2); c = N(v=3); d = N(v=4);
    a +>: E :+> b;        # bare edge type
    a +>: E :+> c;        # bare edge type
    b +>: E() :+> d;      # constructor form, for contrast
    w = Counter();
    w spawn a;
    return {"hits": w.hits};
}

na {
    def bare_edge_na() -> dict[str, any] {
        a = N(v=1); b = N(v=2); c = N(v=3); d = N(v=4);
        a +>: E :+> b;
        a +>: E :+> c;
        b +>: E() :+> d;
        w = Counter();
        w spawn a;
        return {"hits": w.hits};
    }
}
