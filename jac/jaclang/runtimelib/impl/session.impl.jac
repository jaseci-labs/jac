impl promotions_for(base_path: (str | None)) -> dict[str, list[str]] {
    if not base_path {
        return {};
    }
    manifest = os.path.join(base_path, 'jac.toml');
    if not os.path.isfile(manifest) {
        return {};
    }
    try {
        import tomllib;
        with open(manifest, 'rb') as f {
            data = tomllib.load(f);
        }
        raw = (data.get('database') or {}).get('indexes') or {};
        out: dict[str, list[str]] = {};
        for (arch, fields_l) in raw.items() {
            if isinstance(fields_l, list) {
                out[str(arch)] = [str(x) for x in fields_l];
            }
        }
        return out;
    } except Exception as e {
        logger.warning(f"could not read [database.indexes] from {manifest}: {e}");
        return {};
    }
}


impl conninfo_from_url(url: str) -> ConnInfo {
    import from urllib.parse { urlparse, unquote }
    parsed = urlparse(url);
    return ConnInfo(
        host=(parsed.hostname or '127.0.0.1'),
        port=(parsed.port or 5432),
        user=unquote(parsed.username or 'jac'),
        password=unquote(parsed.password or ''),
        database=(parsed.path or '/jac').lstrip('/') or 'jac'
    );
}


impl shared_pg_data_dir -> str {
    import from jaclang.runtimelib.pgembed { dist_cache_dir }
    return os.path.join(os.path.dirname(dist_cache_dir()), 'main');
}


impl project_db_name(base_path: str, target_path: (str | None)) -> str {
    import hashlib;
    import from jaclang.runtimelib.utils { get_name }
    name = get_name(target_path=target_path) or 'main';
    safe = ''.join((ch if (ch.isalnum() or ch == '_') else '_') for ch in name.lower());
    digest = hashlib.sha1(os.path.abspath(base_path).encode('utf-8')).hexdigest()[:8];
    return f"jac_{safe[:40]}_{digest}";
}


impl takeover_project(base_path: str, target_path: (str | None) = None) -> int {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        store = PgStore(conninfo=conninfo_from_url(url));
    } else {
        rt = PgRuntime(
            data_dir=shared_pg_data_dir(),
            database=project_db_name(base_path, target_path)
        );
        store = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
    }
    try {
        return store.takeover();
    } finally {
        store.close();
    }
}


def _ancestry_of(arch: (object | None)) -> list[str] {
    import from jaclang.jac0core.constructs {
        Archetype,
        NodeArchetype,
        EdgeArchetype,
        WalkerArchetype
    }
    if arch is None {
        return [];
    }
    stops = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    out: list[str] = [];
    for c in type(arch).__mro__ {
        if c in stops {
            break;
        }
        out.append(c.__name__);
    }
    return out;
}


def _is_serialization_conflict(e: Exception) -> bool {
    seen = 0;
    cur: (BaseException | None) = e;
    while cur is not None and seen < 8 {
        c: BaseException = cur;
        for arg in getattr(c, 'args', ()) {
            if isinstance(arg, dict)
                and arg.get('C') in ('40001', '40P01', '55P03', '08006') {
                return True;
            }
        }
        cur = c.__cause__ or c.__context__;
        seen += 1;
    }
    return False;
}


glob _schema_ready: set[str] = set();


def _store_ns(store: (Any | None)) -> str {
    if isinstance(store, PgStore) {
        info = store.conninfo;
        return (f"{info.unix_socket_dir or info.host}:" f"{info.port}/{info.database}");
    }
    return '';
}


def _json_default(o: object) -> str {
    return str(o);
}


def _persist_hash(anchor: Anchor) -> int {
    import from json { dumps }
    import from jaclang.runtimelib.serializer { Serializer }
    try {
        data = Serializer.serialize(anchor, include_type=True);
        if isinstance(data, dict) {
            data.pop('edges', None);
        }
        return hash(dumps(data, sort_keys=True));
    } except Exception {
        return 0;
    }
}


