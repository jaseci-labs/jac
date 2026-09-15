"""Cross-backend OSP equivalence fixture: ONE substrate for plain-function
edge ops and walker traversal (issue #7941's interop gate).

A graph built with bare `++>` in a plain function must be visible to a
spawned walker, and edges a walker creates mid-walk must be visible to
plain-function traversal afterward. The old client shim kept bare-op
edges in per-object `__edges` arrays disjoint from the kernel's world --
an architecture this fixture is designed to make impossible.
"""

node S {
    has v: int = 0;
}

edge L {
    has w: int = 0;
}

walker Chainer {
    has hits: int = 0;

    can step with S entry {
        self.hits += here.v;
        if here.v == 2 {
            here +>:L(w=9):+> S(v=99);
        }
        visit [here ->:L:->];
    }
}


def interop_py() -> dict[str, any] {
    a = S(v=1);
    b = S(v=2);
    c = S(v=3);
    a +>:L(w=1):+> b;
    b +>:L(w=2):+> c;
    wlk = Chainer();
    wlk spawn a;
    after_b = len([b ->:L:->]);
    grown = [b ->:L:w == 9:->[?:S]];
    grown_v = grown[0].v if len(grown) > 0 else -1;
    return {"hits": wlk.hits, "after_b": after_b, "grown_v": grown_v};
}

def interop_cl() -> dict[str, any] {
    a = S(v=1);
    b = S(v=2);
    c = S(v=3);
    a +>:L(w=1):+> b;
    b +>:L(w=2):+> c;
    wlk = Chainer();
    wlk spawn a;
    after_b = len([b ->:L:->]);
    grown = [b ->:L:w == 9:->[?:S]];
    grown_v = grown[0].v if len(grown) > 0 else -1;
    return {"hits": wlk.hits, "after_b": after_b, "grown_v": grown_v};
}

def interop_na() -> dict[str, any] {
    a = S(v=1);
    b = S(v=2);
    c = S(v=3);
    a +>:L(w=1):+> b;
    b +>:L(w=2):+> c;
    wlk = Chainer();
    wlk spawn a;
    after_b = len([b ->:L:->]);
    grown = [b ->:L:w == 9:->[?:S]];
    grown_v = grown[0].v if len(grown) > 0 else -1;
    return {"hits": wlk.hits, "after_b": after_b, "grown_v": grown_v};
}
