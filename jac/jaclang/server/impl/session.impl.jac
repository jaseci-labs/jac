def _database_config(base_path: (str | None)) -> DatabaseConfig {
    config = get_config_for_dir(base_path) if base_path else None;
    return config.database if config is not None else DatabaseConfig();
}


impl promotions_for(base_path: (str | None)) -> dict[str, list[str]] {
    return dict(_database_config(base_path).indexes);
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
    return str(bucket("pg").path() / 'main');
}


impl project_database(base_path: str, target_path: (str | None)) -> ProjectDatabase {
    import hashlib;

    workspace = workspace_for_path(target_path or base_path);
    database_root = os.path.realpath(base_path);
    in_project = False;
    if workspace is not None {
        project_root = os.path.realpath(workspace.project_root);
        if database_root == project_root
            or database_root.startswith(project_root + os.sep) {
            database_root = project_root;
            in_project = True;
        }
        name = workspace.persistence_namespace;
    } else {
        name = get_name(target_path=target_path) or 'main';
    }
    safe = ''.join((ch if (ch.isalnum() or ch == '_') else '_') for ch in name.lower());
    digest = hashlib.sha1(database_root.encode('utf-8')).hexdigest()[:8];
    return ProjectDatabase(
        name=f"jac_{safe[:40]}_{digest}", owner=database_root, in_project=in_project
    );
}


