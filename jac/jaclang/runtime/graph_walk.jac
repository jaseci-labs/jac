import from jaclang.runtime.archetype {
    Anchor,
    EdgeAnchor,
    NodeAnchor,
    anchor_key,
    light_edge_view,
    same_anchor
}
import from jaclang.runtime.graph_query { GraphQuery, QHop, QPred }

glob __all__ = [
         'access_gated',
         'acl_read_ok',
         'bounded',
         'edge_pair_for',
         'hop_matches_node',
         'needs_store',
         'origin_anchors',
         'pred_subject',
         'unique_anchors',
         'walk',
         'walk_edges',
         'walk_nodes'
     ];


def access_gated -> bool {
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    jctx = JacRuntimeInterface.peek_context();
    if jctx is None {
        return False;
    }
    ur = jctx?.user_root;
    return ur is not None and ur != jctx.system_root;
}


def acl_read_ok(anchor: Anchor) -> bool {
    import from jaclang.runtime.archetype { AccessLevel }
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    level = JacRuntimeInterface.check_access_level(anchor);
    return level.value > AccessLevel.NO_ACCESS.value;
}


def has_persistent_origin(origins: list[Anchor]) -> bool {
    for a in origins {
        if a.persistent {
            return True;
        }
    }
    return False;
}


def needs_store(mem: any, origins: list[Anchor]) -> bool {
    if not origins or mem?.store is None {
        return False;
    }
    return has_persistent_origin(origins);
}


def origin_anchors(q: GraphQuery) -> list[Anchor] {
    seen: set = set();
    out: list[Anchor] = [];
    for arch in q.origin {
        oanch = arch?.__jac__;
        if isinstance(oanch, Anchor) {
            key = anchor_key(oanch);
            if key not in seen {
                seen.add(key);
                out.append(oanch);
            }
        }
    }
    return out;
}


def pred_subject(arch: any, p: QPred) -> any {
    if isinstance(p.field, tuple) {
        return tuple(getattr(arch, name, None) for name in p.field);
    }
    return getattr(arch, p.field, None);
}


def hop_matches_node(anchor: Anchor, hop: QHop) -> bool {
    if not anchor.is_populated() or anchor.archetype is None {
        return False;
    }
    nd = hop.nd;
    if nd is not None {
        types = nd if isinstance(nd, tuple) else (nd, );
        for nt in types {
            if not isinstance(anchor.archetype, nt) {
                return False;
            }
        }
    }
    for p in hop.preds {
        if not p.matches(pred_subject(anchor.archetype, p)) {
            return False;
        }
    }
    want = hop.only_keys();
    return want is None or anchor_key(anchor) in want;
}


def edge_pair_for(e: EdgeAnchor, cur: Anchor, hop: QHop) -> (Anchor | None) {
    src = e.source;
    tgt = e.target;
    if src is None or tgt is None or e.archetype is None {
        return None;
    }
    other: (Anchor | None) = None;
    from_src = same_anchor(src, cur);
    from_tgt = same_anchor(tgt, cur);
    if hop.dir == 1 {
        if from_tgt {
            other = src;
        } elif e.is_undirected and from_src {
            other = tgt;
        }
    } elif hop.dir == 3 {
        if from_src {
            other = tgt;
        } elif from_tgt {
            other = src;
        }
    } else {
        if from_src {
            other = tgt;
        } elif e.is_undirected and from_tgt {
            other = src;
        }
    }
    if other is None {
        return None;
    }
    if hop.`edge is not None and not isinstance(e.archetype, hop.`edge) {
        return None;
    }
    for p in hop.epreds {
        if not p.matches(pred_subject(e.archetype, p)) {
            return None;
        }
    }
    return other if hop_matches_node(other, hop) else None;
}


