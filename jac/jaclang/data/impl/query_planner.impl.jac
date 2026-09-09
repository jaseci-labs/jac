def _effective_bound(q: GraphQuery) -> (tuple[(int | None), int] | None) {
    if q.limit is not None {
        return (q.limit, q.offset);
    }
    slc = q.slc;
    if slc is None {
        return None;
    }
    (start, stop, step) = (slc.start, slc.stop, slc.step);
    if step is not None and step != 1 {
        return None;
    }
    if start is not None and (not isinstance(start, int) or start < 0) {
        return None;
    }
    if stop is not None and (not isinstance(stop, int) or stop < 0) {
        return None;
    }
    off = start or 0;
    return (None if stop is None else max(0, stop - off), off);
}


def _acl_pushdown_root(q: GraphQuery, upto: int) -> (str | None) {
    if not access_gated() {
        return None;
    }
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    import from jaclang.runtime.archetype { Archetype, Root }
    base = Archetype?.__jac_access__;
    for hop in q.hops[:upto] {
        nd = hop.nd;
        if nd is None {
            return None;
        }
        types = nd if isinstance(nd, tuple) else (nd, );
        for nt in types {
            if nt?.__jac_access__ is not base
                or (isinstance(nt, type) and issubclass(Root, nt)) {
                return None;
            }
        }
    }
    jctx = JacRuntimeInterface.get_context();
    ur = jctx?.user_root;
    return str(ur.id) if ur is not None else None;
}


def _bound_pushable -> bool {
    return not access_gated();
}


impl _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> tuple[list[tuple[(UUID | None), (UUID | None)]], list[QPred]] {
    store = mem.store;
    if store is None or not origin_ids {
        return ([], []);
    }
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    bound = _effective_bound(q);
    push = bound is not None and (acl_root is not None or _bound_pushable());
    eff = q;
    if bound is not None {
        eff = GraphQuery(
            q.origin,
            hops=q.hops,
            edges_only=q.edges_only,
            slc=None,
            order=q.order,
            limit=bound[0] if push else None,
            offset=bound[1] if push else 0,
            level=q.level
        );
        eff.from_visit = q.from_visit;
    }
    cq = compile_query(eff, upto, promotions=store?.promotions, acl_root=acl_root);
    tail: list[QPred] = [];
    if cq.residual {
        last = upto - 1;
        early = sorted(
            [
                h
                for h in cq.residual.keys()
                if h != last
            ]
        );
        if early {
            logger.error(
                f"graph query has non-pushable predicates at intermediate hops "
                f"{early}; results downstream of them are not filtered by those "
                f"predicates"
            );
        }
        tail = list(cq.residual.get(last) or []);
    }
    cq.params['origin'] = [str(i) for i in origin_ids];
    out: list[tuple[(UUID | None), (UUID | None)]] = [];
    for r in store.rows(cq.sql, cq.params) {
        nid = UUID(str(r[0])) if r[0] is not None else None;
        eid = UUID(str(r[1])) if r[1] is not None else None;
        out.append((nid, eid));
    }
    return (out, tail);
}


def _tail_ok(anchor: Anchor, tail: list[QPred]) -> bool {
    arch = anchor.archetype;
    if arch is None {
        return False;
    }
    for p in tail {
        if not p.matches(pred_subject(arch, p)) {
            return False;
        }
    }
    return True;
}


def _resolve_pairs(
    mem: Session, q: GraphQuery, upto: int
) -> tuple[list[tuple[any, any]], dict[any, Anchor], list[QPred]] {
    origins = origin_anchors(q);
    local: dict[any, Anchor] = {};
    sql_ids: list[UUID] = [];
    mem_origins: list[Anchor] = [];
    for oanch in origins {
        if mem.store is not None and oanch.persistent {
            sql_ids.append(oanch.ensure_id());
        } else {
            mem_origins.append(oanch);
        }
        local[anchor_key(oanch)] = oanch;
    }
    (pairs, tail) = _sql_pairs(mem, sql_ids, q, upto);
    if upto == 0 {
        pairs = [(i, None) for i in sql_ids];
    }
    for (a, e) in walk(mem_origins, q, upto, access_gated()) {
        akey = anchor_key(a);
        local[akey] = a;
        ekey: any = None;
        if e is not None {
            ekey = anchor_key(e);
            local[ekey] = e;
        }
        pairs.append((akey, ekey));
    }
    return (pairs, local, tail);
}


def _materialize_ids(
    mem: Session, ids: list, local: dict[any, Anchor]
) -> list[Anchor] {
    missing = [
        i
        for i in ids
        if i not in local
    ];
    fetched = mem.batch_get(missing) if missing else {};
    out: list[Anchor] = [];
    for i in ids {
        a = local.get(i) or fetched.get(i);
        if a is not None and a.is_populated() and a.archetype is not None {
            out.append(a);
        }
    }
    return out;
}


def _unique_nodes(pairs: list[tuple[any, any]]) -> list {
    seen: set = set();
    out: list = [];
    for (nid, _) in pairs {
        if nid is not None and nid not in seen {
            seen.add(nid);
            out.append(nid);
        }
    }
    return out;
}


