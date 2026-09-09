glob _SCHEMA_SQL = [
         """
    CREATE TABLE IF NOT EXISTS anchors (
        id             uuid PRIMARY KEY,
        kind           text NOT NULL,
        arch_type      text NOT NULL DEFAULT '',
        arch_module    text NOT NULL DEFAULT '',
        fingerprint    text NOT NULL DEFAULT '',
        root_id        uuid,
        src            uuid,
        dst            uuid,
        undirected     boolean NOT NULL DEFAULT false,
        props          jsonb NOT NULL DEFAULT '{}'::jsonb,
        format_version integer NOT NULL DEFAULT 1,
        version        bigint NOT NULL DEFAULT 0,
        updated_at     timestamptz NOT NULL DEFAULT now(),
        seq            bigserial
    )
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_src
        ON anchors (src, arch_type) WHERE src IS NOT NULL
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_dst
        ON anchors (dst, arch_type) WHERE dst IS NOT NULL
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_kind_type
        ON anchors (kind, arch_type)
    """,
         """
    CREATE INDEX IF NOT EXISTS idx_anchors_root
        ON anchors (root_id) WHERE root_id IS NOT NULL
    """,
         """
    CREATE TABLE IF NOT EXISTS graph_types (
        type_name text NOT NULL,
        ancestor  text NOT NULL,
        PRIMARY KEY (type_name, ancestor)
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS kv_state (
        key        text PRIMARY KEY,
        value      text NOT NULL,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now()
    )
    """,
         """
    CREATE TABLE IF NOT EXISTS quarantine (
        missing_id  uuid NOT NULL,
        referrer_id uuid,
        kind        text NOT NULL,
        created_at  timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (missing_id, kind)
    )
    """
     ];


impl ConnInfo.dsn -> str {
    if self.unix_socket_dir {
        return (
            f"host={self.unix_socket_dir} user={self.user} " f"dbname={self.database}"
        );
    }
    return (
        f"host={self.host} port={self.port} user={self.user} " f"dbname={self.database}"
    );
}


def _jsonable(o: object) -> str {
    return str(o);
}


def _sanitize_ident(name: str) -> str {
    out = '';
    for ch in name.lower() {
        out += ch if (ch.isalnum() or ch == '_') else '_';
    }
    return out;
}


def _store_ns(info: ConnInfo) -> str {
    return f"{info.unix_socket_dir or info.host}:{info.port}/{info.database}";
}


glob _PG_CHANNEL_LIMIT = 63,
     _CHANNEL_DIGEST_LEN = 16,
     _CHANNEL_ENVELOPE_KEY = '__jac_channel',
     _CHANNEL_ENVELOPE_VERSION = 1,
     _LISTEN_POLL_SECONDS = 1.0,
     _LISTEN_JOIN_SECONDS = 5.0;


def _channel_travels_verbatim(channel: str) -> bool {
    return (
        bool(channel)
        and '\x00' not in channel
        and len(channel.encode('utf-8')) <= _PG_CHANNEL_LIMIT
    );
}


def _channel_ident(channel: str) -> str {
    if _channel_travels_verbatim(channel) {
        return channel;
    }
    import hashlib;
    digest = hashlib.sha256(channel.encode('utf-8')).hexdigest()[:_CHANNEL_DIGEST_LEN];
    stem = _sanitize_ident(channel)[:_PG_CHANNEL_LIMIT - _CHANNEL_DIGEST_LEN - 1];
    return f"{stem}_{digest}";
}


def _quote_channel(ident: str) -> str {
    escaped = ident.replace('"', '""');
    return f'"{escaped}"';
}


def _channel_wire_payload(channel: str, ident: str, payload: str) -> str {
    if ident == channel {
        return payload;
    }
    return json.dumps(
        {
            _CHANNEL_ENVELOPE_KEY: _CHANNEL_ENVELOPE_VERSION,
            'channel': channel,
            'payload': payload
        }
    );
}


def _channel_envelope(payload: str) -> (ChannelMessage | None) {
    try {
        data = json.loads(payload);
    } except Exception {
        return None;
    }
    if not isinstance(data, dict)
        or data.get(_CHANNEL_ENVELOPE_KEY) != _CHANNEL_ENVELOPE_VERSION {
        return None;
    }
    return ChannelMessage(
        channel=str(data.get('channel', '')), payload=str(data.get('payload', ''))
    );
}


impl PgStore.postinit -> None {
    self._conn = None;
    self._side_conn = None;
    self._lock = threading.RLock();
    self._server_version = None;
    self._in_txn = False;
    self._isolation = None;
    self._known_types = set();
    self._listeners = [];
    self._listen_thread = None;
    self._listen_stop = None;
    self._side_listened = False;
    self._booted = False;
    self._ready = False;
    self._readying = None;
}


