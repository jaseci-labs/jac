"""Cross-backend OSP equivalence fixture: BOUND ENDPOINTS on edge refs plus
the `jid` identity builtin (native gap closing).

Covered, all between two bound nodes:
  * edge objects of a typed edge  `[edge p ->:Child:-> c]`, with the edge's
    own fields read off the result (subscript / loop var / def return)
  * backward bound endpoint       `[edge c <-:Child:<- p]`
  * plain traversal to a bound neighbour `[p ->:Child:-> c]` (identity of
    the single result checked via `jid`)
  * `jid(x)` shape: equal for the same object within a process, distinct
    across objects, 32 chars. Exact id bytes are backend-specific by design
    (uuid-based on sv, allocation-derived on na), so only shape is compared.

Graph: p -Child(rank=7)-> c, p -Child(rank=9)-> o. Exactly one Child edge
between p and c; none between c and o.
"""

node Sub {
    has tag: int = 0;
}

edge Child: Sub --> Sub {
    has rank: int = 0;
}

def forward_rank(p: Sub, c: Sub) -> int {
    es = [edge p->:Child:->c];
    if len(es) == 0 {
        return -1;
    }
    return es[0].rank;
}

def loop_rank(p: Sub, c: Sub) -> int {
    for e in [edge p->:Child:->c] {
        return e.rank;
    }
    return -1;
}

def backward_rank(p: Sub, c: Sub) -> int {
    es = [edge c<-:Child:<-p];
    if len(es) == 0 {
        return -1;
    }
    return es[0].rank;
}

def bound_edge_count(p: Sub, o: Sub) -> int {
    return len([edge p->:Child:->o]);
}

def bound_node_is(p: Sub, c: Sub) -> bool {
    ns = [p->:Child:->c];
    if len(ns) != 1 {
        return False;
    }
    return jid(ns[0]) == jid(c);
}

def bound_endpoint_py -> dict[str, any] {
    p = Sub(tag=1);
    c = Sub(tag=2);
    o = Sub(tag=3);
    p +>:Child(rank=7):+> c;
    p +>:Child(rank=9):+> o;
    jp = jid(p);
    jc = jid(c);
    return {
        "fwd": forward_rank(p, c),
        "loop": loop_rank(p, c),
        "bwd": backward_rank(p, c),
        "count_po": bound_edge_count(p, o),
        "other_rank": forward_rank(p, o),
        "is_c": bound_node_is(p, c),
        "jid_stable": jp == jid(p),
        "jid_distinct": jp != jc,
        "jid_len32": len(jp) == 32
    };
}


# --- na (native LLVM) ---

def forward_rank_na(p: Sub, c: Sub) -> int {
    es = [edge p->:Child:->c];
    if len(es) == 0 {
        return -1;
    }
    return es[0].rank;
}

def loop_rank_na(p: Sub, c: Sub) -> int {
    for e in [edge p->:Child:->c] {
        return e.rank;
    }
    return -1;
}

def backward_rank_na(p: Sub, c: Sub) -> int {
    es = [edge c<-:Child:<-p];
    if len(es) == 0 {
        return -1;
    }
    return es[0].rank;
}

def bound_edge_count_na(p: Sub, o: Sub) -> int {
    return len([edge p->:Child:->o]);
}

def bound_node_is_na(p: Sub, c: Sub) -> bool {
    ns = [p->:Child:->c];
    if len(ns) != 1 {
        return False;
    }
    return jid(ns[0]) == jid(c);
}

def bound_endpoint_na -> dict[str, any] {
    p = Sub(tag=1);
    c = Sub(tag=2);
    o = Sub(tag=3);
    p +>:Child(rank=7):+> c;
    p +>:Child(rank=9):+> o;
    jp = jid(p);
    jc = jid(c);
    return {
        "fwd": forward_rank_na(p, c),
        "loop": loop_rank_na(p, c),
        "bwd": backward_rank_na(p, c),
        "count_po": bound_edge_count_na(p, o),
        "other_rank": forward_rank_na(p, o),
        "is_c": bound_node_is_na(p, c),
        "jid_stable": jp == jid(p),
        "jid_distinct": jp != jc,
        "jid_len32": len(jp) == 32
    };
}
