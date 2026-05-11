"""Ability trigger archetype kind validation.

Walker abilities (`can ... with X entry/exit`) fire on the location the
walker is at — `X` must be a node, edge, or `Root`. Node/edge abilities
fire on the visiting walker — `X` must be a walker. The runtime contract
is in `JacWalker._execute_entries`/`_execute_exits` (jac0core/runtime.jac).

Diagnostics:
    E1116 — walker ability trigger that isn't a node/edge/Root.
    E1117 — node/edge ability trigger that isn't a walker.

Tuple `(A, B)` and union `A | B` triggers desugar element-wise — one
diagnostic per bad element. Untyped triggers (`with entry`/`with exit`)
fire on every step and are always valid.
"""

node Place { has v: int = 0; }
node City { has population: int = 0; }
edge Road { has length: int = 0; }
edge Friend { has since: int = 0; }
obj NotAnArch { has v: int = 0; }

walker WalkerOne { can ping with `root entry { ; } }
walker WalkerTwo { can ping with `root entry { ; } }

walker BadWalker {
    # Walker triggers must be node/edge/Root.
    can on1 with NotAnArch entry { ; }                # E1116 (obj)
    can on2 with int entry        { ; }               # E1116 (builtin)
    can on3 with str exit         { ; }               # E1116 (builtin, exit form)
    can on4 with WalkerTwo entry  { ; }               # E1116 (walker, not node/edge)
    can on5 with (Place, NotAnArch) entry { ; }       # E1116 once (NotAnArch element)
    can on6 with Place | NotAnArch entry { ; }        # E1116 once (NotAnArch member)
}

node BadNode {
    # Node triggers must be walkers.
    can on1 with Place entry      { ; }               # E1117 (node)
    can on2 with int entry        { ; }               # E1117 (builtin)
    can on3 with NotAnArch exit   { ; }               # E1117 (obj, exit form)
}

edge BadEdge {
    # Edge triggers must be walkers.
    can on1 with Road entry       { ; }               # E1117 (edge)
    can on2 with Place exit       { ; }               # E1117 (node)
}

walker GoodWalker {
    # No trigger type — fires on every step.
    can any_entry with entry      { ; }
    can any_exit  with exit       { ; }
    # Concrete node/edge/Root triggers.
    can at_place with Place entry { ; }
    can at_road  with Road exit   { ; }
    can at_root  with `root entry { ; }
    # Tuple and union of valid archetypes.
    can at_nodes with (Place, City) entry { ; }
    can at_mixed with Place | Road exit   { ; }
}

node GoodNode {
    can any_entry with entry         { ; }
    can on_walker with WalkerOne entry  { ; }
    can on_walker_union with WalkerOne | WalkerTwo entry { ; }
    can on_walker_tuple with (WalkerOne, WalkerTwo) exit { ; }
}

edge GoodEdge {
    can any_entry with entry         { ; }
    can on_walker with WalkerOne entry  { ; }
}
