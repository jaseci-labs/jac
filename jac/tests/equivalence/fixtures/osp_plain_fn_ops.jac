"""Cross-backend OSP equivalence fixture: bare edge operations in PLAIN
FUNCTIONS (no walker context) -- the single-source-of-truth contract.

Every prior fixture threaded the needle: connects happened in plain code
but traversals only inside walker abilities (where `here` exists). The cl
backend hardcoded `here` as the traversal origin and silently lowered
explicit-origin refs to `undefined`, so plain-function graph code
compiled clean and misbehaved at runtime (jacblocks dogfood #19,
issue #7941). This fixture pins: explicit-origin traversal, typed and
attribute-filtered refs, in/out/any directions, multi-hop chains,
insertion order, and typed disconnect-between -- all outside any walker.
"""

node P {
    has v: int = 0;
}

edge E {
    has w: int = 0;
}


def plain_ops_py() -> dict[str, any] {
    a = P(v=1);
    b = P(v=2);
    c = P(v=3);
    d = P(v=4);
    a ++> b;
    a +>:E(w=1):+> c;
    a +>:E(w=2):+> d;
    c +>:E(w=3):+> d;
    out_all = len([a -->]);
    out_typed = len([a ->:E:->]);
    picked = [a ->:E:w == 2:->[?:P]];
    picked_v = picked[0].v if len(picked) > 0 else -1;
    two_hop = len([a ->:E:-> ->:E:->]);
    into_d = len([d <--]);
    ordered = [a ->:E:->[?:P]];
    first_v = ordered[0].v if len(ordered) > 0 else -1;
    a del ->:E:-> c;
    after_del = len([a ->:E:->]);
    still_in_d = len([d <--]);
    return {
        "out_all": out_all,
        "out_typed": out_typed,
        "picked_v": picked_v,
        "two_hop": two_hop,
        "into_d": into_d,
        "first_v": first_v,
        "after_del": after_del,
        "still_in_d": still_in_d
    };
}

def plain_ops_cl() -> dict[str, any] {
    a = P(v=1);
    b = P(v=2);
    c = P(v=3);
    d = P(v=4);
    a ++> b;
    a +>:E(w=1):+> c;
    a +>:E(w=2):+> d;
    c +>:E(w=3):+> d;
    out_all = len([a -->]);
    out_typed = len([a ->:E:->]);
    picked = [a ->:E:w == 2:->[?:P]];
    picked_v = picked[0].v if len(picked) > 0 else -1;
    two_hop = len([a ->:E:-> ->:E:->]);
    into_d = len([d <--]);
    ordered = [a ->:E:->[?:P]];
    first_v = ordered[0].v if len(ordered) > 0 else -1;
    a del ->:E:-> c;
    after_del = len([a ->:E:->]);
    still_in_d = len([d <--]);
    return {
        "out_all": out_all,
        "out_typed": out_typed,
        "picked_v": picked_v,
        "two_hop": two_hop,
        "into_d": into_d,
        "first_v": first_v,
        "after_del": after_del,
        "still_in_d": still_in_d
    };
}

def plain_ops_na() -> dict[str, any] {
    a = P(v=1);
    b = P(v=2);
    c = P(v=3);
    d = P(v=4);
    a ++> b;
    a +>:E(w=1):+> c;
    a +>:E(w=2):+> d;
    c +>:E(w=3):+> d;
    out_all = len([a -->]);
    out_typed = len([a ->:E:->]);
    picked = [a ->:E:w == 2:->[?:P]];
    picked_v = picked[0].v if len(picked) > 0 else -1;
    two_hop = len([a ->:E:-> ->:E:->]);
    into_d = len([d <--]);
    ordered = [a ->:E:->[?:P]];
    first_v = ordered[0].v if len(ordered) > 0 else -1;
    a del ->:E:-> c;
    after_del = len([a ->:E:->]);
    still_in_d = len([d <--]);
    return {
        "out_all": out_all,
        "out_typed": out_typed,
        "picked_v": picked_v,
        "two_hop": two_hop,
        "into_d": into_d,
        "first_v": first_v,
        "after_del": after_del,
        "still_in_d": still_in_d
    };
}