impl Session.postinit -> None {
    import threading;
    self._lock = threading.RLock();
    self._fetch_count = 0;
    self.__mem__ = {};
    self._dirty = {};
    self._deleted = set();
    self._flushed_hash = {};
    self._on_commit = [];
    self._txn_changed = set();
    self._runtime = None;
    self._active_units = 0;
    if self.store is None and self.base_path {
        url = os.environ.get('JAC_DB_URL', '');
        promos = promotions_for(self.base_path);
        if url {
            pgs = PgStore(conninfo=conninfo_from_url(url));
        } else {
            rt = PgRuntime(
                data_dir=shared_pg_data_dir(),
                database=project_db_name(self.base_path, self.target_path)
            );
            self._runtime = rt;
            pgs = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
        }
        ns = _store_ns(pgs);
        if ns not in _schema_ready {
            pgs.ensure_schema(promos);
            _schema_ready.add(ns);
        }
        self.store = pgs;
    }
}


impl Session.data_location -> (str | None) {
    rt: Any = self._runtime;
    if rt is not None {
        return f"{rt.data_dir}/{rt.database}";
    }
    if isinstance(self.store, PgStore) {
        info = self.store.conninfo;
        return info.unix_socket_dir or f"{info.host}:{info.port}/{info.database}";
    }
    return None;
}


impl Session.is_available -> bool {
    return True;
}


impl Session.get(id: UUID) -> (Anchor | None) {
    if id in self._deleted {
        return None;
    }
    if (hit := self.__mem__.get(id)) is not None {
        return hit;
    }
    if self.store is None {
        return None;
    }
    return self.batch_get([id]).get(id);
}


impl Session.put(anchor: Anchor) -> None {
    with self._lock {
        self.__mem__[anchor.id] = anchor;
        self._dirty[anchor.id] = None;
        self._deleted.discard(anchor.id);
    }
}


impl Session.mark_dirty(anchor: Anchor) -> None {
    if anchor.id in self.__mem__ {
        self._dirty[anchor.id] = None;
    }
}


impl Session.delete(id: UUID) -> None {
    with self._lock {
        self.__mem__.pop(id, None);
        self._dirty.pop(id, None);
        self._flushed_hash.pop(id, None);
        self._deleted.add(id);
    }
}


impl Session.`has(id: UUID) -> bool {
    if id in self._deleted {
        return False;
    }
    if id in self.__mem__ {
        return True;
    }
    if self.store is None {
        return False;
    }
    try {
        self.read_barrier();
        return id in self.store.existing([id]);
    } except Exception as e {
        if not _is_serialization_conflict(e) {
            raise;
        }
        self._recover_conflict();
        self.read_barrier();
        return id in self.store.existing([id]);
    }
}


impl Session.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    for anchor in list(self.__mem__.values()) {
        if filter is None or filter(anchor) {
            yield anchor;
        }
    }
}


impl Session.get_roots -> Generator[Root, None, None] {
    seen: set[UUID] = set();
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.id);
            yield anchor.archetype;
        }
    }
    if self.store is not None {
        self.read_barrier();
        remote = [
            i
            for i in self.store.root_ids()
            if i not in seen and i not in self._deleted
        ];
        root_rows = self.store.load_full(remote);
        for (rid, row) in root_rows.items() {
            anchor = self._materialize(row, edge_ids=row.adjacency);
            if anchor is not None and isinstance(anchor.archetype, Root) {
                yield anchor.archetype;
            }
        }
    }
}


impl Session.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}


impl Session.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    return next(self.find(ids, filter), None);
}


impl Session.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    out: dict[UUID, Anchor] = {};
    missing: list[UUID] = [];
    for i in ids {
        if i in self._deleted {
            continue;
        }
        if (hit := self.__mem__.get(i)) is not None {
            out[i] = hit;
        } else {
            missing.append(i);
        }
    }
    if missing and self.store is not None {
        for attempt in range(2) {
            try {
                self.read_barrier();
                loaded = self.store.load_full(missing);
                for (rid, row) in loaded.items() {
                    anchor = self._materialize(row, edge_ids=row.adjacency);
                    if anchor is not None {
                        self._fetch_count += 1;
                        out[rid] = anchor;
                    }
                }
                break;
            } except Exception as e {
                if attempt == 1 or not _is_serialization_conflict(e) {
                    raise;
                }
                self._recover_conflict();
            }
        }
    }
    return out;
}


impl Session.commit(anchor: (Anchor | None) = None) -> None {
    with self._lock {
        if self.store is not None {
            attempt = 0;
            while True {
                try {
                    self.flush(full=True);
                    self.store.commit();
                    break;
                } except Exception as e {
                    if not _is_serialization_conflict(e) or attempt >= MAX_RETRIES {
                        raise;
                    }
                    attempt += 1;
                    self._recover_conflict();
                }
            }
            self._txn_changed.clear();
        } else {
            self._dirty.clear();
            self._deleted.clear();
        }
    }
    self._fire_on_commit();
}


impl Session.abort -> None {
    if self.store is not None {
        self.store.rollback();
    }
    self._evict_uncommitted();
    self._dirty.clear();
    self._deleted.clear();
    self._on_commit = [];
}


impl Session._evict_uncommitted -> None {
    import from jaclang.runtimelib.serializer { Serializer }
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        known = self._flushed_hash.get(id);
        dirty = known is None;
        if not dirty {
            try {
                dirty = Serializer._compute_hash(anchor) != known;
            } except Exception {
                dirty = True;
            }
        }
        if dirty {
            if isinstance(anchor, EdgeAnchor) {
                import from jaclang.jac0core.osp_graph_sv { sv_forget_edge }
                sv_forget_edge(anchor, self);
            }
            self.__mem__.pop(id, None);
            self._flushed_hash.pop(id, None);
        }
    }
}


impl Session.get_mem -> dict[UUID, Anchor] {
    return self.__mem__;
}


impl Session.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None {
    import from jaclang.jac0core.osp_graph_sv { sv_forget_by_id }
    sv_forget_by_id(stub.id, self);
    if self.store is not None {
        try {
            self.store.quarantine(
                stub.id, referrer.id if referrer else None, type(stub).__name__
            );
        } except Exception as e {
            logger.debug(f"quarantine record failed: {e}");
        }
    }
}


impl Session.is_recoverable_quarantine(id: UUID) -> bool {
    return False;
}


impl Session.aget(id: UUID) -> (Anchor | None) {
    return self.get(id);
}


impl Session.aput(anchor: Anchor) -> None {
    self.put(anchor);
}


impl Session.adelete(id: UUID) -> None {
    self.delete(id);
}


impl Session.ahas(id: UUID) -> bool {
    return self.`has(id);
}


