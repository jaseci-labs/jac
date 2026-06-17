"""Cross-backend OSP equivalence fixture: reading a FIELD off an edge-ref /
node-ref result element (issue #6646). An edge-ref returns its elements as
opaque handles; reading `.field` off one used to crash codegen (node) or E5090
(edge) because the handle was not recovered to the archetype struct layout.

Covered, all of which the checker can resolve to a concrete archetype:
  * edge field via subscript    `ports[0].cx`
  * edge field via def + return `direct(a)` -> `es[0].cx`
  * edge field via loop var     `for e in [edge ...] { ... e.cx }`
  * node field via a FILTERED node-ref `[--> [?:Spot]][0].tag`

Graph: a -Portal(cx=42)-> b(tag=99), a -Portal(cx=8)-> c(tag=7). From a:
2 portals (cx 42+8 = 50), one of which leads to a tag-99 node.
"""

node Spot { has tag: int = 0; }
edge Portal { has cx: float = 0.0; }

walker Reader {
    has first_cx: float = 0.0, sum_cx: float = 0.0, nbr_tag: int = 0;
    can go with Spot entry {
        ports = [edge here ->:Portal:->];
        if len(ports) > 0 {
            self.first_cx = ports[0].cx;          # edge field via subscript
        }
        for e in [edge here ->:Portal:->] {
            self.sum_cx += e.cx;                  # edge field via loop var
        }
        nodes = [here -->[?:Spot]];               # FILTERED node-ref -> typed
        if len(nodes) > 0 {
            self.nbr_tag = nodes[0].tag;          # node field via subscript
        }
    }
}

def first_portal_cx(x: Spot) -> float {
    es = [edge x ->:Portal:->];
    if len(es) == 0 {
        return -1.0;
    }
    return es[0].cx;                              # edge field via def + return
}

def field_access_py() -> dict[str, any] {
    a = Spot(tag=1); b = Spot(tag=99); c = Spot(tag=7);
    a +>: Portal(cx=42.0) :+> b;
    a +>: Portal(cx=8.0) :+> c;
    r = Reader();
    a spawn r;
    return {
        "first_cx": r.first_cx,
        "sum_cx": r.sum_cx,
        "nbr_tag": r.nbr_tag,
        "direct": first_portal_cx(a)
    };
}

na {
    def first_portal_cx_na(x: Spot) -> float {
        es = [edge x ->:Portal:->];
        if len(es) == 0 {
            return -1.0;
        }
        return es[0].cx;
    }

    def field_access_na() -> dict[str, any] {
        a = Spot(tag=1); b = Spot(tag=99); c = Spot(tag=7);
        a +>: Portal(cx=42.0) :+> b;
        a +>: Portal(cx=8.0) :+> c;
        r = Reader();
        a spawn r;
        return {
            "first_cx": r.first_cx,
            "sum_cx": r.sum_cx,
            "nbr_tag": r.nbr_tag,
            "direct": first_portal_cx_na(a)
        };
    }
}