impl project_db_name(base_path: str, target_path: (str | None)) -> str {
    return project_database(base_path, target_path).name;
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


impl scratch_owner_pid -> int {
    raw = os.environ.get(SCRATCH_OWNER_ENV, '').strip();
    if not raw {
        return 0;
    }
    try {
        return max(0, int(raw));
    } except ValueError {
        logger.warning(f"ignoring {SCRATCH_OWNER_ENV}={raw!r}: not a pid");
        return 0;
    }
}


def _drop_owned_at_exit -> None {
    if scratch_owner_pid() != os.getpid() {
        return;
    }
    try {
        drop_owned_databases();
    } except Exception as e {
        logger.debug(f"could not drop the databases this process owns: {e}");
    }
}


impl own_child_databases -> None {
    outer = scratch_owner_pid();
    if outer == os.getpid() {
        return;
    }
    if outer > 0 and process_alive(this_host(), outer) {
        return;
    }
    import atexit;
    os.environ[SCRATCH_OWNER_ENV] = str(os.getpid());
    atexit.register(_drop_owned_at_exit);
}


impl drop_owned_databases(data_dir: str = '') -> int {
    rt = PgRuntime(data_dir=data_dir or shared_pg_data_dir(), database=MAINTENANCE_DB);
    if not rt.is_running() {
        return 0;
    }
    dropped = 0;
    conn: any = connect_admin(rt.conninfo());
    try {
        for name in owned_databases(conn, os.getpid()) {
            if drop_database(conn, name, force=True) {
                dropped += 1;
            }
        }
    } finally {
        conn.close();
    }
    if dropped {
        logger.info(f"dropped {dropped} database(s) created under this process");
    }
    return dropped;
}


impl retention_days_for(base_path: (str | None)) -> int {
    raw: str = os.environ.get(RETENTION_ENV, '').strip();
    if not raw {
        return _database_config(base_path).retention_days;
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
    owner = 0 if lease is not None else scratch_owner_pid();
    scratch = lease is not None or owner > 0;
    project = project_database(base_path, target_path);
    return RuntimeLease(
        runtime=PgRuntime(
            data_dir=shared_pg_data_dir(),
            database=lease.database if lease is not None else project.name,
            owner_path=project.owner
                if project.in_project
                else os.path.abspath(base_path),
            kind=DbKind.SCRATCH if scratch else DbKind.PROJECT,
            owner_pid=owner,
            retention_days=(0 if scratch else retention_days_for(base_path)),
            sole_owner_database=project.in_project and not scratch
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
    if arch is None {
        return [];
    }
    stops = (NodeArchetype, EdgeArchetype, WalkerArchetype, Archetype, object);
    out: list[str] = [];
    for c in type(arch).__mro__ {
        if c in stops {
            break;
        }
        import from jaclang.data.type_identity { storage_type }
        out.append(storage_type(c));
    }
    return out;
}


glob _GETTER_CLASSES: dict[type, bool] = {};

def _runs_getters(arch: object) -> bool {
    cls = type(arch);
    found = _GETTER_CLASSES.get(cls);
    if found is None {
        found = any(
            isinstance(member, property)
            for klass in cls.__mro__
            if klass is not object and not klass.__module__.startswith('jaclang.')
            for member in vars(klass).values()
        );
        _GETTER_CLASSES[cls] = found;
    }
    return found;
}

def _settle_written(anchor: Anchor, seen: int) {
    if seen and anchor.__dict__.get('_field_written', 0) == seen {
        anchor.__dict__.pop('_field_written', None);
    }
}


def _is_serialization_conflict(e: Exception) -> bool {
    if isinstance(e, WriteConflict) {
        return False;
    }
    seen = 0;
    cur: (BaseException | None) = e;
    while cur is not None and seen < 8 {
        c: BaseException = cur;
        for arg in getattr(c, 'args', ()) {
            if isinstance(arg, dict)
                and arg.get('C') in ('40001', '40P01', '53200', '55P03', '08006') {
                return True;
            }
        }
        cur = c.__cause__ or c.__context__;
        seen += 1;
    }
    return False;
}


impl transient_db_error(e: Exception) -> bool {
    return _is_serialization_conflict(e);
}


def _is_lock_timeout(e: Exception) -> bool {
    seen = 0;
    cur: (BaseException | None) = e;
    while cur is not None and seen < 8 {
        c: BaseException = cur;
        for arg in getattr(c, 'args', ()) {
            if isinstance(arg, dict) and arg.get('C') == '55P03' {
                return True;
            }
        }
        cur = c.__cause__ or c.__context__;
        seen += 1;
    }
    return False;
}


impl RowLedger.postinit -> None {
    self._committed = {};
    self._upserted = {};
    self._removed = set();
    self._joined = False;
}


impl RowLedger._reset -> None {
    self._upserted = {};
    self._removed = set();
    self._joined = False;
}


impl RowLedger.current(id: UUID) -> (RowState | None) {
    if id in self._removed {
        return None;
    }
    written = self._upserted.get(id);
    return written if written is not None else self._committed.get(id);
}


impl RowLedger.write_version(id: UUID) -> int {
    if id in self._removed {
        prior = self._committed.get(id);
        return prior.version + 1 if prior is not None else 0;
    }
    state = self.current(id);
    return state.version if state is not None else 0;
}


impl RowLedger.loaded(id: UUID, state: RowState) -> None {
    if id in self._upserted {
        self._upserted[id] = state;
    } else {
        self._committed[id] = state;
    }
}


impl RowLedger.upserted(id: UUID, state: RowState) -> None {
    self._removed.discard(id);
    self._upserted[id] = state;
}


impl RowLedger.removed(id: UUID) -> None {
    self._upserted.pop(id, None);
    self._removed.add(id);
}


impl RowLedger.joined -> None {
    self._joined = True;
}


impl RowLedger.forget(id: UUID) -> None {
    self._committed.pop(id, None);
}


impl RowLedger.in_flight -> bool {
    return bool(self._upserted) or bool(self._removed) or self._joined;
}


impl RowLedger.promote -> None {
    self._committed.update(self._upserted);
    for id in self._removed {
        self._committed.pop(id, None);
    }
    self._reset();
}


impl RowLedger.discard -> TxnWrites {
    lost = TxnWrites(
        upserted=list(self._upserted), removed=list(self._removed), joined=self._joined
    );
    self._reset();
    self.rollbacks += 1;
    return lost;
}


impl RowLedger.clear -> None {
    self._committed = {};
    self._reset();
}


impl Session.postinit -> None {
    self._init_memory();
    self._fetch_count = 0;
    self._rows = RowLedger();
    self._lost = False;
    self._active_units = 0;
    self._flushing = None;
    self._read_scopes = 0;
    self._ro_units = 0;
    self._unit_stack = [];
    self._snapshot_reads = set();
    self._foreign_refs = set();
    self._contended = set();
    self._hop_writes = 0;
    self._hop_cache = {};
    self._hop_siblings = {};
    self._hop_groups_token = None;
    self._queued = [];
    self._last_conflict = set();
    self._scan_clean = False;
    self._scan_sealed = False;
    self._scan_safe = True;
}


impl Session._runtime_lease -> RuntimeLease {
    with self._lock {
        if self._lease is None {
            self._lease = runtime_for_base(self.base_path or '', self.target_path);
        }
        return self._lease;
    }
}


impl Session._boot_store -> None {
    if self._store is not None or not self.base_path {
        return;
    }
    url = os.environ.get('JAC_DB_URL', '');
    promos = promotions_for(self.base_path);
    if url {
        self._store = PgStore(
            conninfo=conninfo_from_url(url), promotions=promos, auto_schema=True
        );
        return;
    }
    lease = self._runtime_lease();
    rt = lease.runtime;
    pgs = PgStore(
        conninfo=rt.conninfo(), ensure_cb=rt.ensure, promotions=promos, auto_schema=True
    );
    if lease.reset {
        if rt.is_running() {
            pgs.reset_data();
        } else {
            pgs.pending_reset = True;
        }
    }
    self._store = pgs;
    self._data_location = f"{rt.data_dir}/{rt.database}";
}


impl Session.__repr__ -> str {
    state = "booted" if self._store is not None else "unbooted";
    return f"Session(base_path={self.base_path}, store={state})";
}


impl Session.data_location -> (str | None) {
    if self._data_location is not None {
        return self._data_location;
    }
    info: (ConnInfo | None) = None;
    if isinstance(self._store, PgStore) {
        info = self._store.conninfo;
    } elif self.base_path {
        url = os.environ.get('JAC_DB_URL', '');
        if url {
            info = conninfo_from_url(url);
        }
    }
    if info is not None {
        return info.unix_socket_dir or f"{info.host}:{info.port}/{info.database}";
    }
    if not self.base_path {
        return None;
    }
    rt = self._runtime_lease().runtime;
    self._data_location = f"{rt.data_dir}/{rt.database}";
    return self._data_location;
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
        self._replay_txn(e);
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
            anchor = self._materialize(row);
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
                self._foreign_refs.difference_update(missing);
                for (rid, row) in loaded.items() {
                    anchor = self._materialize(row);
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
                self._replay_txn(e);
            }
        }
    }
    return out;
}


impl Session.commit(anchor: (Anchor | None) = None) -> None {
    with self._lock {
        if (
            self._store is None and self.base_path and (self._dirty or self._deleted)
        ) {
            self._boot_store();
        }
        if self._store is not None {
            if self._lost {
                self._rollback_txn();
                raise TransactionLost(anchor_id=UUID(int=0));
            }
            attempt = 0;
            while True {
                try {
                    self.flush(full=True);
                    self._commit_txn();
                    self._leave_queue();
                    break;
                } except Exception as e {
                    if not _is_serialization_conflict(e) {
                        self._rollback_txn();
                        raise;
                    }
                    self._replay_txn(e, exhausted=attempt >= MAX_RETRIES);
                    attempt += 1;
                    logger.info(
                        "serialization conflict at commit; replaying the write set "
                        f"(attempt {attempt}/{MAX_RETRIES})"
                    );
                }
            }
        } else {
            self._dirty.clear();
            self._deleted.clear();
        }
    }
    self._fire_on_commit();
}


impl Session.abort -> None {
    with self._lock {
        self._contended |= self._last_conflict;
        self._last_conflict = set();
        self._rollback_txn();
        self._forget_loaded();
        self._dirty.clear();
        self._deleted.clear();
        self._snapshot_reads.clear();
        self._on_commit = [];
        self._lost = False;
        self.unseal_scan();
    }
}


impl Session._forget_loaded -> None {
    self._drop_hop_state();
    for (id, anchor) in list(self.__mem__.items()) {
        if not anchor.is_populated() or not anchor.persistent {
            continue;
        }
        if isinstance(anchor, EdgeAnchor) {
            sv_forget_edge(anchor, self);
        }
        self.__mem__.pop(id, None);
        self._rows.forget(id);
    }
}


impl Session.quarantine_ref(referrer: (Anchor | None), stub: Anchor) -> None {
    sid = stub.ensure_id();
    sv_forget_by_id(sid, self);
    if self._store is not None {
        try {
            self._store.quarantine(
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
    self._rollback_txn();
    raise ReadOnlyRetry(anchor_id=_UUID(int=0), unit_key=last);
}


impl Session._drop_snapshot_reads -> None {
    for id in self._snapshot_reads {
        if id in self._dirty or id in self._deleted {
            continue;
        }
        stale = self.__mem__.pop(id, None);
        self._rows.forget(id);
        if isinstance(stale, EdgeAnchor) {
            sv_forget_edge(stale, self);
        }
    }
    self._snapshot_reads.clear();
}


impl Session._ensure_txn -> None {
    with self._lock {
        if self._store is None {
            return;
        }
        self._reclaim_dead_txn();
        wanted = self._txn_isolation();
        if not self._store.in_txn() {
            self._begin_txn(wanted);
        } elif wanted is TxnIsolation.SERIALIZABLE {
            self._begin_writable();
        }
    }
}


impl Session.unit_enter(key: (str | None) = None) -> None {
    with self._lock {
        self.unseal_scan();
        ro = key is not None and ro_units_enabled() and not unit_writes_recorded(key);
        self._active_units += 1;
        if ro {
            self._ro_units += 1;
        }
        self._unit_stack.append((key, ro));
        if self._store is not None and self._store.in_txn() {
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
        if self._read_scopes > 0 or self._store is None {
            return;
        }
        if self._store.txn_isolation() is not TxnIsolation.SNAPSHOT_READ_ONLY {
            return;
        }
        try {
            self._commit_txn();
        } except Exception as e {
            logger.warning(
                f"read snapshot close failed; rolling back: {type(e).__name__}: {e}"
            );
            self._rollback_txn();
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
            if self._lost {
                self.abort();
                raise TransactionLost(anchor_id=UUID(int=0));
            }
            if self._store is None or not self._store.in_txn() {
                return;
            }
            try {
                self.commit();
            } except TransactionLost {
                self.abort();
                raise;
            } except WriteConflict {
                raise;
            } except Exception as e {
                logger.warning(
                    f"unit close commit failed; rolled back: {type(e).__name__}: {e}"
                );
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


impl Session._commit_txn -> None {
    if self._store is not None {
        self._store.commit();
        self._rows.promote();
    }
}


impl Session._rollback_txn -> None {
    if self._store is not None {
        try {
            self._store.rollback();
        } except Exception as e {
            logger.debug(f"rollback failed: {type(e).__name__}: {e}");
        }
    }
    lost = self._rows.discard();
    if lost.joined {
        self._lost = True;
    }
    for id in lost.upserted {
        anchor = self.__mem__.get(id);
        if anchor is None {
            continue;
        }
        prior = self._rows.current(id);
        anchor.hash = prior.hash if prior is not None else 0;
        self._dirty[id] = None;
    }
    for id in lost.removed {
        if id not in self.__mem__ {
            self._deleted.add(id);
        }
    }
}


impl Session._replay_txn(cause: Exception, exhausted: bool = False) -> None {
    self._rollback_txn();
    if exhausted {
        self._lost = True;
    }
    if self._lost {
        raise TransactionLost(anchor_id=UUID(int=0)) from cause;
    }
}


impl Session._reclaim_dead_txn -> None {
    if not self._rows.in_flight() or self._store is None or self._store.in_txn() {
        return;
    }
    self._rollback_txn();
    if self._lost {
        raise TransactionLost(anchor_id=UUID(int=0));
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
        self._replay_txn(e);
        self._ensure_txn();
        self.flush();
    }
}


impl Session.flush(full: bool = False) -> None {
    if self._store is None {
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


impl Session.seal_scan -> None {
    with self._lock {
        self._scan_sealed = self._scan_clean;
    }
}


impl Session.unseal_scan -> None {
    with self._lock {
        self._scan_clean = False;
        self._scan_sealed = False;
    }
}


impl Session._flush_locked(full: bool) -> None {
    store = self._store;
    if store is None {
        return;
    }
    if full and self._scan_sealed {
        full = any(
            anchor is not None and _runs_getters(anchor.archetype)
            for anchor in (self.__mem__.get(id) for id in self._dirty)
        );
        if full {
            self._scan_sealed = False;
        }
    }
    self._reclaim_dead_txn();
    unflushed: list[UnflushedAnchor] = [];
    while True {
        epoch = self._rows.rollbacks;
        unflushed = self._unflushed(full);
        if unflushed or self._deleted {
            self._begin_writable();
        }
        if self._rows.rollbacks == epoch {
            break;
        }
    }
    wrote = bool(unflushed or self._deleted);
    if unflushed {
        rows = [self._serialize(u.anchor, u.stored) for u in unflushed];
        retyped = [
            row.id
            for row in rows
            if row.kind == 'NodeAnchor'
                and row.arch_type
                and (was := self._rows.current(row.id)) is not None
                and was.arch_type not in ('', row.arch_type)
        ];
        try {
            store.upsert(rows);
            store.retype_edges(retyped);
        } except WriteConflict as wc {
            self._last_conflict = {wc.anchor_id};
            raise;
        } except Exception as e {
            if self._queued or not _is_lock_timeout(e) {
                raise;
            }
            self._last_conflict = {row.id for row in rows};
            raise WriteConflict(anchor_id=rows[0].id) from e;
        }
        for (row, u) in zip(rows, unflushed) {
            self._rows.upserted(
                row.id,
                RowState(hash=u.hash, version=row.version, arch_type=row.arch_type)
            );
            u.anchor.hash = u.hash;
            _settle_written(u.anchor, u.written);
        }
    }
    if self._deleted {
        try {
            store.delete(list(self._deleted));
        } except Exception as e {
            if self._queued or not _is_lock_timeout(e) {
                raise;
            }
            self._last_conflict = set(self._deleted);
            raise WriteConflict(anchor_id=sorted(self._deleted)[0]) from e;
        }
        for id in self._deleted {
            self._rows.removed(id);
        }
        self._deleted.clear();
    }
    self._dirty.clear();
    if wrote {
        self._hop_writes += 1;
    }
    if full {
        self._scan_clean = self._scan_safe;
    }
}


impl Session._unflushed(full: bool) -> list[UnflushedAnchor] {
    import from jaclang { JacRuntimeInterface as JacRI }

    candidates = list(self.__mem__.keys()) if full else list(self._dirty.keys());
    out: list[UnflushedAnchor] = [];
    safe = True;
    for id in candidates {
        anchor = self.__mem__.get(id);
        if anchor is None or not anchor.persistent or not anchor.is_populated() {
            continue;
        }
        known = self._rows.current(id);
        if full
            and id not in self._dirty
            and known is not None
            and known.hash != 0
            and frozen_fields(anchor) {
            continue;
        }
        written = anchor.__dict__.get('_field_written', 0);
        if safe and _runs_getters(anchor.archetype) {
            safe = False;
        }
        stored: (dict[str, object] | None) = None;
        try {
            stored = Serializer.stored_form(anchor);
        } except Exception {}
        h = Serializer.stored_hash(anchor, stored);
        if h != 0 and known is not None and known.hash == h and id not in self._dirty {
            _settle_written(anchor, written);
            continue;
        }
        if not JacRI.check_write_access(anchor, op_hint="field_write") {
            continue;
        }
        out.append(
            UnflushedAnchor(anchor=anchor, stored=stored, hash=h, written=written)
        );
    }
    self._scan_safe = safe;
    return out;
}


impl Session._serialize(
    anchor: Anchor, stored: (dict[str, object] | None) = None
) -> AnchorRow {
    if stored is None {
        stored = Serializer.stored_form(anchor);
    }
    arch = anchor.archetype;
    arch_type = '';
    arch_module = '';
    fingerprint = '';
    if anchor.is_populated() and arch is not None {
        arch_type = storage_type(type(arch));
        arch_module = type_module(type(arch));
        fp = type(arch)?.__jac_fingerprint__;
        fingerprint = fp if isinstance(fp, str) else '';
    }
    src: (UUID | None) = None;
    dst: (UUID | None) = None;
    undirected = False;
    src_type = '';
    dst_type = '';
    if isinstance(anchor, EdgeAnchor) {
        src = anchor.source.ensure_id() if anchor.source is not None else None;
        dst = anchor.target.ensure_id() if anchor.target is not None else None;
        undirected = anchor.is_undirected;
        src_arch = anchor.source.__dict__.get('archetype')
            if anchor.source is not None
            else None;
        dst_arch = anchor.target.__dict__.get('archetype')
            if anchor.target is not None
            else None;
        src_type = storage_type(type(src_arch)) if src_arch is not None else '';
        dst_type = storage_type(type(dst_arch)) if dst_arch is not None else '';
    }
    row_id = anchor.ensure_id();
    return AnchorRow(
        id=row_id,
        kind=type(anchor).__name__,
        arch_type=arch_type,
        arch_module=arch_module,
        fingerprint=fingerprint,
        root_id=anchor.root,
        version=self._rows.write_version(row_id),
        props=stored,
        src=src,
        dst=dst,
        undirected=undirected,
        src_type=src_type,
        dst_type=dst_type,
        ancestry=_ancestry_of(arch)
    );
}


impl Session._materialize(row: AnchorRow) -> (Anchor | None) {
    import from functools { partial }

    self._foreign_refs.discard(row.id);
    existing = self.__mem__.get(row.id);
    if existing is not None and existing.is_populated() {
        return existing;
    }

    application = application_for(self.target_path) if self.target_path else None;
    try {
        with resolution_scope(application) {
            got = Serializer.deserialize(row.props);
        }
    } except ForeignType {
        self._foreign_refs.add(row.id);
        return None;
    }
    if not isinstance(got, Anchor) {
        logger.warning(
            f"could not materialize anchor {row.id} ({row.arch_type}); skipping"
        );
        if self._store is not None {
            try {
                self._store.quarantine(row.id, None, row.kind);
            } except Exception as e {
                logger.debug(f"quarantine record failed: {e}");
            }
        }
        return None;
    }
    anchor: Anchor = got;
    if isinstance(anchor, NodeAnchor) {
        if self._store is not None {
            anchor.__dict__.pop('edges', None);
            anchor.__dict__['_edge_loader'] = partial(self._load_edges, anchor);
        }
        anchor.version = row.version;
    }
    self.__mem__[row.id] = anchor;
    self._rows.loaded(
        row.id, RowState(hash=anchor.hash, version=row.version, arch_type=row.arch_type)
    );
    if self._store is not None
        and self._store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
        self._snapshot_reads.add(row.id);
    }
    return anchor;
}


impl Session._load_edges(nd: NodeAnchor) -> list[EdgeAnchor] {
    loaded = nd.__dict__.get('edges');
    if loaded is not None {
        return loaded;
    }
    ids: list[UUID] = [];
    if self._store is not None and nd.id is not None {
        self.read_barrier();
        after: (tuple[int, UUID] | None) = None;
        while True {
            page = self._store.adjacency(nd.id, after, EDGE_PAGE);
            for (seq, eid) in page {
                if eid not in self._deleted {
                    ids.append(eid);
                }
            }
            if len(page) < EDGE_PAGE {
                break;
            }
            after = page[-1];
        }
    }
    edges: list[EdgeAnchor] = [];
    for eid in ids {
        stub = Serializer._id_to_stub(EdgeAnchor, str(eid));
        if isinstance(stub, EdgeAnchor) {
            edges.append(stub);
        }
    }
    nd.__dict__['edges'] = edges;
    nd.__dict__['_initial_edge_ids'] = frozenset(ids);
    nd.__dict__.pop('_edge_loader', None);
    return edges;
}


impl Session.ensure_writable_txn -> None {
    with self._lock {
        if self._store is None {
            return;
        }
        self._begin_writable();
        self._rows.joined();
    }
}


impl Session._begin_writable -> None {
    with self._lock {
        if self._store is None {
            return;
        }
        self._reclaim_dead_txn();
        if self._store.txn_isolation() is TxnIsolation.SNAPSHOT_READ_ONLY {
            if self._ro_units > 0 {
                self._raise_ro_retry();
            }
            self._commit_txn();
            self._drop_snapshot_reads();
            self._begin_txn(TxnIsolation.SERIALIZABLE);
        } elif not self._store.in_txn() {
            self._begin_txn(TxnIsolation.SERIALIZABLE);
        }
    }
}


impl Session._begin_txn(isolation: TxnIsolation) -> None {
    backing = self._store;
    if backing is None {
        return;
    }
    backing.begin(isolation);
    if not self._queued and isolation is TxnIsolation.SERIALIZABLE {
        backing.lock_wait(FIRST_LOCK_WAIT);
    }
}


impl Session.wait_turn -> None {
    with self._lock {
        backing = self._store;
        if backing is None or not self._contended {
            return;
        }
        wanted = sorted(self._contended);
        if wanted != sorted(self._queued) {
            if self._queued {
                held = self._queued;
                self._queued = [];
                backing.queue_exit(held);
            }
            if not backing.queue_enter(wanted) {
                self._contended.clear();
                return;
            }
            self._queued = wanted;
        }
        if backing.in_txn() {
            return;
        }
        pinned = sorted(self._queued);
        for _ in range(PIN_ATTEMPTS) {
            backing.begin(TxnIsolation.SERIALIZABLE);
            try {
                backing.lock_rows(pinned);
                return;
            } except Exception as e {
                if not _is_serialization_conflict(e) {
                    raise;
                }
                backing.rollback();
            }
        }
    }
}


glob _SESSION_POOL: list[any] = [];


def _session_pool -> any {
    if not _SESSION_POOL {
        import from concurrent.futures { ThreadPoolExecutor }
        _SESSION_POOL.append(
            ThreadPoolExecutor(
                max_workers=SESSION_THREADS, thread_name_prefix="jac-session-io"
            )
        );
    }
    return _SESSION_POOL[0];
}


async def _off_loop(work: Callable) -> any {
    import asyncio;
    import contextvars;
    context = contextvars.copy_context();
    def in_context -> any {
        return context.run(work);
    }
    return await asyncio.get_running_loop().run_in_executor(
        _session_pool(), in_context
    );
}


impl Session.acommit(anchor: (Anchor | None) = None) -> None {
    def settle {
        self.commit(anchor);
    }
    await _off_loop(settle);
}


impl Session._leave_queue -> None {
    self._contended.clear();
    self._last_conflict = set();
    held = self._queued;
    self._queued = [];
    if not held or self._store is None {
        return;
    }
    try {
        self._store.queue_exit(held);
    } except Exception as e {
        logger.warning(f"releasing the write queue failed: {type(e).__name__}: {e}");
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
                self._store is not None
                and (isinstance(e, WriteConflict) or _is_serialization_conflict(e))
                and attempt < MAX_RETRIES
            ) {
                attempt += 1;
                logger.info(
                    "serialization conflict; re-running request "
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
    self._leave_queue();
    if self._store is not None {
        self._store.close();
    }
    self.__mem__.clear();
    self._dirty.clear();
    self._deleted.clear();
    self._rows.clear();
    self._lost = False;
    self._drop_hop_state();

    sv_store_closed(self);
}


impl Session._hop_token -> (tuple[int, int] | None) {
    store = self._store;
    if store is None or not store.in_txn() {
        return None;
    }
    if store.txn_isolation() is TxnIsolation.READ_COMMITTED {
        return None;
    }
    serial = store.txn_serial();
    if serial < 0 {
        return None;
    }
    return (serial, self._hop_writes);
}


impl Session.batching -> bool {
    return self._hop_token() is not None;
}


impl Session._drop_hop_state -> None {
    self._hop_siblings = {};
    self._hop_cache = {};
    self._hop_groups_token = None;
}


impl Session.note_siblings(ids: list[UUID]) -> None {
    if len(ids) < 2 {
        return;
    }
    token = self._hop_token();
    if token is None {
        return;
    }
    if token != self._hop_groups_token {
        self._hop_siblings = {};
        self._hop_groups_token = token;
    }
    group = tuple(ids[:HOP_BATCH_LIMIT]);
    for i in group {
        self._hop_siblings[i] = group;
    }
}


impl Session.hop_siblings(origin: UUID) -> tuple[UUID, ...] {
    if self._hop_groups_token is None or self._hop_groups_token != self._hop_token() {
        return ();
    }
    return self._hop_siblings.get(origin, ());
}


impl Session.hop_cached(key: any, origin: UUID) -> (list[tuple[any, any]] | None) {
    held = self._hop_cache.get(key);
    if held is None or held[0] != self._hop_token() {
        return None;
    }
    return held[1].get(origin);
}


impl Session.hop_store(key: any, by_origin: dict[UUID, list[tuple[any, any]]]) -> None {
    token = self._hop_token();
    if token is None {
        return;
    }
    stale = [
        k
        for (k, held) in self._hop_cache.items()
        if held[0] != token
    ];
    for k in stale {
        del self._hop_cache[k];
    }
    self._hop_cache[key] = (token, by_origin);
}
