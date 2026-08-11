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


impl PgStore.postinit -> None {
    self._conn = None;
    self._side_conn = None;
    self._lock = threading.RLock();
    self._server_version = None;
    self._in_txn = False;
    self._known_types = set();
    self._listeners = [];
    self._listen_thread = None;
    self._listen_stop = None;
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


impl PgStore._connect -> Any {
    import from jaclang.vendor.pgload { connect as pg_connect }
    info = self.conninfo;
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


impl PgStore._main -> Any {
    if self._conn is None {
        self._conn = self._connect();
    }
    return self._conn;
}


impl PgStore._side -> Any {
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
    with self._lock {
        conn: Any = None;
        try {
            conn = self._main();
        } except Exception as e {
            if not (_conn_dead(e) and self.ensure_cb is not None) {
                raise;
            }
            self._conn = None;
            try {
                self.conninfo = self.ensure_cb();
            } except Exception { }
            conn = self._main();
        }
        try {
            return conn.run(sql, **params) or [];
        } except Exception as e {
            if _conn_dead(e) {
                try {
                    conn.close();
                } except Exception { }
                self._conn = None;
                was_txn = self._in_txn;
                self._in_txn = False;
                if self.ensure_cb is not None {
                    try {
                        self.conninfo = self.ensure_cb();
                    } except Exception { }
                }
                if was_txn {
                    import from jaclang.runtimelib.pgwire { PgWireError }
                    raise PgWireError(
                        {'C': '08006', 'M': 'connection lost mid-transaction; retry'}
                    ) from e;
                }
                conn2: Any = self._main();
                return conn2.run(sql, **params) or [];
            }
            if self._in_txn {
                try {
                    conn.run('ROLLBACK');
                } except Exception { }
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
        try {
            self._apply_schema_ddl();
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
                self._apply_schema_ddl();
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
        self._apply_promotions();
        self._property_graph_ddl();
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


impl PgStore.begin(serializable: bool = True, read_only: bool = False) -> None {
    with self._lock {
        if self._in_txn {
            return;
        }
        if read_only {
            level = 'REPEATABLE READ';
        } elif serializable {
            level = 'SERIALIZABLE';
        } else {
            level = 'READ COMMITTED';
        }
        suffix = ' READ ONLY' if read_only else '';
        self._run(f"BEGIN ISOLATION LEVEL {level}{suffix}", {});
        self._in_txn = True;
        try {
            self._run("SET LOCAL lock_timeout = '10s'", {});
        } except Exception { }
    }
}


impl PgStore.commit -> None {
    with self._lock {
        if not self._in_txn {
            return;
        }
        self._run('COMMIT', {});
        self._in_txn = False;
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
        }
    }
}


impl PgStore.in_txn -> bool {
    return self._in_txn;
}


impl PgStore.load_full(ids: list[UUID]) -> dict[UUID, AnchorRow] {
    if not ids {
        return {};
    }
    out: dict[UUID, AnchorRow] = {};
    rows = self._run(
        """
        SELECT a.id, a.kind, a.arch_type, a.arch_module, a.fingerprint,
               a.root_id, a.src, a.dst, a.undirected, a.props, a.xmin::text,
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
                f":undirected{i}, CAST(:props{i} AS jsonb), :fv{i}, now())"
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
            params[f"props{i}"] = json.dumps(row.props, default=_jsonable);
            params[f"fv{i}"] = SCHEMA_VERSION;
        }
        self._run(
            """
            INSERT INTO anchors
                (id, kind, arch_type, arch_module, fingerprint, root_id,
                 src, dst, undirected, props, format_version, updated_at)
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
                updated_at = now()
            """,
            params
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
        conn: Any = self._side();
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


impl PgStore.quarantine(
    missing_id: UUID, referrer_id: (UUID | None), kind: str
) -> None {
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
        conn: Any = self._side();
        conn.run('SELECT pg_notify(:c, :p)', c=channel, p=payload);
    }
}


impl PgStore.listen(channel: str, callback: Any) -> None {
    with self._lock {
        self._listeners.append((channel, callback));
        conn: Any = self._side();
        conn.run(f'LISTEN {_sanitize_ident(channel)}');
        if self._listen_thread is None {
            self._listen_stop = threading.Event();
            t: Any = threading.Thread(
                target=self._listen_loop, daemon=True, name='jac-pg-listen'
            );
            self._listen_thread = t;
            t.start();
        }
    }
}


impl PgStore._listen_loop -> None {
    import select;
    stop: Any = self._listen_stop;
    if stop is None {
        return;
    }
    while not stop.is_set() {
        pending: list = [];
        sock: Any = None;
        try {
            with self._lock {
                conn: Any = self._side();
                if conn.notifications {
                    pending = list(conn.notifications);
                    conn.notifications.clear();
                } else {
                    sock = conn._sock;
                }
            }
            if not pending {
                if sock is None {
                    stop.wait(1.0);
                    continue;
                }
                readable = select.select([sock], [], [], 10.0)[0];
                if stop.is_set() {
                    break;
                }
                if not readable {
                    continue;
                }
                with self._lock {
                    conn2: Any = self._side();
                    conn2.run('SELECT 1');
                    pending = list(conn2.notifications);
                    conn2.notifications.clear();
                }
            }
            for (pid, channel, payload) in pending {
                for (want, cb) in list(self._listeners) {
                    if _sanitize_ident(want) == channel {
                        try {
                            cb(payload);
                        } except Exception as e {
                            logger.warning(f"listener callback failed: {e}");
                        }
                    }
                }
            }
        } except Exception as e {
            logger.debug(f"listen loop hiccup: {e}");
            stop.wait(1.0);
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


impl PgStore._apply_promotions -> None {
    for (arch, fld, col) in self._promotion_columns() {
        try {
            self._run(
                f"""
                ALTER TABLE anchors ADD COLUMN IF NOT EXISTS {col} text
                GENERATED ALWAYS AS (props->'archetype'->>'{fld}') STORED
                """,
                {}
            );
            self._run(
                f"""
                CREATE INDEX IF NOT EXISTS idx_{col} ON anchors ({col})
                WHERE arch_type = '{arch}'
                """,
                {}
            );
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
    with self._lock {
        if self._listen_stop is not None {
            self._listen_stop.set();
        }
        for c in [self._conn, self._side_conn] {
            if c is not None {
                try {
                    c.close();
                } except Exception { }
            }
        }
        self._conn = None;
        self._side_conn = None;
        self._in_txn = False;
    }
}
