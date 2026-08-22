"""Cross-backend OSP equivalence fixture: the binary disconnect expression,
typed `a del ->:E:-> b` and untyped `c del --> d`. Native used to have NO
lowering for DisconnectOp (only `del <edge>` worked), so it was statically
rejected; it now lowers through the central store call
`osp_disconn_between(src, tgt, dir, edge_tag)` (tag -1 = any type).

Semantics pinned here: typed disconnect removes ONLY the matching-type edges
between the two endpoints (the parallel F edge survives), untyped disconnect
removes EVERY edge between its endpoints regardless of type, edges not between
the named endpoints are untouched, and the expression itself is a bool
(something was removed). Graph: a -E-> b, a -F-> b, a -E-> c, c --> d (untyped),
c -E-> d. After `a del ->:E:-> b` and `c del --> d`: a keeps F->b and E->c,
c has nothing.
"""

node N {
    has v: int = 0;
}
edge E {
    has w: int = 0;
}
edge F {}

def disc_between_py() -> dict[str, any] {
    a = N(v=1);
    b = N(v=2);
    c = N(v=3);
    d = N(v=4);
    a +>:E:+> b;
    a +>:F():+> b;
    a +>:E:+> c;
    c ++> d;
    c +>:E:+> d;
    before_a = len([edge a -->]);
    before_c = len([edge c -->]);
    did_t = a del ->:E:-> b;
    did_u = c del --> d;
    return {
        "before_a": before_a,
        "before_c": before_c,
        "removed_t": 1 if did_t else 0,
        "removed_u": 1 if did_u else 0,
        "typed_left": len([a ->:E:->]),
        "f_left": len([a ->:F:->]),
        "a_out": len([edge a -->]),
        "c_out": len([c -->])
    };
}


def disc_between_na() -> dict[str, any] {
    a = N(v=1);
    b = N(v=2);
    c = N(v=3);
    d = N(v=4);
    a +>:E:+> b;
    a +>:F():+> b;
    a +>:E:+> c;
    c ++> d;
    c +>:E:+> d;
    before_a = len([edge a -->]);
    before_c = len([edge c -->]);
    did_t = a del ->:E:-> b;
    did_u = c del --> d;
    return {
        "before_a": before_a,
        "before_c": before_c,
        "removed_t": 1 if did_t else 0,
        "removed_u": 1 if did_u else 0,
        "typed_left": len([a ->:E:->]),
        "f_left": len([a ->:F:->]),
        "a_out": len([edge a -->]),
        "c_out": len([c -->])
    };
}

# --- cl (ECMAScript, in-process via the kernel) ---

def disc_between_cl() -> dict[str, any] {
    a = N(v=1);
    b = N(v=2);
    c = N(v=3);
    d = N(v=4);
    a +>:E:+> b;
    a +>:F():+> b;
    a +>:E:+> c;
    c ++> d;
    c +>:E:+> d;
    before_a = len([edge a -->]);
    before_c = len([edge c -->]);
    did_t = a del ->:E:-> b;
    did_u = c del --> d;
    return {
        "before_a": before_a,
        "before_c": before_c,
        "removed_t": 1 if did_t else 0,
        "removed_u": 1 if did_u else 0,
        "typed_left": len([a ->:E:->]),
        "f_left": len([a ->:F:->]),
        "a_out": len([edge a -->]),
        "c_out": len([c -->])
    };
}