impl PgStore._ensure_ready -> None {
    if self._ready {
        return;
    }
    with self._lock {
        if self._ready or self._readying == threading.get_ident() {
            return;
        }
        self._readying = threading.get_ident();
        try {
            if self.ensure_cb is not None and not self._booted {
                self.conninfo = self.ensure_cb();
                self._booted = True;
            }
            if self.auto_schema {
                self.ensure_schema_once(self.promotions);
            }
            self._ready = True;
            if self.pending_reset {
                self.pending_reset = False;
                self.reset_data();
            }
        } finally {
            self._readying = None;
        }
    }
}


impl SessionConflictError.init(
    self: SessionConflictError, database: str = '', blockers: (list[dict] | None) = None
) -> None {
    self.database = database;
    self.blockers = list(blockers or []);
    parts: list[str] = [];
    for b in self.blockers {
        owner = b.get('owner_pid');
        who = (
            f"pid {owner}"
                if owner is not None
                else f"backend {b.get('backend_pid', '?')}"
        );
        cmd = str(b.get('cmd') or '');
        if cmd {
            who = f"{who} (jac {cmd})";
        }
        started = str(b.get('started') or '');
        if started {
            who = f"{who} since {started}";
        }
        parts.append(who);
    }
    detail = '; '.join(parts) if parts else 'an unidentified session';
    super.__init__(
        f"project database '{database}' is held by another live jac"
        f" process: {detail}"
    );
}


def _app_identity -> str {
    import sys;
    cmd = 'embedded';
    try {
        argv = list(sys?.argv or []);
        if argv {
            cmd = os.path.basename(str(argv[0]) or '') or 'embedded';
            if cmd.startswith('jac') and len(argv) > 1 {
                sub = str(argv[1]);
                if sub and not sub.startswith('-') {
                    cmd = sub;
                }
            }
        }
    } except Exception {
        cmd = 'unknown';
    }
    return f"jac:{os.getpid()}:{cmd}"[:63];
}


glob _SCHEMA_LOCK_TAG = 'jac:ensure_schema',
     _SCHEMA_LOCK_WAIT_SECONDS = 30.0,
     _SCHEMA_LOCK_POLL_SECONDS = 0.05,
     _SCHEMA_LOCK_POLL_MAX_SECONDS = 0.5,
     _CONCURRENT_CREATE_STATES = ('23505', '42P07', '42710');


def _schema_lock_key -> int {
    import hashlib;
    digest = hashlib.sha256(_SCHEMA_LOCK_TAG.encode('utf-8')).digest()[:8];
    return int.from_bytes(digest, 'big', signed=True);
}


def _sqlstate(e: Exception) -> str {
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict) and 'C' in arg {
            return str(arg.get('C') or '');
        }
    }
    return '';
}


def _parse_pid(raw: str) -> (int | None) {
    try {
        return int(raw);
    } except ValueError {
        return None;
    }
}