impl Session.acommit(anchor: (Anchor | None) = None) -> None {
    self.commit(anchor);
}


impl Session.on_commit(callback: Callable) -> None {
    self._on_commit.append(callback);
}


impl Session._fire_on_commit -> None {
    fired = self._on_commit;
    self._on_commit = [];
    for cb in fired {
        try {
            cb();
        } except Exception as e {
            logger.warning(f"on_commit callback failed: {type(e).__name__}: {e}");
        }
    }
}


impl Session._ensure_txn -> None {
    with self._lock {
        if self.store is not None and not self.store.in_txn() {
            self.store.begin(serializable=True);
        }
    }
}


impl Session.unit_enter -> None {
    with self._lock {
        self._active_units += 1;
    }
}


impl Session.unit_exit -> None {
    with self._lock {
        self._active_units = max(0, self._active_units - 1);
        if self._active_units > 0 {
            return;
        }
        if self.store is None or not self.store.in_txn() {
            return;
        }
        try {
            self.commit();
        } except Exception as e {
            logger.warning(
                f"unit close commit failed; rolling back: {type(e).__name__}: {e}"
            );
            try {
                self.store.rollback();
            } except Exception { }
        }
    }
}


impl Session.reset_fetch_count -> None {
    self._fetch_count = 0;
}


impl Session.get_fetch_count -> int {
    return self._fetch_count;
}


impl Session._recover_conflict -> None {
    if self.store is not None {
        try {
            self.store.rollback();
        } except Exception { }
    }
    for id in list(self._txn_changed) {
        if id in self.__mem__ {
            self._flushed_hash.pop(id, None);
            self._dirty[id] = None;
        } else {
            self._deleted.add(id);
        }
    }
}


impl Session.read_barrier -> None {
    if self.store is None {
        return;
    }
    try {
        self._ensure_txn();
        self.flush();
    } except Exception as e {
        if not _is_serialization_conflict(e) {
            raise;
        }
        self._recover_conflict();
        self._ensure_txn();
        self.flush();
    }
}