impl resolve_query_prefix(mem: Session, q: GraphQuery, upto: int) -> list[UUID] {
    (pairs, _local, _tail) = _resolve_pairs(mem, q, upto);
    return [
        k
        for k in _unique_nodes(pairs)
        if isinstance(k, UUID)
    ];
}


impl resolve_query(mem: Session, q: GraphQuery) -> list[Anchor] {
    if not q.origin {
        return [];
    }
    origins = origin_anchors(q);
    gated = access_gated();

    if not needs_store(mem, origins) {
        return walk_nodes(origins, q, gated);
    }
    (pairs, local, tail) = _resolve_pairs(mem, q, len(q.hops));
    ids = _unique_nodes(pairs);
    out = _materialize_ids(mem, ids, local);
    if tail {
        out = [
            a
            for a in out
            if _tail_ok(a, tail)
        ];
    }
    if gated and not _acl_fully_pushed(mem, q) {
        out = [
            a
            for a in out
            if acl_read_ok(a)
        ];
    }
    bound = _effective_bound(q);
    if bound is not None {
        if not (_pushed_bound(mem, q) or _acl_fully_pushed(mem, q)) {
            stop = None if bound[0] is None else bound[1] + bound[0];
            out = out[bound[1]:stop];
        }
    } elif q.slc is not None {
        out = out[q.slc];
    }
    return out;
}


def _acl_fully_pushed(mem: Session, q: GraphQuery) -> bool {
    if mem.store is None or _acl_pushdown_root(q, len(q.hops)) is None {
        return False;
    }
    origins = origin_anchors(q);
    if not origins {
        return False;
    }
    for oanch in origins {
        if not oanch.persistent {
            return False;
        }
    }
    return True;
}


def _pushed_bound(mem: Session, q: GraphQuery) -> bool {
    if mem.store is None or not _bound_pushable() {
        return False;
    }
    for oanch in origin_anchors(q) {
        if not oanch.persistent {
            return False;
        }
    }
    return bool(origin_anchors(q));
}


impl resolve_query_edges(mem: Session, q: GraphQuery) -> list[Anchor] {
    if not q.origin or not q.hops {
        return [];
    }
    origins = origin_anchors(q);
    gated = access_gated();
    if not needs_store(mem, origins) {
        return walk_edges(origins, q, gated);
    }
    (pairs, local, tail) = _resolve_pairs(mem, q, len(q.hops));
    edge_ids: list = [];
    node_of: dict = {};
    seen: set = set();
    for (nid, eid) in pairs {
        if eid is None or eid in seen {
            continue;
        }
        seen.add(eid);
        edge_ids.append(eid);
        if nid is not None {
            node_of[eid] = nid;
        }
    }
    edges = _materialize_ids(mem, edge_ids, local);
    if access_gated() {
        kept: list[Anchor] = [];
        for ea in edges {
            if not acl_read_ok(ea) {
                continue;
            }
            nid = node_of.get(anchor_key(ea));
            if nid is not None {
                ends = _materialize_ids(mem, [nid], local);
                if not ends or not acl_read_ok(ends[0]) {
                    continue;
                }
            }
            kept.append(ea);
        }
        edges = kept;
    }
    if not q.from_visit {
        out_e: list[Anchor] = list(edges);
        if q.slc is not None {
            out_e = out_e[q.slc];
        }
        return out_e;
    }
    out: list[Anchor] = [];
    seen_nodes: set = set();
    for ea in edges {
        out.append(ea);
        nid = node_of.get(anchor_key(ea));
        if nid is None or nid in seen_nodes {
            continue;
        }
        nodes = _materialize_ids(mem, [nid], local);
        if nodes {
            seen_nodes.add(nid);
            out.append(nodes[0]);
        }
    }
    if q.slc is not None {
        out = out[q.slc];
    }
    return out;
}


impl resolve_query_count(mem: Session, q: GraphQuery) -> int {
    store = mem.store;
    origins = origin_anchors(q);
    if store is None
        or not needs_store(mem, origins)
        or access_gated()
        or q.from_visit {
        return len(_resolve_for(mem, q));
    }
    ids: list[UUID] = [];
    for oanch in origins {
        if not oanch.persistent {
            return len(_resolve_for(mem, q));
        }
        ids.append(oanch.ensure_id());
    }
    mem.read_barrier();
    cq = compile_query(q, len(q.hops), promotions=store?.promotions, count_only=True);
    if cq.residual {
        return len(_resolve_for(mem, q));
    }
    cq.params['origin'] = [str(i) for i in ids];
    rows = store.rows(cq.sql, cq.params);
    return int(rows[0][0]) if rows else 0;
}


def _resolve_for(mem: Session, q: GraphQuery) -> list[Anchor] {
    return resolve_query_edges(mem, q) if q.edges_only else resolve_query(mem, q);
}