def _owner_alive(pid: (int | None)) -> bool {
    if pid is None or pid <= 0 {
        return True;
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except Exception {
        return True;
    }
}


impl PgStore._connect -> any {
    import from jaclang.data.pgload { connect as pg_connect }
    import from jaclang.data.pgpool { checkout }
    info = self.conninfo;
    pooled = checkout(info);
    if pooled is not None {
        return pooled;
    }
    return pg_connect(
        info.user,
        host=(info.host or None),
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=info.database,
        password=(info.password or None),
        startup_params={'application_name': _app_identity()}
    );
}


def _park_conn(info: any, conn: any, in_txn: bool, listened: bool) -> None {
    import from jaclang.data.pgpool { pool_enabled, release }
    if conn is None {
        return;
    }
    if not pool_enabled() or getattr(conn, '_closed', False) {
        try {
            conn.close();
        } except Exception {}
        return;
    }
    try {
        if in_txn {
            conn.run('ROLLBACK');
        }
        conn.run('DISCARD ALL');
        if listened {
            conn.notifications.clear();
        }
    } except Exception {
        try {
            conn.close();
        } except Exception {}
        return;
    }
    release(info, conn);
}


impl PgStore._main -> any {
    if self._conn is None {
        self._conn = self._connect();
    }
    return self._conn;
}


impl PgStore._side -> any {
    self._ensure_ready();
    if self._side_conn is None {
        self._side_conn = self._connect();
    }
    return self._side_conn;
}


def _conn_dead(e: Exception) -> bool {
    if isinstance(e, (ConnectionError, BrokenPipeError, EOFError, OSError)) {
        return True;
    }
    for arg in getattr(e, 'args', ()) {
        if isinstance(arg, dict)
            and arg.get('C') in ('08006', '08003', '57P01', '57P03', '25P03') {
            return True;
        }
    }
    return False;
}


impl PgStore._run(sql: str, params: dict) -> list {
    self._ensure_ready();
    with self._lock {
        conn: any = None;
        try {
            conn = self._main();
        } except Exception as e {
            if not (_conn_dead(e) and self.ensure_cb is not None) {
                raise;
            }
            self._conn = None;
            try {
                self.conninfo = self.ensure_cb();
            } except Exception {}
            conn = self._main();
        }
        try {
            return conn.run(sql, **params) or [];
        } except Exception as e {
            if _conn_dead(e) {
                try {
                    conn.close();
                } except Exception {}
                self._conn = None;
                was_txn = self._in_txn;
                self._in_txn = False;
                if self.ensure_cb is not None {
                    try {
                        self.conninfo = self.ensure_cb();
                    } except Exception {}
                }
                if was_txn {
                    import from jaclang.data.pgwire { PgWireError }
                    raise PgWireError(
                        {'C': '08006', 'M': 'connection lost mid-transaction; retry'}
                    ) from e;
                }
                conn2: any = self._main();
                return conn2.run(sql, **params) or [];
            }
            if self._in_txn {
                try {
                    conn.run('ROLLBACK');
                } except Exception {}
                self._in_txn = False;
            }
            raise;
        }
    }
}


impl PgStore.is_available -> bool {
    try {
        self._run('SELECT 1', {});
        return True;
    } except Exception {
        return False;
    }
}


impl PgStore.server_version -> int {
    if self._server_version is None {
        raw = str(self._run('SHOW server_version_num', {})[0][0]);
        self._server_version = int(raw) // 10000;
    }
    return self._server_version;
}


impl PgStore.ensure_schema(promotions: dict[str, list[str]]) -> None {
    with self._lock {
        self.promotions = dict(promotions);
        fp = self._schema_fingerprint();
        if self._schema_stamp() == fp {
            self._load_known_types();
            return;
        }
        held = self._acquire_schema_lock(fp);
        try {
            if self._schema_stamp() == fp {
                self._load_known_types();
                return;
            }
            try {
                self._apply_schema_ddl_resilient();
            } except PgWireError as e {
                if _sqlstate(e) != '55P03' {
                    raise;
                }
                if self._reap_dead_sessions() == 0 {
                    raise SessionConflictError(
                        database=self.conninfo.database, blockers=self._live_blockers()
                    ) from e;
                }
                try {
                    self._apply_schema_ddl_resilient();
                } except PgWireError as e2 {
                    if _sqlstate(e2) != '55P03' {
                        raise;
                    }
                    raise SessionConflictError(
                        database=self.conninfo.database, blockers=self._live_blockers()
                    ) from e2;
                }
            }
            self.kv_put(SCHEMA_STAMP_KEY, fp);
            self._load_known_types();
        } finally {
            if held {
                self._release_schema_lock();
            }
        }
    }
}


impl PgStore.ensure_schema_once(promotions: dict[str, list[str]]) -> None {
    self._ensure_ready();
    ns = _store_ns(self.conninfo);
    key = _schema_extension_key();
    if _schema_ready.get(ns) == key {
        return;
    }
    with _schema_gate {
        if _schema_ready.get(ns) == key {
            return;
        }
        self.ensure_schema(promotions);
        _schema_ready[ns] = key;
    }
}


impl PgStore.reset_data -> None {
    with self._lock {
        if self._in_txn {
            self.rollback();
        }
        listed = self._run(
            'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()', {}
        );
        tables = [str(row[0]) for row in listed];
        if not tables {
            return;
        }
        stamp = self._schema_stamp();
        targets = ', '.join(f'"{name}"' for name in sorted(tables));
        self._run(f"TRUNCATE {targets} RESTART IDENTITY CASCADE", {});
        if stamp {
            self.kv_put(SCHEMA_STAMP_KEY, stamp);
        }
        self._known_types = set();
    }
}


impl PgStore._acquire_schema_lock(fingerprint: str) -> bool {
    import time;
    deadline = time.monotonic() + _SCHEMA_LOCK_WAIT_SECONDS;
    delay = _SCHEMA_LOCK_POLL_SECONDS;
    while True {
        try {
            got = self._run(
                'SELECT pg_try_advisory_lock(:k)', {'k': _schema_lock_key()}
            );
            if got and bool(got[0][0]) {
                return True;
            }
        } except PgWireError as e {
            logger.debug(f"schema election unavailable ({_sqlstate(e)}): {e}");
            return False;
        }
        if self._schema_stamp() == fingerprint {
            return False;
        }
        if time.monotonic() >= deadline {
            logger.warning(
                f"waited {_SCHEMA_LOCK_WAIT_SECONDS:.0f}s for the schema"
                f" election on '{self.conninfo.database}'; applying schema"
                ' DDL without it'
            );
            return False;
        }
        time.sleep(delay);
        delay = min(delay * 2, _SCHEMA_LOCK_POLL_MAX_SECONDS);
    }
}


impl PgStore._release_schema_lock -> None {
    try {
        self._run('SELECT pg_advisory_unlock(:k)', {'k': _schema_lock_key()});
    } except Exception as e {
        logger.debug(f"schema election release failed: {e}");
    }
}


impl PgStore._apply_schema_ddl_resilient -> None {
    try {
        self._apply_schema_ddl();
    } except PgWireError as e {
        state = _sqlstate(e);
        if state not in _CONCURRENT_CREATE_STATES {
            raise;
        }
        logger.info(
            f"schema DDL lost a catalog race ({state}); a concurrent creator"
            ' won, re-checking'
        );
        if self._schema_stamp() == self._schema_fingerprint() {
            return;
        }

        self._apply_schema_ddl();
    }
}


impl PgStore._apply_schema_ddl -> None {
    self._run("SET lock_timeout = '5s'", {});
    try {
        for stmt in _SCHEMA_SQL {
            self._run(stmt, {});
        }
        has_seq = bool(
            self._run(
                """
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'anchors' AND column_name = 'seq'
                """,
                {}
            )
        );
        if not has_seq {
            self._run('ALTER TABLE anchors ADD COLUMN IF NOT EXISTS seq bigserial', {});
        }
        if self._promoted_column_type('version') is None {
            self._run(
                'ALTER TABLE anchors ADD COLUMN IF NOT EXISTS version bigint '
                'NOT NULL DEFAULT 0',
                {}
            );
        }
        self._apply_promotions();
        self._property_graph_ddl();
        for name in sorted(_schema_extensions) {
            for stmt in _schema_extensions[name] {
                self._run(stmt, {});
            }
        }
    } finally {
        self._run('SET lock_timeout = DEFAULT', {});
    }
}


impl PgStore._load_known_types -> None {
    for (tname, ) in self._run('SELECT DISTINCT type_name FROM graph_types', {}) {
        self._known_types.add(str(tname));
    }
}


impl PgStore._schema_fingerprint -> str {
    import hashlib;
    h = hashlib.sha256();
    h.update(str(SCHEMA_VERSION).encode());
    h.update(str(self.server_version()).encode());
    for stmt in _SCHEMA_SQL {
        h.update(stmt.encode());
    }
    for col in sorted(self._promotion_columns()) {
        h.update(str(col).encode());
    }
    for name in sorted(_schema_extensions) {
        h.update(name.encode());
        for stmt in _schema_extensions[name] {
            h.update(stmt.encode());
        }
    }
    return f"{SCHEMA_VERSION}:{h.hexdigest()[:24]}";
}


impl PgStore._schema_stamp -> (str | None) {
    try {
        return self.kv_get(SCHEMA_STAMP_KEY);
    } except PgWireError as e {
        if _sqlstate(e) == '42P01' {
            return None;
        }
        raise;
    }
}


impl PgStore._peer_sessions -> list[dict] {
    rows = self._run(
        """
        SELECT pid, application_name, state, backend_start::text
        FROM pg_stat_activity
        WHERE datname = current_database() AND pid <> pg_backend_pid()
        """,
        {}
    );
    out: list[dict] = [];
    for (pid, app, state, started) in rows {
        app_s = str(app or '');
        owner: (int | None) = None;
        cmd = '';
        parts = app_s.split(':', 2);
        if len(parts) == 3 and parts[0] == 'jac' {
            owner = _parse_pid(parts[1]);
            cmd = parts[2];
        }
        out.append(
            {
                'backend_pid': int(pid),
                'app': app_s,
                'state': str(state or ''),
                'started': str(started or ''),
                'owner_pid': owner,
                'cmd': cmd,
                'owner_alive': _owner_alive(owner)
            }
        );
    }
    return out;
}


impl PgStore._reap_dead_sessions -> int {
    if not self.conninfo.unix_socket_dir {
        return 0;
    }
    n = 0;
    for p in self._peer_sessions() {
        if p['owner_pid'] is not None and not p['owner_alive'] {
            try {
                self._run('SELECT pg_terminate_backend(:p)', {'p': p['backend_pid']});
                n += 1;
            } except Exception as e {
                logger.warning(f"failed to reap backend {p['backend_pid']}: {e}");
            }
        }
    }
    if n {
        logger.info(f"reaped {n} database session(s) left by dead process(es)");
    }
    return n;
}


impl PgStore._live_blockers -> list[dict] {
    peers = [
        p
        for p in self._peer_sessions()
        if p['owner_alive']
    ];
    held = [
        p
        for p in peers
        if 'idle in transaction' in p['state']
    ];
    return held or peers;
}


impl PgStore.takeover -> int {
    n = 0;
    for p in self._peer_sessions() {
        try {
            self._run('SELECT pg_terminate_backend(:p)', {'p': p['backend_pid']});
            n += 1;
        } except Exception as e {
            logger.warning(f"takeover failed for backend {p['backend_pid']}: {e}");
        }
    }
    return n;
}


impl PgStore.begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) -> None {
    with self._lock {
        if self._in_txn {
            return;
        }
        self._run(f"BEGIN {isolation.value}", {});
        self._in_txn = True;
        self._isolation = isolation;
        try {
            self._run("SET LOCAL lock_timeout = '10s'", {});
        } except Exception {}
    }
}


