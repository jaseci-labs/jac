def _toml_section(base_path: (str | None), section: str) -> dict {
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
        return data.get(section) or {};
    } except Exception as e {
        logger.warning(f"could not read [{section}] from {manifest}: {e}");
        return {};
    }
}


impl promotions_for(base_path: (str | None)) -> dict[str, list[str]] {
    raw = _toml_section(base_path, 'database').get('indexes') or {};
    out: dict[str, list[str]] = {};
    for (arch, fields_l) in raw.items() {
        if isinstance(fields_l, list) {
            out[str(arch)] = [str(x) for x in fields_l];
        }
    }
    return out;
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
    import from jaclang.data.pgembed { dist_cache_dir }
    return os.path.join(os.path.dirname(dist_cache_dir()), 'main');
}


impl project_db_name(base_path: str, target_path: (str | None)) -> str {
    import hashlib;
    import from jaclang.runtime.graph_utils { get_name }
    name = get_name(target_path=target_path) or 'main';
    safe = ''.join((ch if (ch.isalnum() or ch == '_') else '_') for ch in name.lower());
    digest = hashlib.sha1(os.path.realpath(base_path).encode('utf-8')).hexdigest()[:8];
    return f"jac_{safe[:40]}_{digest}";
}


glob _scratch_bases: set[str] = set(),
     _scratch: list[ScratchState] = [];


impl mark_scratch_base(base_path: str) -> None {
    _scratch_bases.add(os.path.abspath(base_path));
}


impl scratch_requested(base_path: (str | None)) -> bool {
    if os.environ.get(SCRATCH_ENV, '').strip().lower()
        not in ('', '0', 'false', 'no') {
        return True;
    }
    if not base_path {
        return False;
    }
    return os.path.abspath(base_path) in _scratch_bases;
}


impl scratch_lease(base_path: str) -> ScratchLease {
    import secrets;
    base = os.path.abspath(base_path);
    if not _scratch {
        import atexit;
        _scratch.append(
            ScratchState(
                database=f"{SCRATCH_PREFIX}{os.getpid()}_{secrets.token_hex(3)}",
                base_path=base,
                owner_pid=os.getpid()
            )
        );
        atexit.register(drop_scratch_database);
        return ScratchLease(database=_scratch[0].database);
    }
    state = _scratch[0];
    reset = state.base_path != base;
    state.base_path = base;
    return ScratchLease(database=state.database, reset=reset);
}


impl drop_scratch_database -> None {
    if not _scratch {
        return;
    }
    if _scratch[0].owner_pid != os.getpid() {
        _scratch.clear();
        return;
    }
    state = _scratch.pop();
    stop_heartbeat(state.database);
    try {
        rt = PgRuntime(data_dir=shared_pg_data_dir(), database=MAINTENANCE_DB);
        if rt.is_running() {
            rt.drop_database(state.database, force=True);
        }
    } except Exception as e {
        logger.debug(f"could not drop the scratch database {state.database}: {e}");
    }
}


impl retention_days_for(base_path: (str | None)) -> int {
    raw: str = os.environ.get(RETENTION_ENV, '').strip();
    if not raw {
        raw = str(_toml_section(base_path, 'database').get('retention_days') or '');
    }
    if not raw {
        return 0;
    }
    try {
        days = int(raw);
    } except ValueError {
        logger.warning(f"ignoring non-integer database retention setting {raw!r}");
        return 0;
    }
    return days if days > 0 else 0;
}


impl runtime_for_base(
    base_path: str, target_path: (str | None) = None
) -> RuntimeLease {
    lease: (ScratchLease | None) = None;
    if scratch_requested(base_path) {
        lease = scratch_lease(base_path);
    }
    return RuntimeLease(
        runtime=PgRuntime(
            data_dir=shared_pg_data_dir(),
            database=(
                lease.database
                    if lease is not None
                    else project_db_name(base_path, target_path)
            ),
            owner_path=os.path.abspath(base_path),
            kind=DbKind.SCRATCH if lease is not None else DbKind.PROJECT,
            retention_days=(0 if lease is not None else retention_days_for(base_path))
        ),
        reset=lease is not None and lease.reset
    );
}


impl takeover_project(base_path: str, target_path: (str | None) = None) -> int {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        store = PgStore(conninfo=conninfo_from_url(url));
    } else {
        rt = runtime_for_base(base_path, target_path).runtime;
        store = PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
    }
    try {
        return store.takeover();
    } finally {
        store.close();
    }
}


