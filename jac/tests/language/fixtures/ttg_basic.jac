"""TTG basic integration test fixture.

Builds a typed graph, runs a walker, and verifies that Root's topology
tracking (graph / type_map) is populated correctly.
"""

edge BasicEdge {}
edge SpecialEdge {}

node TypeA {
    has val: int;
}

node TypeB {
    has val: int;
}

walker TTGWalker {
    has visited: list[int] = [];

    can enter_root with Root entry {
        visit [->:BasicEdge:->];
    }

    can run with TypeA entry {
        self.visited.append(here.val);
        visit [->:BasicEdge:->];
    }
}

# Graph layout:
#   root --BasicEdge--> a1(1) --BasicEdge--> a2(2)
#                            \--BasicEdge--> b4(4)
#                       a2 --SpecialEdge--> b3(3)
glob a1 = TypeA(val=1),
     a2 = TypeA(val=2),
     b3 = TypeB(val=3),
     b4 = TypeB(val=4);

with entry {
    root +>: BasicEdge :+> a1;
    a1 +>: BasicEdge :+> a2;
    a2 +>: SpecialEdge :+> b3;
    a1 +>: BasicEdge :+> b4;
}

# Verify Root topology tracking.
glob r = root;
with entry {
    print("graph_len", len(r.graph));
    print("type_map_len", len(r.type_map));
    print("graph_populated", len(r.graph) > 0);
    print("type_map_populated", len(r.type_map) > 0);
}

# Run walker — should traverse only along BasicEdge from TypeA nodes.
glob w = TTGWalker() spawn root;
with entry {
    print("visited", sorted(w.visited));
}
