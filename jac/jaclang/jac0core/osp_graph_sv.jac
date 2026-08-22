import jaclang.jac0core.osp_graph as _graph;
import from dataclasses { field }
import from jaclang.jac0core.archetype { Anchor, EdgeAnchor, NodeAnchor }

obj _SvStore {
    has h_of_id: dict[str, int] = {},
        registered: set[str] = field(default_factory=`set),
        forgotten: set[str] = field(default_factory=`set),
        region: int = 0;
}

glob _obj_of_h: list[(Anchor | None)] = [None],
     _h_free: list[int] = [],
     _next_region: list[int] = [1],
     _tag_of_cls: dict[(type, int)] = {},
     _cls_of_tag_map: dict[(int, type)] = {},
     _fallback: _SvStore = _SvStore();

def _mem_or_ctx(mem: any) -> any {
    if mem is not None {
        return mem;
    }
    import from jaclang.jac0core.runtime { JacRuntimeInterface }
    try {
        return JacRuntimeInterface.get_context().mem;
    } except Exception {
        return None;
    }
}

def _store_for(m: any) -> _SvStore {
    if m is None {
        return _fallback;
    }
    d = m.__dict__;
    st = d.get('_osp_sv_store');
    if st is None {
        st = _SvStore(region=_next_region[0]);
        _next_region[0] += 1;
        d['_osp_sv_store'] = st;
    }
    return st;
}

def _mint(st: _SvStore, anchor: Anchor) -> int {
    key = str(anchor.id);
    h = st.h_of_id.get(key, 0);
    if h == 0 {
        if _h_free {
            h = _h_free.pop();
            _obj_of_h[h] = anchor;
        } else {
            _obj_of_h.append(anchor);
            h = len(_obj_of_h) - 1;
        }
        st.h_of_id[key] = h;
        return h;
    }
    if anchor.is_populated() or _obj_of_h[h] is None {
        _obj_of_h[h] = anchor;
    }
    return h;
}

def handle_of(anchor: Anchor, mem: any = None) -> int {
    return _mint(_store_for(_mem_or_ctx(mem)), anchor);
}

def obj_of(h: int) -> (Anchor | None) {
    if h <= 0 or h >= len(_obj_of_h) {
        return None;
    }
    return _obj_of_h[h];
}

def tag_of_cls(cls: type) -> int {
    t = _tag_of_cls.get(cls);
    if t is None {
        import from jaclang.jac0core.osp_model { stable_osp_tag }
        t = stable_osp_tag(cls.__name__);
        _tag_of_cls[cls] = t;
        _cls_of_tag_map[t] = cls;
    }
    return t;
}

def cls_of_tag(tag: int) -> (type | None) {
    return _cls_of_tag_map.get(tag);
}