def _ancestry_of(arch: (object | None)) -> list[str] {
    import from jaclang.runtime.constructs {
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


def _json_default(o: object) -> str {
    return str(o);
}


def _persist_hash(anchor: Anchor) -> int {
    import from json { dumps }
    import from jaclang.data.serializer { Serializer }
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
    self._init_memory();
    self._fetch_count = 0;
    self._flushed_hash = {};
    self._txn_changed = set();
    self._runtime = None;
    self._active_units = 0;
    self._flushing = None;
    self._read_scopes = 0;
    self._ro_units = 0;
    self._unit_stack = [];
    self._snapshot_reads = set();
    self._version_seen = {};
    if self.store is None and self.base_path {
        url = os.environ.get('JAC_DB_URL', '');
        promos = promotions_for(self.base_path);
        if url {
            self.store = PgStore(
                conninfo=conninfo_from_url(url), promotions=promos, auto_schema=True
            );
        } else {
            lease = runtime_for_base(self.base_path, self.target_path);
            self._runtime = lease.runtime;
            pgs = PgStore(
                conninfo=lease.runtime.conninfo(),
                ensure_cb=lease.runtime.ensure,
                promotions=promos,
                auto_schema=True
            );
            if lease.reset {
                if lease.runtime.is_running() {
                    pgs.reset_data();
                } else {
                    pgs.pending_reset = True;
                }
            }
            self.store = pgs;
        }
    }
}


impl Session.data_location -> (str | None) {
    rt: any = self._runtime;
    if rt is not None {
        return f"{rt.data_dir}/{rt.database}";
    }
    if isinstance(self.store, PgStore) {
        info = self.store.conninfo;
        return info.unix_socket_dir or f"{info.host}:{info.port}/{info.database}";
    }
    return None;
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


impl Session.get_roots -> Generator[Root, None, None] {
    seen: set[UUID] = set();
    for anchor in list(self.__mem__.values()) {
        if isinstance(anchor.archetype, Root) {
            seen.add(anchor.ensure_id());
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
    self._drop_snapshot_reads();
    self._on_commit = [];
}


impl Session._evict_uncommitted -> None {
    import from jaclang.data.serializer { Serializer }
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
                import from jaclang.runtime.osp_graph_sv { sv_forget_edge }
                sv_forget_edge(anchor, self);
            }
            self.__mem__.pop(id, None);
            self._flushed_hash.pop(id, None);
        }
    }
}


impl Session.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None {
    import from jaclang.runtime.osp_graph_sv { sv_forget_by_id }
    sid = stub.ensure_id();
    sv_forget_by_id(sid, self);
    if self.store is not None {
        try {
            self.store.quarantine(
                sid, referrer.ensure_id() if referrer else None, type(stub).__name__
            );
        } except Exception as e {
            logger.debug(f"quarantine record failed: {e}");
        }
    }
}


impl Session._txn_isolation -> TxnIsolation {
    if self._dirty or self._deleted {
        return TxnIsolation.SERIALIZABLE;
    }
    if self._read_scopes > 0 and self._active_units == 0 {
        return TxnIsolation.SNAPSHOT_READ_ONLY;
    }
    if self._active_units > 0 and self._ro_units == self._active_units {
        return TxnIsolation.SNAPSHOT_READ_ONLY;
    }
    return TxnIsolation.SERIALIZABLE;
}


impl Session._register_ro_writers -> str {
    keys = [
        key
        for (key, ro) in self._unit_stack
        if ro and key is not None
    ];
    for key in keys {
        record_unit_writes(key);
    }
    self._ro_units = 0;
    self._unit_stack = [(key, False) for (key, _ro) in self._unit_stack];
    return keys[-1] if keys else '';
}


impl Session._raise_ro_retry -> None {
    import from uuid { UUID as _UUID }
    last = self._register_ro_writers();
    if self.store is not None {
        try {
            self.store.rollback();
        } except Exception {}
    }
    raise ReadOnlyRetry(anchor_id=_UUID(int=0), unit_key=last);
}


impl Session._drop_snapshot_reads -> None {
    import from jaclang.runtime.osp_graph_sv { sv_forget_edge }
    for id in self._snapshot_reads {
        if id in self._dirty or id in self._deleted {
            continue;
        }
        stale = self.__mem__.pop(id, None);
        self._flushed_hash.pop(id, None);
        if isinstance(stale, EdgeAnchor) {
            sv_forget_edge(stale, self);
        }
    }
    self._snapshot_reads.clear();
}


impl Session._ensure_txn -> None {
    with self._lock {
        if self.store is None {
            return;
        }
        wanted = self._txn_isolation();
        if not self.store.in_txn() {
            self.store.begin(wanted);
            return;
        }
        if wanted is TxnIsolation.SERIALIZABLE
            and self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
            if self._ro_units > 0 {
                self._raise_ro_retry();
            }
            self.store.commit();
            self._drop_snapshot_reads();
            self.store.begin(TxnIsolation.SERIALIZABLE);
        }
    }
}


impl Session.unit_enter(key: (str | None) = None) -> None {
    with self._lock {
        ro = key is not None and ro_units_enabled() and not unit_writes_recorded(key);
        self._active_units += 1;
        if ro {
            self._ro_units += 1;
        }
        self._unit_stack.append((key, ro));
        if self.store is not None and self.store.in_txn() {
            self._ensure_txn();
        }
    }
}


impl Session.read_scope_enter -> None {
    with self._lock {
        self._read_scopes += 1;
    }
}


impl Session.read_scope_exit -> None {
    with self._lock {
        self._read_scopes = max(0, self._read_scopes - 1);
        if self._read_scopes > 0 or self.store is None {
            return;
        }
        if self.store.txn_isolation() is not TxnIsolation.SNAPSHOT_READ_ONLY {
            return;
        }
        try {
            self.store.commit();
        } except Exception as e {
            logger.warning(
                f"read snapshot close failed; rolling back: {type(e).__name__}: {e}"
            );
            try {
                self.store.rollback();
            } except Exception {}
        }
        self._drop_snapshot_reads();
    }
}


impl Session.unit_exit -> None {
    with self._lock {
        self._active_units = max(0, self._active_units - 1);
        try {
            if self._active_units > 0 {
                return;
            }
            if self.store is None or not self.store.in_txn() {
                return;
            }
            try {
                self.commit();
            } except WriteConflict {
                try {
                    self.store.rollback();
                } except Exception {}
                raise;
            } except Exception as e {
                logger.warning(
                    f"unit close commit failed; rolling back: {type(e).__name__}: {e}"
                );
                try {
                    self.store.rollback();
                } except Exception {}
            }
        } finally {
            if self._unit_stack {
                (_key, was_ro) = self._unit_stack.pop();
                if was_ro {
                    self._ro_units = max(0, self._ro_units - 1);
                }
            }
        }
    }
}


impl Session.unit_depth -> int {
    return self._active_units;
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
        } except Exception {}
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
    import threading;
    import from jaclang.data.serializer { Serializer }
    if self.store is None {
        return;
    }
    with self._lock {
        if self._flushing == threading.get_ident() {
            return;
        }
        self._flushing = threading.get_ident();
        try {
            self._flush_locked(full);
        } finally {
            self._flushing = None;
        }
    }
}


