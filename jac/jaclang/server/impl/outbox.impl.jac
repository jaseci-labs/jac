glob _COLUMNS = (
         "id, app, walker, kwargs, idempotency_key, attempts, created_at, "
         "status, last_error, next_attempt_at"
     );


impl canonical_kwargs(kwargs: dict) -> str {
    return json.dumps(kwargs, sort_keys=True, separators=(",", ":"), `default=str);
}


impl default_idempotency_key(app: str, `walker: str, kwargs: dict) -> str {
    material = "\n".join([app, `walker, canonical_kwargs(kwargs)]);
    return hashlib.sha256(material.encode("utf-8")).hexdigest()[:32];
}


impl backoff_seconds(attempts: int) -> float {
    if attempts <= 1 {
        return BACKOFF_BASE_S;
    }
    if attempts > 16 {
        return BACKOFF_CAP_S;
    }
    return min(BACKOFF_CAP_S, BACKOFF_BASE_S * float(1 << (attempts - 1)));
}


impl outbox_db_path -> str {
    data_root = os.environ.get("JAC_DATA_PATH", "").strip();
    if data_root {
        return os.path.join(data_root, OUTBOX_DB_REL);
    }
    import from jaclang { JacRuntime }
    import from jaclang.compiler.driver.modresolver { find_jac_project_root }
    base = JacRuntime.get_base_path_dir() or os.getcwd();
    project_root = find_jac_project_root(base) or base;
    return os.path.join(project_root, OUTBOX_DB_REL);
}


impl use_store(store: (OutboxStore | None)) -> None {
    with _state.lock {
        cached_sqlite = _state.sqlite_store;
        cached_worker = _state.worker_store;
        _state.explicit = store;
        _state.worker_store = None;
        _state.sqlite_store = None;
        _state.schema_ready = set();
        _state.seen_lru = OrderedDict();
        if cached_sqlite is not None and cached_sqlite is not store {
            cached_sqlite.close();
        }
        if isinstance(cached_worker, PgOutboxStore) and cached_worker is not store {
            cached_worker.close();
        }
    }
}


impl _row_to_entry(row: tuple) -> OutboxEntry {
    raw_kwargs = row[3];
    return OutboxEntry(
        id=str(row[0]),
        app=str(row[1]),
        `walker=str(row[2]),
        kwargs=json.loads(raw_kwargs) if raw_kwargs else {},
        idempotency_key=str(row[4]),
        attempts=int(row[5] or 0),
        created_at=float(row[6] or 0.0),
        status=str(row[7]),
        last_error=str(row[8] or ""),
        next_attempt_at=float(row[9] or 0.0)
    );
}


impl SqliteOutboxStore.ensure_tables -> None {
    for stmt in _SCHEMA_SQL {
        self._exec(stmt, {});
    }
}


impl SqlOutboxStore.put(item: OutboxEntry) -> None {
    self._exec(
        f"""
        INSERT INTO jac_outbox ({_COLUMNS})
        VALUES (
            :id, :app, :walker, :kwargs, :key, :attempts, :created_at,
            :status, :last_error, :next_attempt_at
        )
        ON CONFLICT (idempotency_key) DO NOTHING
        """,
        {
            "id": item.id,
            "app": item.app,
            "walker": item.`walker,
            "kwargs": canonical_kwargs(item.kwargs),
            "key": item.idempotency_key,
            "attempts": item.attempts,
            "created_at": item.created_at,
            "status": item.status,
            "last_error": item.last_error,
            "next_attempt_at": item.next_attempt_at
        }
    );
}


impl SqlOutboxStore.get_by_key(key: str) -> (OutboxEntry | None) {
    rows = self._exec(
        f"SELECT {_COLUMNS} FROM jac_outbox WHERE idempotency_key = :key", {"key": key}
    );
    return _row_to_entry(rows[0]) if rows else None;
}


impl SqlOutboxStore.list_pending(
    now: float, limit: int = DELIVER_BATCH
) -> list[OutboxEntry] {
    rows = self._exec(
        f"""
        SELECT {_COLUMNS} FROM jac_outbox
        WHERE status IN (:pending, :delivering) AND next_attempt_at <= :now
        ORDER BY next_attempt_at, created_at
        LIMIT :limit
        """,
        {
            "pending": STATUS_PENDING,
            "delivering": STATUS_DELIVERING,
            "now": now,
            "limit": int(limit)
        }
    );
    return [_row_to_entry(r) for r in rows];
}


impl SqlOutboxStore.claim(id: str, now: float, lease_s: float = LEASE_S) -> bool {
    changed = self._exec_count(
        """
        UPDATE jac_outbox
        SET status = :next, next_attempt_at = :lease_until
        WHERE id = :id
          AND status IN (:pending, :delivering)
          AND next_attempt_at <= :now
        """,
        {
            "next": STATUS_DELIVERING,
            "lease_until": now + float(lease_s),
            "id": id,
            "pending": STATUS_PENDING,
            "delivering": STATUS_DELIVERING,
            "now": now
        }
    );
    return changed == 1;
}


impl SqlOutboxStore.update(item: OutboxEntry) -> None {
    self._exec(
        """
        UPDATE jac_outbox
        SET attempts = :attempts,
            status = :status,
            last_error = :last_error,
            next_attempt_at = :next_attempt_at
        WHERE id = :id
        """,
        {
            "attempts": item.attempts,
            "status": item.status,
            "last_error": item.last_error,
            "next_attempt_at": item.next_attempt_at,
            "id": item.id
        }
    );
}


impl SqlOutboxStore.list_status(status: str) -> list[OutboxEntry] {
    rows = self._exec(
        f"SELECT {_COLUMNS} FROM jac_outbox WHERE status = :status ORDER BY created_at",
        {"status": status}
    );
    return [_row_to_entry(r) for r in rows];
}


impl SqlOutboxStore.prune_status(status: str, created_before: float) -> int {
    return self._exec_count(
        "DELETE FROM jac_outbox WHERE status = :status AND created_at < :before",
        {"status": status, "before": created_before}
    );
}


impl SqlOutboxStore.prune_seen(now: float) -> int {
    return self._exec_count(
        "DELETE FROM jac_outbox_seen WHERE expires_at <= :now", {"now": now}
    );
}


impl SqlOutboxStore.recall_key(key: str, now: float) -> (str | None) {
    rows = self._exec(
        """
        SELECT result FROM jac_outbox_seen
        WHERE idempotency_key = :key AND expires_at > :now
        """,
        {"key": key, "now": now}
    );
    return str(rows[0][0] or "") if rows else None;
}


impl SqlOutboxStore.remember_key(
    key: str, ttl_s: int, result: str, now: float
) -> None {
    self._exec(
        """
        INSERT INTO jac_outbox_seen (idempotency_key, result, expires_at)
        VALUES (:key, :result, :expires_at)
        ON CONFLICT (idempotency_key) DO UPDATE SET
            result = EXCLUDED.result,
            expires_at = EXCLUDED.expires_at
        """,
        {"key": key, "result": result, "expires_at": now + float(ttl_s)}
    );
}


impl PgOutboxStore._exec(sql: str, params: dict) -> list[tuple] {
    return self.store.rows(sql, params);
}


impl PgOutboxStore._exec_count(sql: str, params: dict) -> int {
    return len(self.store.rows(sql + " RETURNING 1", params));
}


impl PgOutboxStore.ensure_tables -> None {
    self.store.ensure_schema_once(self.store.promotions);
}


impl PgOutboxStore.close -> None {
    self.store.close();
}


impl SqliteOutboxStore.postinit -> None {
    parent = os.path.dirname(self.path);
    if parent {
        os.makedirs(parent, exist_ok=True);
    }
    conn = sqlite3.connect(
        self.path, check_same_thread=False, isolation_level=None, timeout=5.0
    );
    conn.execute("PRAGMA journal_mode=WAL");
    conn.execute("PRAGMA synchronous=NORMAL");
    conn.execute("PRAGMA busy_timeout=5000");
    self._conn = conn;
    self.ensure_tables();
}


impl SqliteOutboxStore._exec(sql: str, params: dict) -> list[tuple] {
    with self._lock {
        conn = self._conn;
        if conn is None {
            raise RuntimeError(f"outbox store at {self.path} is closed");
        }
        cur = conn.execute(sql, params);
        try {
            return [tuple(r) for r in cur.fetchall()];
        } finally {
            cur.close();
        }
    }
}


impl SqliteOutboxStore._exec_count(sql: str, params: dict) -> int {
    with self._lock {
        conn = self._conn;
        if conn is None {
            raise RuntimeError(f"outbox store at {self.path} is closed");
        }
        cur = conn.execute(sql, params);
        try {
            return int(cur.rowcount);
        } finally {
            cur.close();
        }
    }
}


impl SqliteOutboxStore.close -> None {
    with self._lock {
        conn = self._conn;
        self._conn = None;
        if conn is not None {
            conn.close();
        }
    }
}


impl _current_memory -> any {
    import from jaclang { JacRuntime }
    ctx = JacRuntime.peek_context();
    return ctx.mem if ctx is not None else None;
}


impl _primary_pg_store -> (PgStore | None) {
    store = _current_memory()?.store;
    return store if isinstance(store, PgStore) else None;
}


impl _writable_txn(mem: any, store: Store) -> None {
    import from jaclang.server.session { Session }
    if not isinstance(mem, Session) {
        if not store.in_txn() {
            store.begin(TxnIsolation.SERIALIZABLE);
        }
        return;
    }
    mem.ensure_writable_txn();
}


impl _derive_worker_store(primary: PgStore) -> PgOutboxStore {
    side = PgStore(
        conninfo=primary.conninfo,
        ensure_cb=primary.ensure_cb,
        promotions=dict(primary.promotions)
    );
    derived = PgOutboxStore(store=side);
    derived.ensure_tables();
    return derived;
}


impl _ensure_pg_schema(primary: PgStore) -> None {
    marker = primary.conninfo.dsn();
    if marker in _state.schema_ready {
        return;
    }
    with _state.lock {
        if marker in _state.schema_ready {
            return;
        }
        current = _state.worker_store;
        if isinstance(current, PgOutboxStore) {
            current.ensure_tables();
        } else {
            _state.worker_store = _derive_worker_store(primary);
        }
        _state.schema_ready.add(marker);
    }
}


impl _sqlite_store -> SqliteOutboxStore {
    with _state.lock {
        if _state.sqlite_store is None {
            _state.sqlite_store = SqliteOutboxStore(path=outbox_db_path());
        }
        return _state.sqlite_store;
    }
}


impl _store_for_request(writable: bool = True) -> OutboxStore {
    explicit = _state.explicit;
    if explicit is not None {
        return explicit;
    }
    primary = _primary_pg_store();
    if primary is None {
        return _sqlite_store();
    }
    _ensure_pg_schema(primary);
    if writable {
        _writable_txn(_current_memory(), primary);
    }
    return PgOutboxStore(store=primary);
}


impl _store_for_worker -> OutboxStore {
    explicit = _state.explicit;
    if explicit is not None {
        return explicit;
    }
    primary = _primary_pg_store();
    if primary is not None {
        _ensure_pg_schema(primary);
    }
    with _state.lock {
        cached = _state.worker_store;
        if cached is not None {
            return cached;
        }
        resolved: OutboxStore = _sqlite_store();
        _state.worker_store = resolved;
        return resolved;
    }
}


impl _store_for_seen -> OutboxStore {
    return _store_for_worker();
}


impl enqueue(app: str, `walker: str, kwargs: dict, idempotency_key: str = "") -> str {
    key = idempotency_key or default_idempotency_key(app, `walker, kwargs);
    store = _store_for_request(writable=True);
    found = store.get_by_key(key);
    if found is not None {
        return found.id;
    }
    now = time.time();
    item = OutboxEntry(
        id=uuid.uuid4().hex,
        app=app,
        `walker=`walker,
        kwargs=dict(kwargs),
        idempotency_key=key,
        attempts=0,
        created_at=now,
        status=STATUS_PENDING,
        last_error="",
        next_attempt_at=now
    );
    store.put(item);
    winner = store.get_by_key(key);
    return winner.id if winner is not None else item.id;
}


impl _run_coro(coro: any) -> any {
    import asyncio;
    try {
        asyncio.get_running_loop();
    } except RuntimeError {
        return asyncio.run(coro);
    }
    box: list[tuple[bool, any]] = [];

    def runner {
        try {
            box.append((True, asyncio.run(coro)));
        } except BaseException as e {
            box.append((False, e));
        }
    }
    helper = threading.Thread(target=runner, daemon=True, name="jac-outbox-await");
    helper.start();
    helper.join();
    (ok, value) = box[0];
    if not ok {
        if isinstance(value, BaseException) {
            raise value;
        }
        raise RuntimeError(str(value));
    }
    return value;
}


impl _deliver_one(item: OutboxEntry) -> any {
    import jaclang.server.sv_client as sv_client;
    return await sv_client.spawn_walker(
        item.app,
        item.`walker,
        dict(item.kwargs),
        DeliveryReceipt,
        idempotency_key=item.idempotency_key
    );
}


impl deliver_pending(max_attempts: int = DEFAULT_MAX_ATTEMPTS) -> int {
    store = _store_for_worker();
    now = time.time();
    due = store.list_pending(now, DELIVER_BATCH);
    delivered = 0;
    for item in due {
        if not store.claim(item.id, now) {
            continue;
        }
        item.status = STATUS_DELIVERING;
        item.attempts += 1;
        try {
            _run_coro(_deliver_one(item));
            item.status = STATUS_DELIVERED;
            item.last_error = "";
            delivered += 1;
        } except Exception as e {
            message = f"{type(e).__name__}: {e}";
            item.last_error = message[:2000];
            if isinstance(e, BridgeRejected) or item.attempts >= max_attempts {
                item.status = STATUS_DEAD;
                walker_name = item.`walker;
                logger.warning(
                    f"outbox {item.id} to {item.app}.{walker_name} dead after "
                    f"{item.attempts} attempt(s): {item.last_error}"
                );
            } else {
                item.status = STATUS_PENDING;
                item.next_attempt_at = time.time() + backoff_seconds(item.attempts);
            }
        }
        store.update(item);
    }
    return delivered;
}


impl prune(delivered_ttl_s: float = DELIVERED_TTL_S) -> int {
    store = _store_for_worker();
    now = time.time();
    removed = store.prune_status(STATUS_DELIVERED, now - float(delivered_ttl_s));
    store.prune_seen(now);
    return removed;
}


impl purge_dead(older_than_s: float = 0.0) -> int {
    return _store_for_worker().prune_status(
        STATUS_DEAD, time.time() - float(older_than_s)
    );
}


impl dead_letters -> list[OutboxEntry] {
    return _store_for_worker().list_status(STATUS_DEAD);
}


impl _worker_loop(interval_s: float, stop: threading.Event) -> None {
    while not stop.is_set() {
        try {
            deliver_pending();
            prune();
        } except Exception as e {
            logger.warning(f"outbox delivery pass failed: {type(e).__name__}: {e}");
        }
        stop.`wait(timeout=interval_s);
    }
}


impl start_worker(interval_s: float = 1.0) -> None {
    with _state.lock {
        current = _state.worker;
        if current is not None and current.is_alive() {
            return;
        }
        _store_for_worker();
        stop = threading.Event();
        thread = threading.Thread(
            target=_worker_loop, args=(interval_s, stop), daemon=True, name="jac-outbox"
        );
        _state.stop_event = stop;
        _state.worker = thread;
        thread.start();
    }
}


impl start_worker_if_bridging(interval_s: float = 1.0) -> bool {
    import jaclang.server.sv_client as sv_client;
    if not sv_client.has_consumers() {
        return False;
    }
    start_worker(interval_s);
    return True;
}


impl stop_worker(timeout_s: float = 5.0) -> None {
    with _state.lock {
        thread = _state.worker;
        stop = _state.stop_event;
        _state.worker = None;
        _state.stop_event = None;
    }
    if stop is not None {
        stop.set();
    }
    if thread is not None and thread.is_alive() {
        thread.join(timeout=timeout_s);
    }
}


impl worker_running -> bool {
    thread = _state.worker;
    return thread is not None and thread.is_alive();
}


impl _lru_get(key: str, now: float) -> (str | None) {
    with _state.lock {
        hit = _state.seen_lru.get(key);
        if hit is None {
            return None;
        }
        (expires_at, result) = hit;
        if expires_at <= now {
            _state.seen_lru.pop(key, None);
            return None;
        }
        _state.seen_lru.move_to_end(key);
        return result;
    }
}


impl _lru_put(key: str, expires_at: float, result: str) -> None {
    with _state.lock {
        _state.seen_lru[key] = (expires_at, result);
        _state.seen_lru.move_to_end(key);
        while len(_state.seen_lru) > SEEN_LRU_SIZE {
            _state.seen_lru.popitem(last=False);
        }
    }
}


impl cached_result(key: str) -> (str | None) {
    if not key {
        return None;
    }
    now = time.time();
    hit = _lru_get(key, now);
    if hit is not None {
        return hit;
    }
    return _store_for_seen().recall_key(key, now);
}


impl seen_idempotency_key(key: str) -> bool {
    return cached_result(key) is not None;
}


impl remember_idempotency_key(
    key: str, ttl_s: int = DEFAULT_SEEN_TTL_S, result: str = ""
) -> None {
    if not key {
        return;
    }
    now = time.time();
    _store_for_seen().remember_key(key, ttl_s, result, now);
    _lru_put(key, now + float(ttl_s), result);
}


impl scoped_idempotency_key(raw: str, username: str, app: str, target: str) -> str {
    key = str(raw or "").strip();
    if not key {
        return "";
    }
    material = "\n".join([app, target, username]).encode("utf-8");
    return hashlib.sha256(material).hexdigest()[:16] + ":" + key;
}


impl replay_cached(key: str) -> any {
    if not key {
        return None;
    }
    cached = cached_result(key);
    if cached is None {
        return None;
    }
    import from jaclang.server.bridge { replay_response }
    return replay_response(cached);
}


impl remember_response(key: str, response: any) -> any {
    if not key {
        return response;
    }
    import from jaclang.server.bridge { serialize_response }
    import from jaclang.server.serving.datatypes { JSONResponse }
    import from jaclang.server.transport { TransportResponse }
    ok = False;
    if isinstance(response, TransportResponse) {
        ok = bool(response.ok);
    } elif isinstance(response, JSONResponse) {
        ok = 200 <= int(response.status_code) < 300;
    }
    if ok {
        remember_idempotency_key(key, result=serialize_response(response));
    }
    return response;
}
