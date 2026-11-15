"""Cross-backend OSP equivalence fixture: bound endpoints and `jid`.

A bound endpoint names the far end of a hop: `[p ->:Child:-> c]` keeps the
neighbours (or, with `edge`, the edges) that reach `c`. Covered: forward and
backward edge objects between two bound nodes with their fields read back, a
list of endpoints, an edge predicate combined with an endpoint, an endpoint in
the middle of a chain, and plain node results. `jid` is compared by shape only
(exact ids are backend-specific): stable per object, distinct across objects,
32 hex characters, for nodes, edges and a narrowed optional node.

Graph: p -Child(7)-> c, p -Child(9)-> o, c -Child(1)-> g.
"""

node Sub {
    has tag: int = 0;
}

edge Child: Sub --> Sub {
    has rank: int = 0;
}

def forward_rank(p: Sub, c: Sub) -> int {
    es = [edge p->:Child:->c];
    return es[0].rank if len(es) == 1 else -1;
}

def backward_rank(p: Sub, c: Sub) -> int {
    es = [edge c<-:Child:<-p];
    return es[0].rank if len(es) == 1 else -1;
}

def listed(p: Sub, c: Sub, g: Sub) -> int {
    ends: list[Sub] = [c, g];
    return len([p->:Child:->ends]);
}

def predicated(p: Sub, c: Sub, o: Sub) -> int {
    return len([edge p->:Child:rank>8:->o]) * 10 + len([edge p->:Child:rank>8:->c]);
}

def mid_chain(p: Sub, c: Sub, o: Sub) -> int {
    return len([p->:Child:->c->:Child:->]) * 10 + len([p->:Child:->o->:Child:->]);
}

def unconnected(c: Sub, o: Sub) -> int {
    return len([c->:Child:->o]);
}

def jid_len(n: (Sub | None)) -> int {
    if n is not None {
        return len(jid(n));
    }
    return -1;
}

def bound_endpoint_py -> dict[str, any] {
    p = Sub(tag=1);
    c = Sub(tag=2);
    o = Sub(tag=3);
    g = Sub(tag=4);
    p +>:Child(rank=7):+> c;
    p +>:Child(rank=9):+> o;
    c +>:Child(rank=1):+> g;
    e = [edge p->:Child:->c][0];
    jp = jid(p);
    je = jid(e);
    return {
        "fwd": forward_rank(p, c),
        "bwd": backward_rank(p, c),
        "other": forward_rank(p, o),
        "listed": listed(p, c, g),
        "predicated": predicated(p, c, o),
        "mid_chain": mid_chain(p, c, o),
        "unconnected": unconnected(c, o),
        "jid_stable": jp == jid(p) and je == jid(e),
        "jid_distinct": jp != jid(c) and je != jp,
        "jid_len": len(jp) + len(je),
        "jid_narrowed": jid_len(c),
        "jid_none": jid_len(None)
    };
}

# --- na (native LLVM) ---

def forward_rank_na(p: Sub, c: Sub) -> int {
    es = [edge p->:Child:->c];
    return es[0].rank if len(es) == 1 else -1;
}

def backward_rank_na(p: Sub, c: Sub) -> int {
    es = [edge c<-:Child:<-p];
    return es[0].rank if len(es) == 1 else -1;
}

def listed_na(p: Sub, c: Sub, g: Sub) -> int {
    ends: list[Sub] = [c, g];
    return len([p->:Child:->ends]);
}

def predicated_na(p: Sub, c: Sub, o: Sub) -> int {
    return len([edge p->:Child:rank>8:->o]) * 10 + len([edge p->:Child:rank>8:->c]);
}

def mid_chain_na(p: Sub, c: Sub, o: Sub) -> int {
    return len([p->:Child:->c->:Child:->]) * 10 + len([p->:Child:->o->:Child:->]);
}

def unconnected_na(c: Sub, o: Sub) -> int {
    return len([c->:Child:->o]);
}

def jid_len_na(n: (Sub | None)) -> int {
    if n is not None {
        return len(jid(n));
    }
    return -1;
}

def bound_endpoint_na -> dict[str, any] {
    p = Sub(tag=1);
    c = Sub(tag=2);
    o = Sub(tag=3);
    g = Sub(tag=4);
    p +>:Child(rank=7):+> c;
    p +>:Child(rank=9):+> o;
    c +>:Child(rank=1):+> g;
    e = [edge p->:Child:->c][0];
    jp = jid(p);
    je = jid(e);
    return {
        "fwd": forward_rank_na(p, c),
        "bwd": backward_rank_na(p, c),
        "other": forward_rank_na(p, o),
        "listed": listed_na(p, c, g),
        "predicated": predicated_na(p, c, o),
        "mid_chain": mid_chain_na(p, c, o),
        "unconnected": unconnected_na(c, o),
        "jid_stable": jp == jid(p) and je == jid(e),
        "jid_distinct": jp != jid(c) and je != jp,
        "jid_len": len(jp) + len(je),
        "jid_narrowed": jid_len_na(c),
        "jid_none": jid_len_na(None)
    };
}
