"""Cross-backend OSP equivalence fixture: typed / filtered edge references.

The graph mixes edge types: `a -Road-> b`, `a -Rail-> c`, `b -Road-> d`. The
walker follows ONLY `Road` edges via the typed edge ref `[->:Road:->]`, so it
reaches `a, b, d` and never crosses the `Rail` edge to `c`. This pins typed
edge filtering against the untyped `[-->]` (which would also reach `c`).

Backend status: na and py agree. Typed edge connect/ref (`+>:Road:+>`,
`[->:Road:->]`) lower on na via the in-memory adjacency (osp_graph.jac), which
tags each edge so `[->:Road:->]` filters by type; `visit` lowers too. OSP
instances live in a program-lifetime graph arena. cl is unwired here, so the
cross-backend assert is na vs py.
"""

node City { has val: int; }
edge Road {}
edge Rail {}

walker Router {
    has seen: list = [];
    can step with City entry {
        self.seen.append(here.val);
        visit [->:Road:->];
    }
}

def edge_typed_py() -> dict[str, any] {
    a = City(val=1); b = City(val=2); c = City(val=3); d = City(val=4);
    a +>: Road() :+> b;
    a +>: Rail() :+> c;
    b +>: Road() :+> d;
    w = Router();
    w spawn a;
    return {"seen": w.seen};
}

na {
    def edge_typed_na() -> dict[str, any] {
        a = City(val=1); b = City(val=2); c = City(val=3); d = City(val=4);
        a +>: Road() :+> b;
        a +>: Rail() :+> c;
        b +>: Road() :+> d;
        w = Router();
        w spawn a;
        return {"seen": w.seen};
    }
}

cl {
    def edge_typed_cl() -> dict[str, any] {
        a = City(val=1); b = City(val=2); c = City(val=3); d = City(val=4);
        a +>: Road() :+> b;
        a +>: Rail() :+> c;
        b +>: Road() :+> d;
        w = Router();
        w spawn a;
        return {"seen": w.seen};
    }
}
