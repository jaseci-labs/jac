"""Spawn operator validation.

`a spawn b` is a binary expression where exactly one operand must be a
walker instance (or list[Walker]); the other operand is the spawn
"target" and must be a node, edge, or collection thereof. The runtime
implementation lives in `JacWalker.spawn` (jac0core/runtime.jac).

Diagnostics:
    E1114 — neither side is a walker instance.
    E1115 — non-walker side is not a node/edge/path/collection thereof.
"""

node Place { has name: str; }
edge Road { has length: int = 0; }

obj NotAWalker { has v: int; }

walker MyWalker {
    can on_root with `root entry { ; }
}

walker AsyncWalker {
    can on_root with `root entry { ; }
}

with entry {
    p: Place = Place(name="A");
    n: Place = Place(name="B");
    w: MyWalker = MyWalker();
    nw: NotAWalker = NotAWalker(v=1);

    # --- Bad: neither side is a walker ---
    bad1 = p spawn 42;                       # E1114
    bad2 = p spawn NotAWalker(v=1);          # E1114
    bad3 = p spawn nw;                       # E1114
    bad4 = "x" spawn "y";                    # E1114

    # --- Bad: walker present, but target side is not a node/edge ---
    bad5 = MyWalker() spawn 42;              # E1115 (left is walker, right is int)
    bad6 = 42 spawn MyWalker();              # E1115 (right is walker, left is int)
    bad7 = MyWalker() spawn "hi";            # E1115
    bad8 = MyWalker() spawn nw;              # E1115 (NotAWalker not a node)
    bad9 = MyWalker() spawn [1, 2, 3];       # E1115 (list[int] not list of node/edge)

    # --- Good: walker + node/edge/path/list-of-those ---
    good1 = p spawn MyWalker();              # ok: node spawn walker
    good2 = MyWalker() spawn p;              # ok: walker spawn node
    good3 = w spawn p;                       # ok: walker var spawn node
    good4 = root spawn MyWalker();           # ok: root is a node
    nodes: list[Place] = [Place(name="x"), Place(name="y")];
    good5 = MyWalker() spawn nodes;          # ok: walker spawn list of nodes
    e: Road = Road();
    good6 = MyWalker() spawn e;              # ok: walker spawn edge
}