impl resolve_query_exists(mem: Session, q: GraphQuery) -> bool {
    probe = GraphQuery(
        q.origin,
        hops=q.hops,
        edges_only=q.edges_only,
        slc=None,
        order=q.order,
        limit=1,
        level=q.level
    );
    probe.from_visit = q.from_visit;
    return bool(_resolve_for(mem, probe));
}


impl LazyRefs.init(self: LazyRefs, resolve: any, query: GraphQuery) -> None {
    super.init();
    self._resolve = resolve;
    self._query = query;
    self._done = False;
}


impl LazyRefs._realize(self: LazyRefs) -> None {
    if self._done {
        return;
    }
    self._done = True;
    list.extend(self, self._resolve(self._query));
}


impl LazyRefs._bounded(self: LazyRefs, limit: (int | None), offset: int) -> list {
    q = self._query;
    bounded = GraphQuery(
        q.origin,
        hops=q.hops,
        edges_only=q.edges_only,
        slc=None,
        order=q.order,
        limit=limit,
        offset=offset,
        level=q.level
    );
    bounded.from_visit = q.from_visit;
    return self._resolve(bounded);
}


impl LazyRefs.__len__(self: LazyRefs) -> int {
    if self._done {
        return list.__len__(self);
    }
    return self._count();
}


impl LazyRefs._count(self: LazyRefs) -> int {
    try {
        return resolve_query_count(self._mem(), self._query);
    } except Exception {
        self._realize();
        return list.__len__(self);
    }
}


impl LazyRefs._mem(self: LazyRefs) -> any {
    import from jaclang.runtime.runtime { JacRuntimeInterface }
    return JacRuntimeInterface.get_context().mem;
}


impl LazyRefs.__bool__(self: LazyRefs) -> bool {
    if self._done {
        return list.__len__(self) > 0;
    }
    try {
        return bool(self._bounded(1, 0));
    } except Exception {
        self._realize();
        return list.__len__(self) > 0;
    }
}


impl LazyRefs.__iter__(self: LazyRefs) -> any {
    self._realize();
    return list.__iter__(self);
}


impl LazyRefs.__getitem__(self: LazyRefs, key: any) -> any {
    if self._done {
        return list.__getitem__(self, key);
    }
    if isinstance(key, int) and key >= 0 {
        got = self._bounded(1, key);
        if not got {
            raise IndexError('list index out of range');
        }
        return got[0];
    }
    if isinstance(key, slice) {
        (start, stop, step) = (key.start, key.stop, key.step);
        if (step is None or step == 1)
            and (start is None or (isinstance(start, int) and start >= 0))
            and (stop is None or (isinstance(stop, int) and stop >= 0)) {
            off = start or 0;
            lim = None if stop is None else max(0, stop - off);
            return self._bounded(lim, off);
        }
    }
    self._realize();
    return list.__getitem__(self, key);
}


impl LazyRefs.__repr__(self: LazyRefs) -> str {
    self._realize();
    return list.__repr__(self);
}


impl LazyRefs.__eq__(self: LazyRefs, other: any) -> bool {
    self._realize();
    return list.__eq__(self, other);
}


impl LazyRefs.__contains__(self: LazyRefs, item: any) -> bool {
    self._realize();
    return list.__contains__(self, item);
}


impl LazyRefs.__reversed__(self: LazyRefs) -> any {
    self._realize();
    return list.__reversed__(self);
}


impl LazyRefs.__add__(self: LazyRefs, other: any) -> any {
    self._realize();
    return list.__add__(self, other);
}


impl LazyRefs.__setitem__(self: LazyRefs, key: any, value: any) -> None {
    self._realize();
    list.__setitem__(self, key, value);
}


impl LazyRefs.__delitem__(self: LazyRefs, key: any) -> None {
    self._realize();
    list.__delitem__(self, key);
}


impl LazyRefs.append(self: LazyRefs, item: any) -> None {
    self._realize();
    list.append(self, item);
}


impl LazyRefs.extend(self: LazyRefs, items: any) -> None {
    self._realize();
    list.extend(self, items);
}


impl LazyRefs.insert(self: LazyRefs, i: int, item: any) -> None {
    self._realize();
    list.insert(self, i, item);
}


impl LazyRefs.remove(self: LazyRefs, item: any) -> None {
    self._realize();
    list.remove(self, item);
}


impl LazyRefs.pop(self: LazyRefs, i: int = -1) -> any {
    self._realize();
    return list.pop(self, i);
}


impl LazyRefs.clear(self: LazyRefs) -> None {
    self._done = True;
    list.clear(self);
}


impl LazyRefs.sort(self: LazyRefs, **kw: any) -> None {
    self._realize();
    list.sort(self, **kw);
}


impl LazyRefs.reverse(self: LazyRefs) -> None {
    self._realize();
    list.reverse(self);
}


impl LazyRefs.index(self: LazyRefs, item: any, *a: any) -> int {
    self._realize();
    return list.index(self, item, *a);
}


impl LazyRefs.count(self: LazyRefs, item: any) -> int {
    self._realize();
    return list.count(self, item);
}


impl LazyRefs.copy(self: LazyRefs) -> list {
    self._realize();
    return list(self);
}
