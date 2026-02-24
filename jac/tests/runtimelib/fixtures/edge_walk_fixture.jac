"""Test: Build a tree (phase 0) and walk it by edge type (phase 1).

Phase 0 creates a small graph with two node types and two edge types.
Phase 1 spawns a walker that only traverses Link edges, verifying
that the persisted graph is correctly loaded and edge-filtered
traversal works across separate runs.
"""

import os;

node TypeA {
    has val: int = 0;
}

node TypeB {
    has name: str = "";
}

edge Link {}

edge Bridge {}

walker Visitor {
    has visited: list = [];

    can skip_root with Root entry {
        visit [->:Link:->];
    }

    can visit_a with TypeA entry {
        self.visited.append(f"TypeA({here.val})");
        visit [->:Link:->];
    }

    can visit_b with TypeB entry {
        self.visited.append(f"TypeB({here.name})");
        visit [->:Link:->];
    }
}

with entry {
    phase = os.environ.get("PHASE", "0");

    if phase == "0" {
        # Build a small tree with two node types and two edge types.
        #
        #  root --Link--> a1(TypeA, val=1)
        #            |--- Bridge --> b1(TypeB, name="hello")
        #            |--- Link ---> a2(TypeA, val=2)
        #                              |--- Bridge --> b2(TypeB, name="world")

        a1 = TypeA(val=1);
        b1 = TypeB(name="hello");
        a2 = TypeA(val=2);
        b2 = TypeB(name="world");

        root +>: Link :+> a1;
        a1 +>: Bridge :+> b1;
        a1 +>: Link :+> a2;
        a2 +>: Bridge :+> b2;

        print("PHASE 0: Tree created");
        print("  All from root:", [root-->]);
        print("  Link only from root:", [root->:Link:->]);
    }

    if phase == "1" {
        # Walk the persisted graph — only traverse Link edges.
        w = Visitor() spawn root;
        print("PHASE 1: Walker visited (Link edges only):", w.visited);
        assert len(w.visited) == 2, f"Expected 2 visited nodes, got {len(w.visited)}: {w.visited}";
    }
}
