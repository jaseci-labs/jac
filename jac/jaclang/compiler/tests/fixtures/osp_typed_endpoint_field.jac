"""Cross-backend OSP equivalence fixture: reading a field off an *unfiltered*
neighbour traversal, made possible by typed edge endpoints (issue #6657).

`edge Portal: Spot --> Spot` declares the edge's endpoint node types, so
`[here ->:Portal:->]` narrows to `list[Spot]` with no `[?:Spot]` filter. The
element type is therefore a concrete archetype, which lets the native backend
recover the struct layout from the opaque adjacency handle (the #6648 path) and
read the field -- the case that, for an *untyped* edge, must still E5090.

Contrast with osp_field_access.jac, whose node-field read needs a `[?:Spot]`
filter to recover the type. Here the same reads (subscript element + loop var)
carry NO filter.

Graph: a -Portal-> b(tag=99), a -Portal-> c(tag=7). From a: 2 neighbours,
tags 99 + 7 = 106, first neighbour tag 99.
"""

node Spot { has tag: int = 0; }
edge Portal: Spot --> Spot {}            # typed endpoints -- Spot --> Spot

walker Reader {
    has count: int = 0, nbr_tag: int = 0, sum_tag: int = 0;
    can go with Spot entry {
        nbrs = [here ->:Portal:->];      # UNFILTERED -> narrows to list[Spot]
        self.count = len(nbrs);
        if len(nbrs) > 0 {
            self.nbr_tag = nbrs[0].tag;  # field via subscript, no [?:Spot]
        }
        for n in nbrs {
            self.sum_tag += n.tag;       # field via loop var, no [?:Spot]
        }
    }
}

def typed_endpoint_py() -> dict[str, any] {
    a = Spot(tag=1); b = Spot(tag=99); c = Spot(tag=7);
    a +>: Portal() :+> b;
    a +>: Portal() :+> c;
    r = Reader();
    a spawn r;
    return {"count": r.count, "nbr_tag": r.nbr_tag, "sum_tag": r.sum_tag};
}

na {
    def typed_endpoint_na() -> dict[str, any] {
        a = Spot(tag=1); b = Spot(tag=99); c = Spot(tag=7);
        a +>: Portal() :+> b;
        a +>: Portal() :+> c;
        r = Reader();
        a spawn r;
        return {"count": r.count, "nbr_tag": r.nbr_tag, "sum_tag": r.sum_tag};
    }
}
