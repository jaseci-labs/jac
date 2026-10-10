"""Graph identity (`jid`) and bound endpoints over reclaimable native nodes
and edges. A jid belongs to one object: it goes when the object is freed, so
an object later allocated at the same address gets a fresh one. A bound
endpoint holds only the results it returns, and releases a temporary operand.
Drop hooks count reclamation."""

glob nodes_dropped: int = 0,
     edges_dropped: int = 0;

node Room {
    has tag: int = 0;

    def drop {
        nodes_dropped += 1;
    }
}

edge Door: Room --> Room {
    has w: int = 1;

    def drop {
        edges_dropped += 1;
    }
}

def reset {
    nodes_dropped = 0;
    edges_dropped = 0;
}

def note(seen: list[str], j: str) {
    if j not in seen {
        seen.append(j);
    }
}

"""A node that was never connected takes its jid with it."""
def loose_ids(n: int) -> int {
    reset();
    seen: list[str] = [];
    for i in range(n) {
        r = Room(tag=i);
        note(seen, jid(r));
    }
    return len(seen);
}

"""A node cut loose from the graph and freed takes its jid with it."""
def cut_ids(n: int) -> int {
    reset();
    hub = Room(tag=0);
    seen: list[str] = [];
    for i in range(n) {
        x = Room(tag=i);
        hub ++> x;
        note(seen, jid(x));
        hub del --> x;
    }
    return len(seen) + hub.tag;
}

"""An edge freed by a disconnect takes its jid with it."""
def edge_ids(n: int) -> int {
    reset();
    a = Room(tag=1);
    b = Room(tag=2);
    seen: list[str] = [];
    for i in range(n) {
        a +>:Door(w=i):+> b;
        for e in [edge a->:Door:->b] {
            note(seen, jid(e));
        }
        a del --> b;
    }
    return len(seen) * 1000 + edges_dropped + (a.tag + b.tag) * 0;
}

"""An edge object that was never connected takes its jid with it."""
def loose_edge_ids(n: int) -> int {
    reset();
    seen: list[str] = [];
    for i in range(n) {
        e = Door(w=i);
        note(seen, jid(e));
    }
    return len(seen);
}

"""A jid stays with its object for as long as something holds it."""
def stable_while_held -> int {
    reset();
    a = Room(tag=1);
    b = Room(tag=2);
    a +>:Door(w=3):+> b;
    es = [edge a->:Door:->b];
    je = jid(es[0]);
    jb = jid(b);
    a del --> b;
    same_edge = 1 if jid(es[0]) == je else 0;
    same_node = 1 if jid(b) == jb else 0;
    return same_edge * 100 + same_node * 10 + edges_dropped + a.tag * 0;
}

"""A bound endpoint holds the results it returns and nothing else."""
def endpoint_balance(n: int) -> int {
    reset();
    hub = Room(tag=0);
    kids: list[Room] = [];
    for i in range(n) {
        k = Room(tag=i + 1);
        hub +>:Door(w=i):+> k;
        kids.append(k);
    }
    hits = 0;
    for turn in range(3) {
        for k in kids {
            hits += len([hub->:Door:->k]) + len([edge hub->:Door:->k]);
        }
        hits += len([hub->:Door:->kids]);
    }
    early = nodes_dropped + edges_dropped;
    for k in kids {
        hub del --> k;
    }
    kids.clear();
    return hits * 10000 + early * 1000 + nodes_dropped * 10 + edges_dropped + hub.tag;
}

"""Edges a bound endpoint returned stay valid while the result is held."""
def endpoint_edges_held -> int {
    reset();
    a = Room(tag=1);
    b = Room(tag=2);
    a +>:Door(w=7):+> b;
    es = [edge a->:Door:->b];
    a del --> b;
    held = edges_dropped;
    return es[0].w * 100 + held * 10 + len(es);
}

def with_stranger(k: Room) -> list[Room] {
    return [k, Room(tag=7)];
}

"""A temporary node or list used as an endpoint, or passed to `jid`, is
released once the expression is done."""
def temporaries_released -> int {
    reset();
    hub = Room(tag=0);
    k = Room(tag=1);
    hub +>:Door():+> k;
    miss = len([hub->:Door:->Room(tag=9)]);
    after_endpoint = nodes_dropped;
    width = len(jid(Room(tag=8)));
    after_jid = nodes_dropped;
    ends = len([hub->:Door:->with_stranger(k)]);
    after_list = nodes_dropped;
    return miss * 100000
        + after_endpoint * 10000
        + after_jid * 1000
        + after_list * 100
        + ends * 10
        + (1 if width == 32 else 0)
        + (hub.tag + k.tag) * 0;
}

def serial(j: str) -> int {
    return int(j[16:], 16);
}

walker Ident {
    has node_id: int = 0,
        edge_id: int = 0;

    can look with Room entry {
        self.node_id = serial(jid(here));
        for e in [edge here->:Door:->] {
            self.edge_id = serial(jid(e));
        }
    }
}

def loose_in_region(i: int) -> int {
    rgn: own Region = Region();
    out = 0;
    in rgn {
        r = Room(tag=i);
        w = r spawn Ident();
        out = w.node_id;
    }
    return out;
}

def edge_in_region(i: int) -> int {
    rgn: own Region = Region();
    out = 0;
    in rgn {
        a = Room(tag=i);
        b = Room(tag=i);
        a +>:Door(w=i):+> b;
        w = a spawn Ident();
        out = w.edge_id;
    }
    return out;
}

"""A region's nodes and edges take their jids with the region, connected or
not."""
def region_ids(n: int) -> int {
    nodes: list[int] = [];
    edges: list[int] = [];
    for i in range(n) {
        j = loose_in_region(i);
        if j not in nodes {
            nodes.append(j);
        }
        k = edge_in_region(i);
        if k not in edges {
            edges.append(k);
        }
    }
    return len(nodes) * 100 + len(edges);
}