impl PgStore.commit -> None {
    with self._lock {
        if not self._in_txn {
            return;
        }
        try {
            self._run('COMMIT', {});
        } finally {
            self._in_txn = False;
            self._isolation = None;
        }
    }
}


impl PgStore.rollback -> None {
    with self._lock {
        if not self._in_txn {
            return;
        }
        try {
            self._run('ROLLBACK', {});
        } finally {
            self._in_txn = False;
            self._isolation = None;
        }
    }
}


impl PgStore.in_txn -> bool {
    return self._in_txn;
}


impl PgStore.txn_isolation -> (TxnIsolation | None) {
    return self._isolation if self._in_txn else None;
}


impl PgStore.load_full(ids: list[UUID]) -> dict[UUID, AnchorRow] {
    if not ids {
        return {};
    }
    out: dict[UUID, AnchorRow] = {};
    rows = self._run(
        """
        SELECT a.id, a.kind, a.arch_type, a.arch_module, a.fingerprint,
               a.root_id, a.src, a.dst, a.undirected, a.props, a.version,
               CASE WHEN a.kind = 'NodeAnchor' THEN
                   (SELECT string_agg(e.id::text, ',' ORDER BY e.seq, e.id)
                      FROM anchors e WHERE e.src = a.id OR e.dst = a.id)
               END
        FROM anchors a WHERE a.id = ANY(CAST(:ids AS uuid[]))
        """,
        {'ids': [str(i) for i in ids]}
    );
    for r in rows {
        raw_props = r[9];
        props: dict = (
            raw_props if isinstance(raw_props, dict) else json.loads(str(raw_props))
        );
        adjacency: (list[UUID] | None) = None;
        if str(r[1]) == 'NodeAnchor' {
            adjacency = [];
            if r[11] {
                seen_e: set[str] = set();
                for tok in str(r[11]).split(',') {
                    if tok and tok not in seen_e {
                        seen_e.add(tok);
                        adjacency.append(UUID(tok));
                    }
                }
            }
        }
        row = AnchorRow(
            id=UUID(str(r[0])),
            kind=str(r[1]),
            arch_type=str(r[2]),
            arch_module=str(r[3]),
            fingerprint=str(r[4]),
            root_id=UUID(str(r[5])) if r[5] else None,
            props=props,
            src=UUID(str(r[6])) if r[6] else None,
            dst=UUID(str(r[7])) if r[7] else None,
            undirected=bool(r[8]),
            version=int(str(r[10])),
            adjacency=adjacency
        );
        out[row.id] = row;
    }
    return out;
}