def _walk_light(
    cur: NodeAnchor,
    hop: QHop,
    outgoing: bool,
    want_edges: bool,
    gated: bool,
    seen: set,
    nxt: list[tuple[Anchor, (EdgeAnchor | None)]]
) -> None {
    d = cur.out_light if outgoing else cur.in_light;
    if not d {
        return;
    }
    ecls = hop.`edge;
    for (k, lst) in d.items() {
        if ecls is not None and not issubclass(k, ecls) {
            continue;
        }
        for item in lst {
            arch = item if outgoing else item();
            if arch is None {
                continue;
            }
            other = arch.__jac__;
            if not hop_matches_node(other, hop) {
                continue;
            }
            if gated and not acl_read_ok(other) {
                continue;
            }
            key = (k, id(cur), id(other)) if outgoing else (k, id(other), id(cur));
            if key in seen {
                continue;
            }
            seen.add(key);
            e: (EdgeAnchor | None) = None;
            if want_edges {
                view = light_edge_view(k, cur, other)
                    if outgoing
                    else light_edge_view(k, other, cur);
                e = view.__jac__;
            }
            nxt.append((other, e));
        }
    }
}


def walk(
    origins: list[Anchor], q: GraphQuery, upto: int, gated: bool
) -> list[tuple[Anchor, (EdgeAnchor | None)]] {
    frontier: list[Anchor] = list(origins);
    pairs: list[tuple[Anchor, (EdgeAnchor | None)]] = [(a, None) for a in origins];
    nhops = min(upto, len(q.hops));
    i = 0;
    while i < nhops {
        hop = q.hops[i];
        i += 1;
        nxt: list[tuple[Anchor, (EdgeAnchor | None)]] = [];
        seen_edges: set = set();
        for cur in frontier {
            if not isinstance(cur, NodeAnchor) or not cur.is_populated() {
                continue;
            }
            if not hop.epreds {
                if hop.dir != 1 {
                    _walk_light(cur, hop, True, q.edges_only, gated, seen_edges, nxt);
                }
                if hop.dir != 2 {
                    _walk_light(cur, hop, False, q.edges_only, gated, seen_edges, nxt);
                }
            }
            for e in list(cur.edges) {
                if not e.is_populated() {
                    continue;
                }
                ekey = anchor_key(e);
                if ekey in seen_edges {
                    continue;
                }
                other = edge_pair_for(e, cur, hop);
                if other is not None {
                    if gated and not acl_read_ok(other) {
                        continue;
                    }
                    seen_edges.add(ekey);
                    nxt.append((other, e));
                }
            }
        }
        pairs = nxt;

        if i < nhops {
            frontier = unique_anchors(nxt);
        }
    }
    return pairs;
}


def unique_anchors(pairs: list[tuple[Anchor, (EdgeAnchor | None)]]) -> list[Anchor] {
    seen: set = set();
    out: list[Anchor] = [];
    for (a, _) in pairs {
        key = anchor_key(a);
        if key not in seen {
            seen.add(key);
            out.append(a);
        }
    }
    return out;
}


def bounded(out: list[Anchor], q: GraphQuery) -> list[Anchor] {
    if q.limit is not None {
        return out[q.offset:q.offset + q.limit];
    }
    if q.slc is not None {
        return out[q.slc];
    }
    return out;
}


def walk_nodes(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor] {
    return bounded(unique_anchors(walk(origins, q, len(q.hops), gated)), q);
}


def walk_edges(origins: list[Anchor], q: GraphQuery, gated: bool) -> list[Anchor] {
    if not q.hops {
        return [];
    }
    edges: list[Anchor] = [];
    node_of: dict[object, any] = {};
    seen: set = set();
    for (a, e) in walk(origins, q, len(q.hops), gated) {
        if e is None {
            continue;
        }
        ekey = anchor_key(e);
        if ekey in seen {
            continue;
        }
        seen.add(ekey);
        edges.append(e);
        node_of[ekey] = a;
    }
    if not q.from_visit {
        return edges[q.slc] if q.slc is not None else edges;
    }
    out: list[Anchor] = [];
    seen_nodes: set = set();
    for e in edges {
        out.append(e);
        nd = node_of.get(anchor_key(e));
        if nd is None {
            continue;
        }
        nkey = anchor_key(nd);
        if nkey in seen_nodes {
            continue;
        }
        seen_nodes.add(nkey);
        out.append(nd);
    }
    return out[q.slc] if q.slc is not None else out;
}