def tag_for(edge_a: EdgeAnchor) -> int {
    return tag_of_cls(`type(edge_a.archetype));
}

def _resolve(cand: (Anchor | None), m: any) -> (Anchor | None) {
    if cand is None or m is None {
        return cand;
    }
    cur = m.get_mem().get(cand.id);
    if cur is not None and cur.is_populated() {
        return cur;
    }
    return cand;
}

def sv_conn(
    src_a: NodeAnchor,
    tgt_a: NodeAnchor,
    edge_a: EdgeAnchor,
    is_undirected: bool,
    mem: any = None
) -> None {
    m = _mem_or_ctx(mem);
    st = _store_for(m);
    key = str(edge_a.id);
    if key in st.registered {
        _mint(st, edge_a);
        return;
    }
    st.forgotten.discard(key);
    eh = _mint(st, edge_a);
    _graph.osp_conn(
        _mint(st, src_a),
        _mint(st, tgt_a),
        eh,
        1 if is_undirected else 0,
        tag_for(edge_a),
        st.region,
        st.region
    );
    st.registered.add(key);
}

def sv_live_edges(
    origin_a: NodeAnchor,
    dir_int: int,
    edge_type: (type | None),
    edges_only: bool,
    mem: any = None
) -> list[Anchor] {
    m = _mem_or_ctx(mem);
    st = _store_for(m);
    oh = _mint(st, origin_a);
    if edge_type is None {
        out: list[Anchor] = [];
        for h in _graph.osp_refs(oh, dir_int, -1, 1 if edges_only else 0) {
            a = _resolve(obj_of(h), m);
            if a is not None {
                out.append(a);
            }
        }
        return out;
    }
    okey = str(origin_a.id);
    hits: list[EdgeAnchor] = [];
    for h in _graph.osp_refs(oh, dir_int, -1, 1) {
        e = _resolve(obj_of(h), m);
        if not isinstance(e, EdgeAnchor) or not e.is_populated() {
            continue;
        }
        if isinstance(e.archetype, edge_type) {
            hits.append(e);
        }
    }
    if edges_only {
        return hits;
    }
    ends: list[Anchor] = [];
    seen: set[str] = set();
    for e in hits {
        o_a = e.target if str(e.source.id) == okey else e.source;
        ra = _resolve(o_a, m);
        if ra is None {
            continue;
        }
        rk = str(ra.id);
        if rk not in seen {
            seen.add(rk);
            ends.append(ra);
        }
    }
    return ends;
}

def sv_candidate_edges_between(
    src_a: NodeAnchor, tgt_a: NodeAnchor, dir_int: int, mem: any = None
) -> list[EdgeAnchor] {
    skey = str(src_a.id);
    tkey = str(tgt_a.id);
    out: list[EdgeAnchor] = [];
    for e in sv_live_edges(src_a, dir_int, None, True, mem) {
        if not isinstance(e, EdgeAnchor) or not e.is_populated() {
            continue;
        }
        okey = str(e.target.id) if str(e.source.id) == skey else str(e.source.id);
        if okey == tkey {
            out.append(e);
        }
    }
    return out;
}

def _conn_hydrated(e: EdgeAnchor, m: any) -> None {
    src_a = e.source;
    tgt_a = e.target;
    if src_a is None or tgt_a is None {
        return;
    }
    sv_conn(src_a, tgt_a, e, e.is_undirected, m);
}

def sv_register_hydrated(
    node_a: NodeAnchor, mem: any = None, fetch_stubs: bool = False
) -> None {
    if not isinstance(node_a, NodeAnchor) or not node_a.is_populated() {
        return;
    }
    m = _mem_or_ctx(mem);
    _mint(_store_for(m), node_a);
    pending: list[EdgeAnchor] = [];
    for e in list(node_a.edges) {
        if not e.is_populated() {
            if fetch_stubs {
                pending.append(e);
            }
            continue;
        }
        if isinstance(e, EdgeAnchor) {
            _conn_hydrated(e, m);
        }
    }
    if pending and m is not None {
        batch = m?.batch_get;
        fetched = batch([p.id for p in pending])
            if batch is not None
            else {p.id: m.get(p.id) for p in pending};
        for p in pending {
            fa = fetched.get(p.id);
            if isinstance(fa, EdgeAnchor) and fa.is_populated() {
                _conn_hydrated(fa, m);
            }
        }
    }
}

def sv_edge_alive(edge_a: EdgeAnchor, mem: any = None) -> bool {
    st = _store_for(_mem_or_ctx(mem));
    return str(edge_a.id) not in st.forgotten;
}

def sv_forget_by_id(anchor_id: any, mem: any = None) {
    st = _store_for(_mem_or_ctx(mem));
    key = str(anchor_id);
    st.registered.discard(key);
    st.forgotten.add(key);
    h = st.h_of_id.get(key, 0);
    if h > 0 {
        _graph.osp_disconnect(h);
    }
}

def sv_forget_edge(edge_a: EdgeAnchor, mem: any = None) {
    sv_forget_by_id(edge_a.id, mem);
}

def sv_store_closed(mem: any) -> int {
    if mem is None {
        return 0;
    }
    st = mem.__dict__.pop('_osp_sv_store', None);
    if st is None {
        return 0;
    }
    n = 0;
    if st.region != 0 {
        n = _graph.osp_region_died(st.region);
    }
    for h in st.h_of_id.values() {
        if h > 0 and h < len(_obj_of_h) {
            _obj_of_h[h] = None;
            _h_free.append(h);
        }
    }
    return n;
}