impl PgStore.upsert(rows_in: list[AnchorRow]) -> None {
    if not rows_in {
        return;
    }
    by_id: dict[UUID, AnchorRow] = {row.id: row for row in rows_in};
    rows = list(by_id.values());
    stale: list[AnchorRow] = [];
    chunk = 200;
    for start in range(0, len(rows), chunk) {
        batch = rows[start:start + chunk];
        values: list[str] = [];
        params: dict = {};
        for (i, row) in enumerate(batch) {
            values.append(
                f"(CAST(:id{i} AS uuid), :kind{i}, :arch_type{i}, "
                f":arch_module{i}, :fp{i}, CAST(:root_id{i} AS uuid), "
                f"CAST(:src{i} AS uuid), CAST(:dst{i} AS uuid), "
                f":undirected{i}, CAST(:props{i} AS jsonb), :fv{i}, :ver{i}, now())"
            );
            params[f"id{i}"] = str(row.id);
            params[f"kind{i}"] = row.kind;
            params[f"arch_type{i}"] = row.arch_type;
            params[f"arch_module{i}"] = row.arch_module;
            params[f"fp{i}"] = row.fingerprint;
            params[f"root_id{i}"] = str(row.root_id) if row.root_id else None;
            params[f"src{i}"] = str(row.src) if row.src else None;
            params[f"dst{i}"] = str(row.dst) if row.dst else None;
            params[f"undirected{i}"] = row.undirected;
            params[f"props{i}"] = json.dumps(row.props, `default=_jsonable);
            params[f"fv{i}"] = SCHEMA_VERSION;
            params[f"ver{i}"] = int(row.version);
        }
        written = self._run(
            """
            INSERT INTO anchors
                (id, kind, arch_type, arch_module, fingerprint, root_id,
                 src, dst, undirected, props, format_version, version, updated_at)
            VALUES
            """
                + ',\n'.join(values)
                + """
            ON CONFLICT (id) DO UPDATE SET
                kind = EXCLUDED.kind,
                arch_type = EXCLUDED.arch_type,
                arch_module = EXCLUDED.arch_module,
                fingerprint = EXCLUDED.fingerprint,
                root_id = EXCLUDED.root_id,
                src = EXCLUDED.src,
                dst = EXCLUDED.dst,
                undirected = EXCLUDED.undirected,
                props = EXCLUDED.props,
                format_version = EXCLUDED.format_version,
                version = EXCLUDED.version + 1,
                updated_at = now()
            WHERE anchors.version = EXCLUDED.version
            RETURNING id, version
            """,
            params
        );
        landed: dict[str, int] = {str(r[0]): int(r[1]) for r in written};
        for row in batch {
            got = landed.get(str(row.id));
            if got is None {
                stale.append(row);
            } else {
                row.version = got;
            }
        }
    }
    if stale {
        first = stale[0];
        found = self._run(
            'SELECT version FROM anchors WHERE id = CAST(:i AS uuid)',
            {'i': str(first.id)}
        );
        raise WriteConflict(
            anchor_id=first.id,
            expected_version=int(first.version),
            actual_version=int(found[0][0]) if found else -1
        );
    }
    pairs: list[tuple[str, str]] = [];
    seen_pairs: set[tuple[str, str]] = set();
    for row in rows {
        if row.arch_type and row.arch_type not in self._known_types {
            for anc in (row.ancestry or [row.arch_type]) {
                if (row.arch_type, anc) not in seen_pairs {
                    seen_pairs.add((row.arch_type, anc));
                    pairs.append((row.arch_type, anc));
                }
            }
        }
    }
    if pairs {
        tvals: list[str] = [];
        tparams: dict = {};
        for (i, pair) in enumerate(pairs) {
            tvals.append(f"(:t{i}, :a{i})");
            tparams[f"t{i}"] = pair[0];
            tparams[f"a{i}"] = pair[1];
        }
        self._run(
            'INSERT INTO graph_types (type_name, ancestor) VALUES '
                + ', '.join(tvals)
                + ' ON CONFLICT DO NOTHING',
            tparams
        );
        for pair in pairs {
            self._known_types.add(pair[0]);
        }
    }
}


impl PgStore.delete(ids: list[UUID]) -> None {
    if not ids {
        return;
    }
    self._run(
        'DELETE FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': [str(i) for i in ids]}
    );
}


impl PgStore.existing(ids: list[UUID]) -> set[UUID] {
    if not ids {
        return set();
    }
    rows = self._run(
        'SELECT id FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': [str(i) for i in ids]}
    );
    return {UUID(str(r[0])) for r in rows};
}


impl PgStore.root_ids -> list[UUID] {
    rows = self._run(
        """
        SELECT id FROM anchors
        WHERE kind = 'NodeAnchor' AND arch_type = 'Root' ORDER BY id
        """,
        {}
    );
    return [UUID(str(r[0])) for r in rows];
}


impl PgStore.subtype_names(type_name: str) -> list[str] {
    rows = self._run(
        'SELECT type_name FROM graph_types WHERE ancestor = :t', {'t': type_name}
    );
    names = [str(r[0]) for r in rows];
    if type_name not in names {
        names.append(type_name);
    }
    return names;
}


impl PgStore.rows(sql: str, params: dict) -> list[tuple] {
    return [tuple(r) for r in self._run(sql, params)];
}


impl PgStore.kv_get(key: str) -> (str | None) {
    rows = self._run(
        """
        SELECT value FROM kv_state
        WHERE key = :k AND (expires_at IS NULL OR expires_at > now())
        """,
        {'k': key}
    );
    return str(rows[0][0]) if rows else None;
}


impl PgStore.kv_put(key: str, value: str) -> None {
    self._run(
        """
        INSERT INTO kv_state (key, value, updated_at) VALUES (:k, :v, now())
        ON CONFLICT (key) DO UPDATE SET value = :v, updated_at = now()
        """,
        {'k': key, 'v': value}
    );
}


impl PgStore.kv_put_ttl(key: str, value: str, ttl_seconds: int) -> None {
    with self._lock {
        conn: any = self._side();
        conn.run(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, :v, now() + make_interval(secs => CAST(:ttl AS int)), now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            """,
            k=key,
            v=value,
            ttl=ttl_seconds
        );
    }
}


impl PgStore.kv_delete(key: str) -> None {
    self._run('DELETE FROM kv_state WHERE key = :k', {'k': key});
}


impl PgStore.kv_acquire_lease(key: str, ttl_seconds: int, owner: str) -> bool {
    with self._lock {
        conn: any = self._side();
        rows = conn.run(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, :o, now() + make_interval(secs => CAST(:ttl AS int)), now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            WHERE kv_state.value = :o
                  OR kv_state.expires_at IS NULL
                  OR kv_state.expires_at <= now()
            RETURNING key
            """,
            k=f"lease:{key}",
            o=owner,
            ttl=ttl_seconds
        );
    }
    return bool(rows);
}


impl PgStore.kv_release_lease(key: str, owner: str) -> bool {
    with self._lock {
        conn: any = self._side();
        rows = conn.run(
            'DELETE FROM kv_state WHERE key = :k AND value = :o RETURNING key',
            k=f"lease:{key}",
            o=owner
        );
    }
    return bool(rows);
}


impl PgStore.quarantine(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
    if self._isolation is TxnIsolation.SNAPSHOT_READ_ONLY {
        return;
    }
    self._run(
        """
        INSERT INTO quarantine (missing_id, referrer_id, kind)
        VALUES (CAST(:m AS uuid), CAST(:r AS uuid), :k)
        ON CONFLICT DO NOTHING
        """,
        {
            'm': str(missing_id),
            'r': str(referrer_id) if referrer_id else None,
            'k': kind
        }
    );
}


impl PgStore.notify(channel: str, payload: str) -> None {
    with self._lock {
        ident = _channel_ident(channel);
        conn: any = self._side();
        conn.run(
            'SELECT pg_notify(:c, :p)',
            c=ident,
            p=_channel_wire_payload(channel, ident, payload)
        );
    }
}


impl PgStore.listen(channel: str, callback: any) -> None {
    with self._lock {
        ident = _channel_ident(channel);
        self._listeners.append(
            ChannelListener(channel=channel, ident=ident, callback=callback)
        );
        conn: any = self._side();
        conn.run(f"LISTEN {_quote_channel(ident)}");
        self._side_listened = True;
        if self._listen_thread is None {
            self._listen_stop = threading.Event();
            t: any = threading.Thread(
                target=self._listen_loop, daemon=True, name='jac-pg-listen'
            );
            self._listen_thread = t;
            t.start();
        }
    }
}


impl PgStore.unlisten(channel: str) -> None {
    parked: any = None;
    with self._lock {
        ident = _channel_ident(channel);
        kept = [
            lst
            for lst in self._listeners
            if lst.channel != channel
        ];
        if len(kept) == len(self._listeners) {
            return;
        }
        self._listeners = kept;
        shared = any((lst.ident == ident) for lst in kept);
        conn: any = self._side_conn;
        if conn is not None and not shared {
            try {
                conn.run(f"UNLISTEN {_quote_channel(ident)}");
            } except Exception as e {
                logger.debug(f"unlisten {channel} failed: {e}");
            }
        }
        if not self._listeners {
            parked = self._stop_listen_thread();
        }
    }
    self._join_listen_thread(parked);
}


impl PgStore._stop_listen_thread -> any {
    if self._listen_stop is not None {
        self._listen_stop.set();
    }
    parked = self._listen_thread;
    self._listen_thread = None;
    return parked;
}


impl PgStore._join_listen_thread(parked: any) -> None {
    if parked is None or parked is threading.current_thread() {
        return;
    }
    parked.join(timeout=_LISTEN_JOIN_SECONDS);
    if parked.is_alive() {
        logger.warning('pg listen thread did not stop within its join window');
    }
}


impl PgStore._listen_loop -> None {
    import select;
    stop: any = self._listen_stop;
    if stop is None {
        return;
    }
    while not stop.is_set() {
        pending: list = [];
        sock: any = None;
        try {
            with self._lock {
                conn: any = self._side_conn;
                if conn is None {
                    break;
                }
                if conn.notifications {
                    pending = list(conn.notifications);
                    conn.notifications.clear();
                } else {
                    sock = conn._sock;
                }
            }
            if not pending {
                if sock is None {
                    stop.`wait(_LISTEN_POLL_SECONDS);
                    continue;
                }
                readable = select.select([sock], [], [], _LISTEN_POLL_SECONDS)[0];
                if stop.is_set() {
                    break;
                }
                if not readable {
                    continue;
                }
                with self._lock {
                    conn2: any = self._side_conn;
                    if conn2 is None {
                        break;
                    }
                    conn2.run('SELECT 1');
                    pending = list(conn2.notifications);
                    conn2.notifications.clear();
                }
            }
            for (pid, channel, payload) in pending {
                self._dispatch_notification(channel, payload);
            }
        } except Exception as e {
            logger.debug(f"listen loop hiccup: {e}");
            stop.`wait(_LISTEN_POLL_SECONDS);
        }
    }
}


impl PgStore._dispatch_notification(channel: str, payload: str) -> None {
    envelope: (ChannelMessage | None) = None;
    decoded = False;
    for lst in list(self._listeners) {
        if lst.ident != channel {
            continue;
        }
        body = payload;
        if lst.channel != channel {
            if not decoded {
                envelope = _channel_envelope(payload);
                decoded = True;
                if envelope is None {
                    logger.warning(
                        f"notification on {channel} carries no channel envelope;"
                        ' dropping it rather than guessing a subscriber'
                    );
                }
            }
            if envelope is None or envelope.channel != lst.channel {
                continue;
            }
            body = envelope.payload;
        }
        try {
            lst.callback(body);
        } except Exception as e {
            logger.warning(f"listener callback failed: {e}");
        }
    }
}


impl PgStore._promotion_columns -> list[tuple[str, str, str]] {
    out: list[tuple[str, str, str]] = [];
    for (arch, fields_l) in sorted(self.promotions.items()) {
        for fld in fields_l {
            col = f"g_{_sanitize_ident(arch)}_{_sanitize_ident(fld)}";
            out.append((arch, fld, col));
        }
    }
    return out;
}


impl PgStore._promoted_column_type(col: str) -> (str | None) {
    rows = self._run(
        'SELECT data_type FROM information_schema.columns '
        'WHERE table_name = :t AND column_name = :c',
        {'t': 'anchors', 'c': col.lower()}
    );
    return str(rows[0][0]) if rows else None;
}


impl PgStore._apply_promotions -> None {
    for (arch, fld, col) in self._promotion_columns() {
        try {
            have = self._promoted_column_type(col);
            if have is not None and have != 'jsonb' {
                logger.info(
                    f"promotion {arch}.{fld}: rebuilding {col} from {have} to jsonb"
                );
                self._run(f'DROP INDEX IF EXISTS idx_{col}', {});
                self._run(f'ALTER TABLE anchors DROP COLUMN IF EXISTS {col}', {});
            }
            self._run(
                f"""
                ALTER TABLE anchors ADD COLUMN IF NOT EXISTS {col} jsonb
                GENERATED ALWAYS AS (props->'archetype'->'{fld}') STORED
                """,
                {}
            );
            self._run(f'CREATE INDEX IF NOT EXISTS idx_{col} ON anchors ({col})', {});
        } except Exception as e {
            logger.warning(f"promotion {arch}.{fld} failed: {e}");
        }
    }
}


impl PgStore._property_graph_ddl -> None {
    if self.server_version() < 19 {
        return;
    }
    stmts = [
        """
        CREATE OR REPLACE VIEW graph_nodes AS
            SELECT id, arch_type, root_id, props FROM anchors
            WHERE kind = 'NodeAnchor'
        """,
        """
        CREATE OR REPLACE VIEW graph_edges AS
            SELECT id, arch_type, src, dst, undirected, props FROM anchors
            WHERE kind = 'EdgeAnchor' AND src IS NOT NULL AND dst IS NOT NULL
        """,
        """
        CREATE PROPERTY GRAPH IF NOT EXISTS jac_graph
            VERTEX TABLES (
                graph_nodes KEY (id) LABEL node PROPERTIES (arch_type)
            )
            EDGE TABLES (
                graph_edges KEY (id)
                    SOURCE KEY (src) REFERENCES graph_nodes (id)
                    DESTINATION KEY (dst) REFERENCES graph_nodes (id)
                    LABEL edge PROPERTIES (arch_type)
            )
        """
    ];
    for stmt in stmts {
        try {
            self._run(stmt, {});
        } except Exception as e {
            logger.debug(f"property graph ddl skipped: {e}");
            return;
        }
    }
}


impl PgStore.close -> None {
    parked: any = None;
    main_conn: any = None;
    side_conn: any = None;
    was_txn = False;
    listened = False;
    with self._lock {
        parked = self._stop_listen_thread();
        self._listeners = [];
        main_conn = self._conn;
        side_conn = self._side_conn;
        was_txn = self._in_txn;
        listened = self._side_listened;
        self._conn = None;
        self._side_conn = None;
        self._in_txn = False;
        self._side_listened = False;
    }
    self._join_listen_thread(parked);
    _park_conn(self.conninfo, main_conn, was_txn, False);
    _park_conn(self.conninfo, side_conn, False, listened);
}