impl Session.flush(full: bool = False) -> None {
    import from jaclang.runtimelib.serializer { Serializer }
    if self.store is None {
        return;
    }
    with self._lock {
        self._ensure_txn();
        candidates: list[UUID];
        if full {
            candidates = list(self.__mem__.keys());
        } else {
            candidates = list(self._dirty.keys());
        }
        rows: list[AnchorRow] = [];
        pending: list[tuple[Anchor, int]] = [];
        for id in candidates {
            anchor = self.__mem__.get(id);
            if anchor is None or not anchor.persistent or not anchor.is_populated() {
                continue;
            }
            h = _persist_hash(anchor);
            if h != 0 and self._flushed_hash.get(id) == h and id not in self._dirty {
                continue;
            }

            import from jaclang { JacRuntimeInterface as JacRI }
            if not JacRI.check_write_access(anchor, op_hint="field_write") {
                continue;
            }
            rows.append(self._serialize(anchor));
            pending.append((anchor, h));
        }
        if rows {
            self.store.upsert(rows);
            for (anchor, h) in pending {
                self._flushed_hash[anchor.id] = h;
                anchor.hash = h;
                self._txn_changed.add(anchor.id);
            }
        }
        if self._deleted {
            self.store.delete(list(self._deleted));
            for id in self._deleted {
                self._flushed_hash.pop(id, None);
                self._txn_changed.add(id);
            }
            self._deleted.clear();
        }
        self._dirty.clear();
    }
}


impl Session._serialize(anchor: Anchor) -> AnchorRow {
    import from jaclang.runtimelib.serializer { Serializer }
    props = Serializer.serialize(anchor, include_type=True);
    arch = anchor.archetype;
    arch_type = '';
    arch_module = '';
    fingerprint = '';
    if anchor.is_populated() and arch is not None {
        arch_type = type(arch).__name__;
        arch_module = type(arch).__module__;
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) else '';
    }
    src: (UUID | None) = None;
    dst: (UUID | None) = None;
    undirected = False;
    if isinstance(anchor, EdgeAnchor) {
        src = anchor.source.id if anchor.source is not None else None;
        dst = anchor.target.id if anchor.target is not None else None;
        undirected = anchor.is_undirected;
    }
    return AnchorRow(
        id=anchor.id,
        kind=type(anchor).__name__,
        arch_type=arch_type,
        arch_module=arch_module,
        fingerprint=fingerprint,
        root_id=anchor.root,
        props=props if isinstance(props, dict) else {},
        src=src,
        dst=dst,
        undirected=undirected,
        ancestry=_ancestry_of(arch)
    );
}


impl Session._materialize(
    row: AnchorRow, edge_ids: (list[UUID] | None) = None
) -> (Anchor | None) {
    import from jaclang.runtimelib.serializer { Serializer }
    existing = self.__mem__.get(row.id);
    if existing is not None and existing.is_populated() {
        return existing;
    }
    got = Serializer.deserialize(row.props);
    if not isinstance(got, Anchor) {
        logger.warning(
            f"could not materialize anchor {row.id} ({row.arch_type}); skipping"
        );
        if self.store is not None {
            try {
                self.store.quarantine(row.id, None, row.kind);
            } except Exception as e {
                logger.debug(f"quarantine record failed: {e}");
            }
        }
        return None;
    }
    anchor: Anchor = got;
    if isinstance(anchor, NodeAnchor) and self.store is not None {
        adj = edge_ids if edge_ids is not None else [];
        live = [
            i
            for i in adj
            if i not in self._deleted
        ];
        edges = [];
        for eid in live {
            if (stub := Serializer._id_to_stub(EdgeAnchor, str(eid))) is not None
                and isinstance(stub, EdgeAnchor) {
                edges.append(stub);
            }
        }
        anchor.edges = edges;
    }
    self.__mem__[row.id] = anchor;
    self._flushed_hash[row.id] = _persist_hash(anchor);
    anchor.hash = self._flushed_hash[row.id];
    return anchor;
}


impl Session.run_request(body: Callable) -> Any {
    attempt = 0;
    while True {
        try {
            self._ensure_txn();
            result = body();
            self.commit();
            return result;
        } except Exception as e {
            if (
                self.store is not None
                and _is_serialization_conflict(e)
                and attempt < MAX_RETRIES
            ) {
                attempt += 1;
                logger.info(
                    f"serialization conflict; re-running request "
                    f"(attempt {attempt}/{MAX_RETRIES})"
                );
                self.abort();
                continue;
            }
            self.abort();
            raise;
        }
    }
}


impl Session.close -> None {
    try {
        self.commit();
    } except Exception as e {
        logger.warning(f"commit on close failed: {type(e).__name__}: {e}");
    }
    if self.store is not None {
        self.store.close();
    }
    self.__mem__.clear();
    self._dirty.clear();
    self._deleted.clear();
    self._flushed_hash.clear();
    import from jaclang.jac0core.osp_graph_sv { sv_store_closed }
    sv_store_closed(self);
}
