def _effective_bound(q: GraphQuery) -> (tuple[(int | None), int] | None);


def _acl_pushdown_root(q: GraphQuery, upto: int) -> (str | None);


def _bound_pushable -> bool;


def _residual_classes(nd: (type | tuple[type, ...] | None)) -> list[type];


def _acl_residual(q: GraphQuery, upto: int, store: any) -> dict[int, list[str]];


def _rechecks(anchor: Anchor) -> bool;


def _scan(
    mem: Session, q: GraphQuery, distinct: bool, lookahead: bool
) -> tuple[list[tuple[Anchor, (Anchor | None)]], (tuple[int, (UUID | None)] | None)];


def _split_tail(cq: CompiledQuery, upto: int) -> list[QPred];


def _with_bound(q: GraphQuery, limit: (int | None), offset: int) -> GraphQuery;


impl _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> tuple[list[tuple[(UUID | None), (UUID | None)]], list[QPred]] {
    store = mem.store;
    if store is None or not origin_ids {
        return ([], []);
    }
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    bound = _effective_bound(q);
    push = bound is not None
        and (
            _bound_pushable() or (acl_root is not None and (upto - 1) not in residual)
        );
    eff = q;
    if bound is not None {
        eff = _with_bound(q, bound[0] if push else None, bound[1] if push else 0);
    }
    cq = compile_query(
        eff,
        upto,
        store,
        promotions=store?.promotions,
        acl_root=acl_root,
        acl_residual=residual
    );
    tail = _split_tail(cq, upto);
    if upto > 0
        and len(origin_ids) == 1
        and eff.limit is None
        and not eff.offset
        and mem.batching() {
        key = (cq.sql, _param_key(cq.params));
        hit = mem.hop_cached(key, origin_ids[0]);
        if hit is not None {
            return (hit, tail);
        }
        siblings = mem.hop_siblings(origin_ids[0]);
        if len(siblings) > 1 and origin_ids[0] in siblings {
            by_origin = _hop_by_origin(store, cq, list(siblings));
            mem.hop_store(key, by_origin);
            reached = _unique_nodes([p for pairs in by_origin.values() for p in pairs]);
            if reached {
                mem.batch_get(reached);
                mem.note_siblings(reached);
            }
            return (by_origin.get(origin_ids[0], []), tail);
        }
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


def _hop_by_origin(
    store: any, cq: any, origins: list[UUID]
) -> dict[UUID, list[tuple[(UUID | None), (UUID | None)]]];


def _param_key(params: dict[str, any]) -> tuple[tuple[str, str], ...];


def _tail_ok(anchor: Anchor, tail: list[QPred]) -> bool;


def _resolve_pairs(
    mem: Session, q: GraphQuery, upto: int
) -> tuple[list[tuple[any, any]], dict[any, Anchor], list[QPred]];


def _materialize_ids(
    mem: Session, ids: list[any], local: dict[any, Anchor]
) -> list[Anchor];


def _unique_nodes(pairs: list[tuple[any, any]]) -> list[any];


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
    if gated
        and q.hops
        and _effective_bound(q) is not None
        and _acl_fully_pushed(mem, q) {
        return [n for (n, _) in _scan(mem, q, True, False)[0]];
    }
    (pairs, local, tail) = _resolve_pairs(mem, q, len(q.hops));
    ids = _unique_nodes(pairs);
    mem.note_siblings(
        [
            i
            for i in ids
            if isinstance(i, UUID)
        ]
    );
    out = _materialize_ids(mem, ids, local);
    if tail {
        out = [
            a
            for a in out
            if _tail_ok(a, tail)
        ];
    }
    pushed = gated and _acl_fully_pushed(mem, q);
    if gated {
        out = [
            a
            for a in out
            if (pushed and not _rechecks(a)) or acl_read_ok(a)
        ];
    }
    bound = _effective_bound(q);
    if bound is not None {
        if not _pushed_bound(mem, q) {
            stop = None if bound[0] is None else bound[1] + bound[0];
            out = out[bound[1]:stop];
        }
    } elif q.slc is not None {
        out = out[q.slc];
    }
    return out;
}


def _acl_fully_pushed(mem: Session, q: GraphQuery) -> bool;


def _pushed_bound(mem: Session, q: GraphQuery) -> bool;


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
    edge_ids: list[any] = [];
    node_of: dict[object, any] = {};
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
    gated = access_gated();
    if store is None
        or not needs_store(mem, origins)
        or q.from_visit
        or (gated and (q.edges_only or not _acl_fully_pushed(mem, q))) {
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
    upto = len(q.hops);
    acl_root = _acl_pushdown_root(q, upto) if upto else None;
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    cq = compile_query(
        q,
        upto,
        store,
        promotions=store?.promotions,
        count_only=True,
        acl_root=acl_root,
        acl_residual=residual
    );
    if cq.residual {
        return len(_resolve_for(mem, q));
    }
    cq.params['origin'] = [str(i) for i in ids];
    rows = store.rows(cq.sql, cq.params);
    total = int(rows[0][0]) if rows else 0;
    if (upto - 1) in residual {
        rq = compile_query(
            _with_bound(q, None, 0),
            upto,
            store,
            promotions=store?.promotions,
            acl_root=acl_root,
            acl_residual=residual,
            residual_only=True
        );
        rq.params['origin'] = [str(i) for i in ids];
        found = mem.batch_get(
            _unique_nodes(
                [
                    (UUID(str(r[0])), None)
                    for r in store.rows(rq.sql, rq.params)
                    if r[0] is not None
                ]
            )
        );
        total += len(
            [
                a
                for a in found.values()
                if a is not None
                    and a.is_populated()
                    and a.archetype is not None
                    and acl_read_ok(a)
            ]
        );
    }
    return total;
}


def _resolve_for(mem: Session, q: GraphQuery) -> list[Anchor];


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


impl LazyRefs._bounded(self: LazyRefs, limit: (int | None), offset: int) -> list[any] {
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


impl LazyRefs.copy(self: LazyRefs) -> list[any] {
    self._realize();
    return list(self);
}

impl _effective_bound(q: GraphQuery) -> (tuple[(int | None), int] | None) {
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


impl _acl_pushdown_root(q: GraphQuery, upto: int) -> (str | None) {
    if not access_gated() {
        return None;
    }
    jctx = JacRuntimeInterface.get_context();
    ur = jctx?.user_root;
    return str(ur.id) if ur is not None else None;
}


impl _residual_classes(nd: (type | tuple[type, ...] | None)) -> list[type] {
    wanted = [] if nd is None else (list(nd) if isinstance(nd, tuple) else [nd]);
    base = Archetype?.__jac_access__;
    out: list[type] = [];
    pending: list[type] = [NodeArchetype];
    seen: set = set();
    while pending {
        cls = pending.pop();
        if cls in seen {
            continue;
        }
        seen.add(cls);
        pending.extend(cls.__subclasses__());
        if not (issubclass(cls, Root) or cls?.__jac_access__ is not base) {
            continue;
        }
        if all(
            issubclass(cls, t)
            for t in wanted
            if isinstance(t, type)
        ) {
            out.append(cls);
        }
    }
    return out;
}


impl _acl_residual(q: GraphQuery, upto: int, store: any) -> dict[int, list[str]] {
    out: dict[int, list[str]] = {};
    for (i, hop) in enumerate(q.hops[:upto]) {
        names: list[str] = [];
        for cls in _residual_classes(hop.nd) {
            tname = storage_type(cls);
            if not tname or tname in names {
                continue;
            }
            for name in [tname] + list(store.subtype_names(tname)) {
                if name not in names {
                    names.append(name);
                }
            }
        }
        if names {
            out[i] = names;
        }
    }
    return out;
}


impl _rechecks(anchor: Anchor) -> bool {
    arch = anchor.archetype;
    return isinstance(arch, Root)
        or type(arch)?.__jac_access__ is not Archetype?.__jac_access__;
}


impl _split_tail(cq: CompiledQuery, upto: int) -> list[QPred] {
    if not cq.residual {
        return [];
    }
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
    return list(cq.residual.get(last) or []);
}


impl _with_bound(q: GraphQuery, limit: (int | None), offset: int) -> GraphQuery {
    eff = GraphQuery(
        q.origin,
        hops=q.hops,
        edges_only=q.edges_only,
        slc=None,
        order=q.order,
        limit=limit,
        offset=offset,
        level=q.level,
        after=q.after
    );
    eff.from_visit = q.from_visit;
    return eff;
}


impl _scan(
    mem: Session, q: GraphQuery, distinct: bool, lookahead: bool
) -> tuple[list[tuple[Anchor, (Anchor | None)]], (tuple[int, (UUID | None)] | None)] {
    store = mem.store;
    upto = len(q.hops);
    origins = origin_anchors(q);
    if store is None {
        return ([], None);
    }
    if q.after is not None and (len(origins) != 1 or q.order) {
        raise ValueError('a keyset cursor applies to one origin in edge order');
    }
    ids = [o.ensure_id() for o in origins];
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    promos = store?.promotions;
    tail = _split_tail(
        compile_query(
            q, upto, store, promotions=promos, acl_root=acl_root, acl_residual=residual
        ),
        upto
    );
    (limit, offset) = _effective_bound(q) or (None, 0);
    exact = not tail and (upto - 1) not in residual;
    skip_left = 0 if exact else offset;
    raw_off = offset if exact else 0;
    out: list[tuple[Anchor, (UUID | None)]] = [];
    seen: set = set();
    last_key: (tuple[int, (UUID | None)] | None) = None;
    more = False;
    while True {
        need = None if limit is None else limit - len(out);
        chunk = None if need is None else need + skip_left + (1 if lookahead else 0);
        cq = compile_query(
            _with_bound(q, chunk, raw_off),
            upto,
            store,
            promotions=promos,
            acl_root=acl_root,
            acl_residual=residual
        );
        cq.params['origin'] = [str(i) for i in ids];
        rows = store.rows(cq.sql, cq.params);
        take = rows if chunk is None or not lookahead else rows[:chunk - 1];
        found = mem.batch_get(
            _unique_nodes(
                [
                    (UUID(str(r[0])), None)
                    for r in take
                    if r[0] is not None
                ]
            )
        );
        stopped = False;
        used = 0;
        for r in take {
            used += 1;
            raw_off += 1;
            eid = UUID(str(r[1])) if r[1] is not None else None;
            last_key = (int(str(r[4])), eid) if r[4] is not None else None;
            if r[0] is None {
                continue;
            }
            nid = UUID(str(r[0]));
            a = found.get(nid);
            if a is None or not a.is_populated() or a.archetype is None {
                continue;
            }
            if distinct and nid in seen {
                continue;
            }
            if tail and not _tail_ok(a, tail) {
                continue;
            }
            if acl_root is not None and _rechecks(a) and not acl_read_ok(a) {
                continue;
            }
            seen.add(nid);
            if skip_left > 0 {
                skip_left -= 1;
                continue;
            }
            out.append((a, eid));
            if limit is not None and len(out) >= limit {
                stopped = True;
                break;
            }
        }
        if stopped {
            more = len(rows) > used;
            break;
        }
        if chunk is None or len(rows) < chunk {
            break;
        }
    }
    edge_ids: list[UUID] = [];
    for (_, e) in out {
        if e is not None {
            edge_ids.append(e);
        }
    }
    edges = mem.batch_get(edge_ids) if edge_ids and not distinct else {};
    pairs: list[tuple[Anchor, (Anchor | None)]] = [
        (a, edges.get(e) if e is not None else None) for (a, e) in out
    ];
    return (pairs, last_key if more else None);
}


impl resolve_query_page(
    mem: Session, q: GraphQuery
) -> tuple[list[tuple[Anchor, (Anchor | None)]], (tuple[int, (UUID | None)] | None)] {
    origins = origin_anchors(q);
    if len(q.hops) != 1 or len(origins) != 1 or q.order or q.edges_only {
        raise ValueError('a page is one hop from one node in edge order');
    }
    gated = access_gated();
    if needs_store(mem, origins) and origins[0].persistent {
        if not gated or _acl_fully_pushed(mem, q) {
            return _scan(mem, q, False, True);
        }
    }
    pairs = walk(origins, q, 1, gated);
    start = int(q.after[0]) if q.after is not None else 0;
    stop = None if q.limit is None else start + q.limit;
    page = [(a, e) for (a, e) in pairs[start:stop]];
    nxt = (stop, None) if stop is not None and stop < len(pairs) else None;
    return (page, nxt);
}


impl resolve_query_type_counts(
    mem: Session, q: GraphQuery, per: str = 'node'
) -> dict[str, int] {
    store = mem.store;
    origins = origin_anchors(q);
    gated = access_gated();
    upto = len(q.hops);
    counts: dict[str, int] = {};
    if store is None
        or upto == 0
        or not needs_store(mem, origins)
        or not all(o.persistent for o in origins)
        or (gated and not _acl_fully_pushed(mem, q)) {
        for (a, e) in walk(origins, q, upto, gated) {
            subject = e if per == 'edge' else a;
            if subject is not None and subject.archetype is not None {
                name = storage_type(type(subject.archetype));
                counts[name] = counts.get(name, 0) + 1;
            }
        }
        return counts;
    }
    ids = [o.ensure_id() for o in origins];
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    cq = compile_query(
        q,
        upto,
        store,
        promotions=store?.promotions,
        count_only=True,
        acl_root=acl_root,
        acl_residual=residual,
        group_by=per
    );
    if cq.residual {
        raise ValueError('per-type counts need predicates the store can evaluate');
    }
    cq.params['origin'] = [str(i) for i in ids];
    for r in store.rows(cq.sql, cq.params) {
        counts[str(r[0])] = counts.get(str(r[0]), 0) + int(r[1]);
    }
    if (upto - 1) in residual {
        rq = compile_query(
            _with_bound(q, None, 0),
            upto,
            store,
            promotions=store?.promotions,
            acl_root=acl_root,
            acl_residual=residual,
            residual_only=True
        );
        rq.params['origin'] = [str(i) for i in ids];
        rows = [
            r
            for r in store.rows(rq.sql, rq.params)
            if r[0] is not None
        ];
        found = mem.batch_get(_unique_nodes([(UUID(str(r[0])), None) for r in rows]));
        seen: set = set();
        for r in rows {
            a = found.get(UUID(str(r[0])));
            if a is None
                or not a.is_populated()
                or a.archetype is None
                or not acl_read_ok(a) {
                continue;
            }
            key = r[1] if per == 'edge' else r[0];
            if key is None or key in seen {
                continue;
            }
            seen.add(key);
            name = str(r[5] if per == 'edge' else r[3]);
            counts[name] = counts.get(name, 0) + 1;
        }
    }
    return counts;
}


impl _bound_pushable -> bool {
    return not access_gated();
}


impl _hop_by_origin(
    store: any, cq: any, origins: list[UUID]
) -> dict[UUID, list[tuple[(UUID | None), (UUID | None)]]] {
    by_origin: dict[UUID, list[tuple[(UUID | None), (UUID | None)]]] = {
        o: [] for o in origins
    };
    params = dict(cq.params);
    params['origin'] = [str(o) for o in origins];
    for r in store.rows(cq.sql, params) {
        nid = UUID(str(r[0])) if r[0] is not None else None;
        eid = UUID(str(r[1])) if r[1] is not None else None;
        by_origin[UUID(str(r[2]))].append((nid, eid));
    }
    return by_origin;
}


impl _param_key(params: dict[str, any]) -> tuple[tuple[str, str], ...] {
    return tuple(
        sorted(
            (k, repr(v))
            for (k, v) in params.items()
            if k != 'origin'
        )
    );
}


impl _tail_ok(anchor: Anchor, tail: list[QPred]) -> bool {
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


impl _resolve_pairs(
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


impl _materialize_ids(
    mem: Session, ids: list[any], local: dict[any, Anchor]
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


impl _unique_nodes(pairs: list[tuple[any, any]]) -> list[any] {
    seen: set = set();
    out: list[any] = [];
    for (nid, _) in pairs {
        if nid is not None and nid not in seen {
            seen.add(nid);
            out.append(nid);
        }
    }
    return out;
}


impl _acl_fully_pushed(mem: Session, q: GraphQuery) -> bool {
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


impl _pushed_bound(mem: Session, q: GraphQuery) -> bool {
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


impl _resolve_for(mem: Session, q: GraphQuery) -> list[Anchor] {
    return resolve_query_edges(mem, q) if q.edges_only else resolve_query(mem, q);
}
