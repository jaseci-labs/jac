def _effective_bound(q: GraphQuery) -> (tuple[(int | None), int] | None);


def _acl_pushdown_root(q: GraphQuery, upto: int) -> (str | None);


def _bound_pushable -> bool;


def _trusted_names(
    base: type, nd: (type | tuple[type, ...] | None), store: any
) -> (list[str] | None);


def _edge_residual(hop: QHop, store: any) -> (list[str] | None);


def _staged(mem: Session, q: GraphQuery) -> GraphQuery;


def _acl_residual(q: GraphQuery, upto: int, store: any) -> dict[int, list[str]];


def _scan(
    mem: Session,
    q: GraphQuery,
    unique: str,
    lookahead: bool,
    budget: (int | None) = None
) -> tuple[
    list[tuple[Anchor, (Anchor | None), (tuple[int, (UUID | None)] | None)]],
    (tuple[int, (UUID | None)] | None)
];


def _split_tail(cq: CompiledQuery, upto: int, edges: bool = False) -> list[QPred];


def _with_bound(q: GraphQuery, limit: (int | None), offset: int) -> GraphQuery;


def _with_edges(q: GraphQuery) -> GraphQuery;


impl _sql_pairs(
    mem: Session, origin_ids: list[UUID], q: GraphQuery, upto: int
) -> tuple[list[tuple[(UUID | None), (UUID | None)]], list[QPred], list[QPred]] {
    store = mem.store;
    if store is None or not origin_ids {
        return ([], [], []);
    }
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    bound = _effective_bound(q);
    push = bound is not None
        and not q.edges_only
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
    etail = _split_tail(cq, upto, True);
    if upto > 0
        and len(origin_ids) == 1
        and eff.limit is None
        and not eff.offset
        and mem.batching() {
        key = (cq.sql, _param_key(cq.params));
        hit = mem.hop_cached(key, origin_ids[0]);
        if hit is not None {
            return (hit, tail, etail);
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
            return (by_origin.get(origin_ids[0], []), tail, etail);
        }
    }
    cq.params['origin'] = [str(i) for i in origin_ids];
    out: list[tuple[(UUID | None), (UUID | None)]] = [];
    for r in store.rows(cq.sql, cq.params) {
        nid = UUID(str(r[0])) if r[0] is not None else None;
        eid = UUID(str(r[1])) if r[1] is not None else None;
        out.append((nid, eid));
    }
    return (out, tail, etail);
}


def _hop_by_origin(
    store: any, cq: any, origins: list[UUID]
) -> dict[UUID, list[tuple[(UUID | None), (UUID | None)]]];


def _param_key(params: dict[str, any]) -> tuple[tuple[str, str], ...];


def _tail_ok(anchor: Anchor, tail: list[QPred]) -> bool;


def _resolve_pairs(
    mem: Session, q: GraphQuery, upto: int
) -> tuple[list[tuple[any, any]], dict[any, Anchor], list[QPred], list[QPred]];


def _materialize_ids(
    mem: Session, ids: list[any], local: dict[any, Anchor]
) -> list[Anchor];


def _unique_nodes(pairs: list[tuple[any, any]]) -> list[any];


