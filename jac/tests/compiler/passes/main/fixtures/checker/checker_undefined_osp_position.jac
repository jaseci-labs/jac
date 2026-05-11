"""Issue #5885 gap 7: undefined names in OSP-shape positions are
structural errors, not the stylistic `W2001` warning.

Three positions promote `Name 'X' may be undefined` from `W2001` to
`E2018` because an unresolved name there breaks the program's shape:

    1. Connect typed-edge:    `a +>: NoSuchEdge :+> b`
    2. Disconnect typed-edge: `a del ->:NoSuchEdge:-> b`
    3. Ability trigger:       `can ... with NoSuchType entry`

The fixture exercises each position once with a bare name, plus the
two compound trigger forms (tuple and union) to verify per-element
promotion. Names that resolve correctly must not emit E2018.
"""

node N { has v: int = 0; }
edge MyEdge { has w: int = 0; }
walker GoodWalker { can ping with `root entry { ; } }

walker BadWalker {
    can on1 with NoSuchType entry { ; }                # E2018
    can on2 with (N, AlsoMissing) entry { ; }          # E2018 (tuple element)
    can on3 with N | StillMissing exit { ; }           # E2018 (union member)
    can on_ok with N entry { ; }                       # Ok
}

with entry {
    a = N();
    b = N();
    a +>: NoSuchEdge :+> b;        # E2018 (connect conn_type)
    a del ->:NoSuchEdge:-> b;      # E2018 (disconnect typed edge)
    a +>: MyEdge :+> b;            # Ok
    a del ->:MyEdge:-> b;          # Ok
}
