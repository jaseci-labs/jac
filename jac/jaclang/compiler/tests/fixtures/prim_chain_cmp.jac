"""Chained-comparison cross-backend equivalence fixture (#7593 item 2).

Pins CPython chain semantics for membership (in / not in) and identity
(is / is not) links against the native lowering. ES/JS opts out.
"""

obj Box {
    has v: int = 0;
}

def chain_cmp_py -> dict {
    t = Box();
    u = t;
    w = Box();
    a = 1 if 1 < 2 in [2, 5] else 0;
    b = 1 if 1 < 2 in [3, 5] else 0;
    c = 1 if 3 > 2 not in [9, 8] else 0;
    d = 1 if "a" < "b" in ["b", "c"] else 0;
    e = 1 if "a" < ("be" + "ta") in ["beta", "x"] else 0;
    f = 1 if "a" < "kb" in {"ka": 1, "kb": 2} else 0;
    g = 1 if t is u is u else 0;
    h = 1 if t is u is w else 0;
    i = 1 if w is not t is not u else 0;
    j = 1 if 0 < 1 < 2 else 0;
    return {
        "mixed_in_true": a,
        "mixed_in_false": b,
        "notin_chain": c,
        "str_in_chain": d,
        "heap_middle_chain": e,
        "dict_in_chain": f,
        "is_alias_chain": g,
        "is_alias_break": h,
        "isnot_chain": i,
        "plain_chain": j,
    };
}

cl def chain_cmp_cl -> dict {
    return {};
}

na {
    obj NaBox {
        has v: int = 0;
    }

    def chain_cmp_na -> dict[str, any] {
        t = NaBox();
        u = t;
        w = NaBox();
        a = 1 if 1 < 2 in [2, 5] else 0;
        b = 1 if 1 < 2 in [3, 5] else 0;
        c = 1 if 3 > 2 not in [9, 8] else 0;
        d = 1 if "a" < "b" in ["b", "c"] else 0;
        e = 1 if "a" < ("be" + "ta") in ["beta", "x"] else 0;
        f = 1 if "a" < "kb" in {"ka": 1, "kb": 2} else 0;
        g = 1 if t is u is u else 0;
        h = 1 if t is u is w else 0;
        i = 1 if w is not t is not u else 0;
        j = 1 if 0 < 1 < 2 else 0;
        return {
            "mixed_in_true": a,
            "mixed_in_false": b,
            "notin_chain": c,
            "str_in_chain": d,
            "heap_middle_chain": e,
            "dict_in_chain": f,
            "is_alias_chain": g,
            "is_alias_break": h,
            "isnot_chain": i,
            "plain_chain": j,
        };
    }
}