impl resolve_query_prefix(mem: Session, q: GraphQuery, upto: int) -> list[UUID] {
    (pairs, _local, _tail, _etail) = _resolve_pairs(mem, q, upto);
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
    gated = access_gated();
    q = _staged(mem, q);
    if not q.origin {
        return [];
    }
    origins = origin_anchors(q);
    if not needs_store(mem, origins) {
        return walk_nodes(origins, q, gated);
    }
    if q.hops
        and _effective_bound(q) is not None
        and all(o.persistent for o in origins)
        and (not gated or _acl_fully_pushed(mem, q)) {
        page = [n for (n, _, _) in _scan(mem, q, 'node', False)[0]];
        mem.note_siblings([n.ensure_id() for n in page]);
        return page;
    }
    (pairs, local, tail, etail) = _resolve_pairs(mem, q, len(q.hops));
    if etail {
        reaching = _materialize_ids(
            mem,
            _unique_nodes(
                [
                    (e, None)
                    for (_, e) in pairs
                    if e is not None
                ]
            ),
            local
        );
        passing = {
            anchor_key(ea)
            for ea in reaching
            if _tail_ok(ea, etail)
        };
        pairs = [
            (n, e)
            for (n, e) in pairs
            if e is not None and e in passing
        ];
    }
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
    if gated
        and (
            not _acl_fully_pushed(mem, q)
            or (len(q.hops) - 1) in _acl_residual(q, len(q.hops), mem.store)
        ) {
        out = [
            a
            for a in out
            if acl_read_ok(a)
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
    q = _staged(mem, q);
    if not q.origin {
        return [];
    }
    origins = origin_anchors(q);
    gated = access_gated();
    if not needs_store(mem, origins) {
        return walk_edges(origins, q, gated);
    }
    bound = _effective_bound(q);
    if q.from_visit {
        bound = None if q.limit is None else (q.limit, q.offset);
    }
    if bound is not None
        and all(o.persistent for o in origins)
        and (not gated or _acl_fully_pushed(mem, q)) {
        scanned: list[Anchor] = [];
        reached: set = set();
        for (a, e, _) in _scan(mem, q, 'edge', False)[0] {
            if e is None {
                continue;
            }
            scanned.append(e);
            if q.from_visit and anchor_key(a) not in reached {
                reached.add(anchor_key(a));
                scanned.append(a);
            }
        }
        if q.from_visit and q.slc is not None {
            scanned = scanned[q.slc];
        }
        return scanned;
    }
    (pairs, local, tail, etail) = _resolve_pairs(mem, q, len(q.hops));
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
    if etail {
        edges = [
            ea
            for ea in edges
            if _tail_ok(ea, etail)
        ];
    }
    if tail {
        kept_tail: list[Anchor] = [];
        for ea in edges {
            nid = node_of.get(anchor_key(ea));
            ends = _materialize_ids(mem, [nid], local) if nid is not None else [];
            if ends and _tail_ok(ends[0], tail) {
                kept_tail.append(ea);
            }
        }
        edges = kept_tail;
    }
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
    if bound is not None {
        stop = None if bound[0] is None else bound[1] + bound[0];
        edges = edges[bound[1]:stop];
    }
    if not q.from_visit {
        out_e: list[Anchor] = list(edges);
        if q.slc is not None and bound is None {
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
    bound = _effective_bound(q);
    q = _staged(mem, q);
    origins = origin_anchors(q);
    gated = access_gated();
    if store is None
        or not needs_store(mem, origins)
        or q.from_visit
        or (q.slc is not None and bound is None)
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
        _with_bound(q, None, 0),
        upto,
        store,
        promotions=store?.promotions,
        count_only=True,
        acl_root=acl_root,
        acl_residual=residual
    );
    if cq.residual or cq.eresidual {
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
    if bound is not None {
        total = max(0, total - bound[1]);
        if bound[0] is not None {
            total = min(total, bound[0]);
        }
    }
    return total;
}


def _resolve_for(mem: Session, q: GraphQuery) -> list[Anchor];


impl resolve_query_exists(mem: Session, q: GraphQuery) -> bool {
    return bool(_resolve_for(mem, _with_bound(q, 1, 0)));
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
    return self._resolve(_with_bound(self._query, limit, offset));
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


impl _trusted_names(
    base: type, nd: (type | tuple[type, ...] | None), store: any
) -> (list[str] | None) {
    base_access = Archetype?.__jac_access__;
    trusted: set = set();
    pending: list[type] = [base];
    seen: set = set();
    while pending {
        cls = pending.pop();
        if cls in seen {
            continue;
        }
        seen.add(cls);
        pending.extend(cls.__subclasses__());
        if issubclass(cls, Root) or cls?.__jac_access__ is not base_access {
            continue;
        }
        tname = storage_type(cls);
        if tname {
            trusted.add(tname);
        }
    }
    wanted = [] if nd is None else (list(nd) if isinstance(nd, tuple) else [nd]);
    stored: (set | None) = None;
    for t in wanted {
        if not isinstance(t, type) {
            continue;
        }
        tname = storage_type(t);
        names = set([tname] + list(store.subtype_names(tname)));
        stored = names if stored is None else stored & names;
    }
    if stored is None {
        return sorted(trusted);
    }
    if stored <= trusted {
        return None;
    }
    return sorted(stored & trusted);
}


impl _acl_residual(q: GraphQuery, upto: int, store: any) -> dict[int, list[str]] {
    out: dict[int, list[str]] = {};
    for (i, hop) in enumerate(q.hops[:upto]) {
        trusted = _trusted_names(NodeArchetype, hop.nd, store);
        if trusted is not None {
            out[i] = trusted;
        }
    }
    return out;
}


impl _edge_residual(hop: QHop, store: any) -> (list[str] | None) {
    return _trusted_names(EdgeArchetype, hop.`edge, store);
}


impl _staged(mem: Session, q: GraphQuery) -> GraphQuery {
    if mem.store is None
        or len(q.hops) < 2
        or _acl_pushdown_root(q, len(q.hops)) is None {
        return q;
    }
    hops = list(q.hops);
    middle = sorted(_acl_residual(q, len(q.hops) - 1, mem.store).keys());
    changed = False;
    for k in middle {
        hop = hops[k];
        if hop.only is not None and all(acl_read_ok(a) for a in hop.only_anchors()) {
            continue;
        }
        reached = resolve_query(mem, GraphQuery(q.origin, hops=hops[:k + 1]));
        hops[k] = QHop(
            dir=hop.dir,
            `edge=hop.`edge,
            nd=hop.nd,
            epreds=hop.epreds,
            preds=hop.preds,
            only=[a.archetype for a in reached]
        );
        changed = True;
    }
    if not changed {
        return q;
    }
    staged = _with_bound(q, q.limit, q.offset);
    staged.slc = q.slc;
    staged.hops = hops;
    return staged;
}


impl _split_tail(cq: CompiledQuery, upto: int, edges: bool = False) -> list[QPred] {
    held = cq.eresidual if edges else cq.residual;
    if not held {
        return [];
    }
    last = upto - 1;
    early = sorted(
        [
            h
            for h in held.keys()
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
    return list(held.get(last) or []);
}


impl _with_edges(q: GraphQuery) -> GraphQuery {
    eff = _with_bound(q, None, 0);
    eff.edges_only = True;
    return eff;
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
    mem: Session,
    q: GraphQuery,
    unique: str,
    lookahead: bool,
    budget: (int | None) = None
) -> tuple[
    list[tuple[Anchor, (Anchor | None), (tuple[int, (UUID | None)] | None)]],
    (tuple[int, (UUID | None)] | None)
] {
    store = mem.store;
    upto = len(q.hops);
    origins = origin_anchors(q);
    if store is None {
        return ([], None);
    }
    ids = [o.ensure_id() for o in origins];
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    distinct = unique == 'node';
    edge_acl = acl_root is not None and not distinct;
    eres = _edge_residual(q.hops[upto - 1], store) if edge_acl else None;
    promos = store?.promotions;
    probe = compile_query(
        q,
        upto,
        store,
        promotions=promos,
        acl_root=acl_root,
        acl_residual=residual,
        edge_residual=eres,
        edge_acl=edge_acl
    );
    tail = _split_tail(probe, upto);
    etail = _split_tail(probe, upto, True);
    want_edges = not distinct or bool(etail);
    (limit, offset) = _effective_bound(q) or (None, 0);
    if limit == 0 {
        return ([], None);
    }
    node_trust = residual.get(upto - 1);
    node_known = set(node_trust or []);
    edge_known = set(eres or []);
    exact = not tail
        and not etail
        and node_trust is None
        and eres is None
        and unique == 'row';

    def node_unknown(r: tuple[any, ...]) -> bool {
        return node_trust is not None and str(r[3]) not in node_known;
    }

    def edge_unknown(r: tuple[any, ...]) -> bool {
        return eres is not None and str(r[5]) not in edge_known;
    }
    skip_left = 0 if exact else offset;
    raw_off = offset if exact else 0;
    out: list[tuple[Anchor, (Anchor | None), (tuple[int, (UUID | None)] | None)]] = [];
    seen: set = set();
    nodes: dict[UUID, Anchor] = {};
    edges: dict[UUID, Anchor] = {};
    probing = False;
    more = False;
    examined = 0;
    resume: (tuple[int, (UUID | None)] | None) = None;
    held: list[UUID] = [];

    def checked(r: tuple[any, ...]) -> bool {
        return bool(tail) or bool(etail) or node_unknown(r) or edge_unknown(r);
    }

    def load(rows: list[tuple[any, ...]], start: int) {
        room = None if limit is None else limit - len(out);
        stop = len(rows) if budget is None else start + max(0, budget - examined) + 1;
        want_n: list[UUID] = [];
        want_e: list[UUID] = [];
        for r in rows[start:stop] {
            if r[0] is None {
                continue;
            }
            keep = not probing and skip_left == 0 and (room is None or room > 0);
            if not (keep or checked(r)) {
                continue;
            }
            if keep and room is not None {
                room -= 1;
            }
            nid = UUID(str(r[0]));
            if nid not in nodes {
                want_n.append(nid);
            }
            if want_edges
                and r[1] is not None
                and (
                    (keep and not node_unknown(r)) or edge_unknown(r) or bool(etail)
                ) {
                eid = UUID(str(r[1]));
                if eid not in edges {
                    want_e.append(eid);
                }
            }
        }
        if want_n {
            nodes.update(mem.batch_get(want_n));
        }
        if want_e {
            edges.update(mem.batch_get(want_e));
        }
    }

    while True {
        need = 0 if probing else (None if limit is None else limit - len(out));
        chunk = None if need is None else need + skip_left + (1 if lookahead else 0);
        if probing {
            chunk = limit;
        }
        cq = compile_query(
            _with_bound(q, chunk, raw_off),
            upto,
            store,
            promotions=promos,
            acl_root=acl_root,
            acl_residual=residual,
            edge_residual=eres,
            edge_acl=edge_acl
        );
        cq.params['origin'] = [str(i) for i in ids];
        rows = store.rows(cq.sql, cq.params);
        done = False;
        for (idx, r) in enumerate(rows) {
            for gone in held {
                nodes.pop(gone, None);
                edges.pop(gone, None);
            }
            held = [];
            if budget is not None and examined >= budget {
                more = True;
                done = True;
                break;
            }
            examined += 1;
            raw_off += 1;
            if r[0] is None {
                continue;
            }
            nid = UUID(str(r[0]));
            eid = UUID(str(r[1])) if r[1] is not None else None;
            held = [nid] if eid is None else [nid, eid];
            if r[4] is not None {
                resume = (int(str(r[4])), eid);
            }
            mark = eid if unique == 'edge' else nid;
            if unique != 'row' and mark in seen {
                continue;
            }
            keep = not probing and skip_left == 0;
            a: any = None;
            ea: (Anchor | None) = None;
            if keep or checked(r) {
                if nid not in nodes {
                    load(rows, idx);
                }
                a = nodes.get(nid);
                if a is None or not a.is_populated() or a.archetype is None {
                    continue;
                }
                if tail and not _tail_ok(a, tail) {
                    continue;
                }
                if node_unknown(r) and not acl_read_ok(a) {
                    continue;
                }
                if want_edges and eid is not None {
                    if eid not in edges {
                        edges.update(mem.batch_get([eid]));
                    }
                    ea = edges.get(eid);
                    if ea is None or not ea.is_populated() or ea.archetype is None {
                        continue;
                    }
                    if etail and not _tail_ok(ea, etail) {
                        continue;
                    }
                    if edge_unknown(r) and not acl_read_ok(ea) {
                        continue;
                    }
                }
            }
            seen.add(mark);
            if probing {
                more = True;
                done = True;
                break;
            }
            if skip_left > 0 {
                skip_left -= 1;
                continue;
            }
            key = (int(str(r[4])), eid) if r[4] is not None else None;
            out.append((a, ea, key));
            if limit is not None and len(out) >= limit {
                if not lookahead {
                    done = True;
                    break;
                }
                probing = True;
            }
        }
        if done or chunk is None or len(rows) < chunk {
            break;
        }
    }
    if not more {
        return (out, None);
    }
    if out and (limit is None or len(out) >= limit or resume is None) {
        return (out, out[-1][2]);
    }
    return (out, resume);
}


impl resolve_query_page(
    mem: Session, q: GraphQuery
) -> tuple[
    list[tuple[Anchor, (Anchor | None), (tuple[int, (UUID | None)] | None)]],
    (tuple[int, (UUID | None)] | None)
] {
    origins = origin_anchors(q);
    if len(q.hops) != 1 or len(origins) != 1 or q.order or q.edges_only {
        raise ValueError('a page is one hop from one node in edge order');
    }
    if q.offset or (q.slc is not None and q.slc.start) {
        raise ValueError('a page resumes from a cursor, not an offset');
    }
    gated = access_gated();
    if needs_store(mem, origins) and origins[0].persistent {
        if not gated or _acl_fully_pushed(mem, q) {
            return _scan(
                mem,
                q,
                'row',
                True,
                max(PAGE_SCAN_FLOOR, PAGE_SCAN_FACTOR * (q.limit or 0))
            );
        }
    }
    limit = q.limit if q.limit is not None else (_effective_bound(q) or (None, 0))[0];
    pairs = [
        (a, e)
        for (a, e) in walk(origins, _with_edges(q), 1, gated)
        if not gated or e is None or acl_read_ok(e)
    ];
    start = int(q.after[0]) if q.after is not None else 0;
    stop = None if limit is None else start + limit;
    page: list[tuple[Anchor, (Anchor | None), (tuple[int, (UUID | None)] | None)]] = [];
    for (i, (a, e)) in enumerate(pairs[start:stop]) {
        page.append((a, e, (start + i + 1, None)));
    }
    nxt = (stop, None) if stop is not None and stop < len(pairs) else None;
    return (page, nxt);
}


impl resolve_query_type_counts(
    mem: Session, q: GraphQuery, per: str = 'node'
) -> tuple[dict[str, int], bool] {
    store = mem.store;
    q = _staged(mem, q);
    origins = origin_anchors(q);
    gated = access_gated();
    upto = len(q.hops);
    counts: dict[str, int] = {};
    if store is None
        or upto == 0
        or not needs_store(mem, origins)
        or not all(o.persistent for o in origins)
        or (gated and not _acl_fully_pushed(mem, q)) {
        counted: set = set();
        for (a, e) in walk(origins, _with_edges(q), upto, gated) {
            if gated and e is not None and not acl_read_ok(e) {
                continue;
            }
            subject = e if per == 'edge' else a;
            if subject is None or subject.archetype is None {
                continue;
            }
            key = anchor_key(subject);
            if key in counted {
                continue;
            }
            counted.add(key);
            name = storage_type(type(subject.archetype));
            counts[name] = counts.get(name, 0) + 1;
        }
        return (counts, True);
    }
    ids = [o.ensure_id() for o in origins];
    mem.read_barrier();
    acl_root = _acl_pushdown_root(q, upto);
    residual = _acl_residual(q, upto, store) if acl_root is not None else {};
    edge_acl = acl_root is not None;
    eres = _edge_residual(q.hops[upto - 1], store) if edge_acl else None;
    cq = compile_query(
        _with_bound(q, None, 0),
        upto,
        store,
        promotions=store?.promotions,
        count_only=True,
        acl_root=acl_root,
        acl_residual=residual,
        edge_residual=eres,
        edge_acl=edge_acl,
        group_by=per
    );
    if cq.residual or cq.eresidual {
        raise ValueError('per-type counts need predicates the store can evaluate');
    }
    cq.params['origin'] = [str(i) for i in ids];
    for r in store.rows(cq.sql, cq.params) {
        counts[str(r[0])] = counts.get(str(r[0]), 0) + int(r[1]);
    }
    node_trust = residual.get(upto - 1);
    if node_trust is None and eres is None {
        return (counts, True);
    }
    rq = compile_query(
        _with_bound(q, COUNT_CHECK_CAP + 1, 0),
        upto,
        store,
        promotions=store?.promotions,
        acl_root=acl_root,
        acl_residual=residual,
        edge_residual=eres,
        edge_acl=edge_acl,
        residual_only=True
    );
    rq.params['origin'] = [str(i) for i in ids];
    rows = [
        r
        for r in store.rows(rq.sql, rq.params)
        if r[0] is not None and r[1] is not None
    ];
    exact = len(rows) <= COUNT_CHECK_CAP;
    rows = rows[:COUNT_CHECK_CAP];
    node_known = set(node_trust or []);
    edge_known = set(eres or []);

    def node_unknown(r: tuple[any, ...]) -> bool {
        return node_trust is not None and str(r[3]) not in node_known;
    }

    def edge_unknown(r: tuple[any, ...]) -> bool {
        return eres is not None and str(r[5]) not in edge_known;
    }
    wanted: list[tuple[any, any]] = [];
    for r in rows {
        if node_unknown(r) {
            wanted.append((UUID(str(r[0])), None));
        }
        if edge_unknown(r) {
            wanted.append((UUID(str(r[1])), None));
        }
    }
    found = mem.batch_get(_unique_nodes(wanted)) if wanted else {};

    unresolved: list[bool] = [];

    def readable(anchor_id: any, checked: bool) -> bool {
        if not checked {
            return True;
        }
        a = found.get(UUID(str(anchor_id)));
        if a is None or not a.is_populated() or a.archetype is None {
            unresolved.append(True);
            return False;
        }
        return acl_read_ok(a);
    }
    seen: dict[str, str] = {};
    for r in rows {
        if not readable(r[0], node_unknown(r)) or not readable(r[1], edge_unknown(r)) {
            continue;
        }
        key = str(r[1] if per == 'edge' else r[0]);
        if key not in seen {
            seen[key] = str(r[5] if per == 'edge' else r[3]);
        }
    }
    if per != 'edge' and seen {
        reached = mem.batch_get([UUID(k) for k in seen.keys()]);
        last = q.hops[upto - 1];
        narrowed = _with_bound(q, None, 0);
        narrowed.hops = q.hops[:upto - 1]
            + [
                QHop(
                    dir=last.dir,
                    `edge=last.`edge,
                    nd=last.nd,
                    epreds=last.epreds,
                    preds=last.preds,
                    only=[
                        a.archetype
                        for a in reached.values()
                        if a is not None
                    ]
                )
            ];
        dq = compile_query(
            narrowed,
            upto,
            store,
            promotions=store?.promotions,
            count_only=True,
            acl_root=acl_root,
            acl_residual=residual,
            edge_residual=eres,
            edge_acl=edge_acl,
            group_by='node_ids'
        );
        dq.params['origin'] = [str(i) for i in ids];
        for r in store.rows(dq.sql, dq.params) {
            seen.pop(str(r[0]), None);
        }
    }
    for name in seen.values() {
        counts[name] = counts.get(name, 0) + 1;
    }
    return (counts, exact and not unresolved);
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
) -> tuple[list[tuple[any, any]], dict[any, Anchor], list[QPred], list[QPred]] {
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
    (pairs, tail, etail) = _sql_pairs(mem, sql_ids, q, upto);
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
    return (pairs, local, tail, etail);
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
