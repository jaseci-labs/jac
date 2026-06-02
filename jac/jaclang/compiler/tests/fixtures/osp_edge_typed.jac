"""Cross-backend OSP equivalence fixture: typed / filtered edge references.

The graph mixes edge types: `a -Road-> b`, `a -Rail-> c`, `b -Road-> d`. The
walker follows ONLY `Road` edges via the typed edge ref `[->:Road:->]`, so it
reaches `a, b, d` and never crosses the `Rail` edge to `c`. This pins typed
edge filtering against the untyped `[-->]` (which would also reach `c`).

Backend status: edge connect/ref are E5090 on na and unwired on cl, so py-only
today.
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