impl Session._flush_locked(full: bool) -> None {
    if self.store is not None {
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
        if rows or self._deleted {
            if self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
                self.ensure_writable_txn();
            } else {
                self._ensure_txn();
            }
        }
        if rows {
            self.store.upsert(rows);
            for (i, (anchor, h)) in enumerate(pending) {
                aid = anchor.ensure_id();
                self._flushed_hash[aid] = h;
                anchor.hash = h;
                self._version_seen[aid] = rows[i].version;
                self._txn_changed.add(aid);
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
    import from jaclang.data.serializer { Serializer }
    props = Serializer.serialize(anchor, include_type=True);
    if isinstance(props, dict) {
        props.pop('edges', None);
    }
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
        src = anchor.source.ensure_id() if anchor.source is not None else None;
        dst = anchor.target.ensure_id() if anchor.target is not None else None;
        undirected = anchor.is_undirected;
    }
    row_id = anchor.ensure_id();
    return AnchorRow(
        id=row_id,
        kind=type(anchor).__name__,
        arch_type=arch_type,
        arch_module=arch_module,
        fingerprint=fingerprint,
        root_id=anchor.root,
        version=self._version_seen.get(row_id, 0),
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
    import from jaclang.data.serializer { Serializer }
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
    if isinstance(anchor, NodeAnchor) {
        anchor.version = row.version;
    }
    self._version_seen[row.id] = row.version;
    self.__mem__[row.id] = anchor;
    self._flushed_hash[row.id] = _persist_hash(anchor);
    anchor.hash = self._flushed_hash[row.id];
    if self.store is not None
        and self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
        self._snapshot_reads.add(row.id);
    }
    return anchor;
}


impl Session.ensure_writable_txn -> None {
    with self._lock {
        if self.store is None {
            return;
        }
        if self.store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
            if self._ro_units > 0 {
                self._raise_ro_retry();
            }
            self.store.commit();
            self._drop_snapshot_reads();
            self.store.begin(TxnIsolation.SERIALIZABLE);
        } elif not self.store.in_txn() {
            self.store.begin(TxnIsolation.SERIALIZABLE);
        }
    }
}

impl Session.run_request(body: Callable) -> any {
    attempt = 0;
    while True {
        try {
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
    import from jaclang.runtime.osp_graph_sv { sv_store_closed }
    sv_store_closed(self);
}
