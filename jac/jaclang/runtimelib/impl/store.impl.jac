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


impl PgStore._connect -> Any {
    import from jaclang.vendor.pgload { connect as pg_connect }
    info = self.conninfo;
    return pg_connect(
        info.user,
        host=(info.host or None),
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=info.database,
        password=(info.password or None)
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


impl PgStore._run(sql: str, params: dict) -> list {
    with self._lock {
        conn: Any = self._main();
        try {
            return conn.run(sql, **params) or [];
        } except Exception {
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
            self._run("SET lock_timeout = '5s'", {});
            try {
                self._run(
                    'ALTER TABLE anchors ADD COLUMN IF NOT EXISTS seq bigserial', {}
                );
            } finally {
                self._run('SET lock_timeout = DEFAULT', {});
            }
        }
        self._apply_promotions();
        self._property_graph_ddl();
        for (tname, ) in self._run('SELECT DISTINCT type_name FROM graph_types', {}) {
            self._known_types.add(str(tname));
        }
    }
}


impl PgStore.begin(serializable: bool = True) -> None {
    with self._lock {
        if self._in_txn {
            return;
        }
        level = 'SERIALIZABLE' if serializable else 'READ COMMITTED';
        self._run(f"BEGIN ISOLATION LEVEL {level}", {});
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


impl PgStore.load(ids: list[UUID]) -> dict[UUID, AnchorRow] {
    if not ids {
        return {};
    }
    out: dict[UUID, AnchorRow] = {};
    rows = self._run(
        """
        SELECT id, kind, arch_type, arch_module, fingerprint, root_id,
               src, dst, undirected, props, xmin::text
        FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))
        """,
        {'ids': [str(i) for i in ids]}
    );
    for r in rows {
        raw_props = r[9];
        props: dict = (
            raw_props if isinstance(raw_props, dict) else json.loads(str(raw_props))
        );
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
            version=int(str(r[10]))
        );
        out[row.id] = row;
    }
    return out;
}


impl PgStore.adjacency(ids: list[UUID]) -> dict[UUID, list[UUID]] {
    if not ids {
        return {};
    }
    out: dict[UUID, list[UUID]] = {i: [] for i in ids};
    rows = self._run(
        """
        SELECT id, src, dst FROM anchors
        WHERE src = ANY(CAST(:ids AS uuid[])) OR dst = ANY(CAST(:ids AS uuid[]))
        ORDER BY seq, id
        """,
        {'ids': [str(i) for i in ids]}
    );
    for r in rows {
        eid = UUID(str(r[0]));
        for endpoint in (r[1], r[2]) {
            if endpoint is not None {
                nid = UUID(str(endpoint));
                if nid in out and eid not in out[nid] {
                    out[nid].append(eid);
                }
            }
        }
    }
    return out;
}


impl PgStore.load_versions(ids: list[UUID]) -> dict[UUID, int] {
    if not ids {
        return {};
    }
    rows = self._run(
        'SELECT id, xmin::text FROM anchors WHERE id = ANY(CAST(:ids AS uuid[]))',
        {'ids': [str(i) for i in ids]}
    );
    return {UUID(str(r[0])): int(str(r[1])) for r in rows};
}


impl PgStore.upsert(rows_in: list[AnchorRow]) -> None {
    if not rows_in {
        return;
    }
    for row in rows_in {
        self._run(
            """
            INSERT INTO anchors
                (id, kind, arch_type, arch_module, fingerprint, root_id,
                 src, dst, undirected, props, format_version, updated_at)
            VALUES
                (CAST(:id AS uuid), :kind, :arch_type, :arch_module, :fp,
                 CAST(:root_id AS uuid), CAST(:src AS uuid),
                 CAST(:dst AS uuid), :undirected, CAST(:props AS jsonb),
                 :fv, now())
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
            {
                'id': str(row.id),
                'kind': row.kind,
                'arch_type': row.arch_type,
                'arch_module': row.arch_module,
                'fp': row.fingerprint,
                'root_id': str(row.root_id) if row.root_id else None,
                'src': str(row.src) if row.src else None,
                'dst': str(row.dst) if row.dst else None,
                'undirected': row.undirected,
                'props': json.dumps(row.props, default=_jsonable),
                'fv': SCHEMA_VERSION
            }
        );
        if row.arch_type and row.arch_type not in self._known_types {
            for anc in (row.ancestry or [row.arch_type]) {
                self._run(
                    """
                    INSERT INTO graph_types (type_name, ancestor)
                    VALUES (:t, :a) ON CONFLICT DO NOTHING
                    """,
                    {'t': row.arch_type, 'a': anc}
                );
            }
            self._known_types.add(row.arch_type);
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
    conn: Any = self._side();
    conn.run('SELECT pg_notify(:c, :p)', c=channel, p=payload);
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
    stop: Any = self._listen_stop;
    if stop is None {
        return;
    }
    while not stop.is_set() {
        try {
            with self._lock {
                conn: Any = self._side();
                conn.run('SELECT 1');
                pending = list(conn.notifications);
                conn.notifications.clear();
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
        }
        stop.wait(1.0);
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
