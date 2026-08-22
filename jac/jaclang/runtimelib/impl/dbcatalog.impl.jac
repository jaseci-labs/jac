import os;
import platform;
import from threading { Event, Lock, Thread }

glob _heartbeats: dict[str, any] = {},
     _heartbeat_lock = Lock(),
     _HEARTBEAT_WARN_AFTER_SECONDS = 300;


def _registry_ddl -> str {
    return f"""
        CREATE TABLE IF NOT EXISTS {REGISTRY_TABLE} (
            database          text PRIMARY KEY,
            kind              text NOT NULL DEFAULT '{DbKind.PROJECT.value}',
            owner_path        text NOT NULL DEFAULT '',
            host              text NOT NULL DEFAULT '',
            pid               integer NOT NULL DEFAULT 0,
            created_at        timestamptz NOT NULL DEFAULT now(),
            last_used_at      timestamptz NOT NULL DEFAULT now(),
            last_heartbeat_at timestamptz NOT NULL DEFAULT now(),
            condemned_at      timestamptz
        )
        """;
}


def _heartbeat_column_ddl -> list[str] {
    return [
        f"""
        ALTER TABLE {REGISTRY_TABLE}
        ADD COLUMN IF NOT EXISTS last_heartbeat_at timestamptz NOT NULL DEFAULT now()
        """,
        f"""
        ALTER TABLE {REGISTRY_TABLE}
        ADD COLUMN IF NOT EXISTS condemned_at timestamptz
        """
    ];
}


impl this_host -> str {
    return platform.`node() or '';
}


impl is_jac_database(database: str) -> bool {
    if not database.startswith(DB_PREFIX) or len(database) <= len(DB_PREFIX) {
        return False;
    }
    for ch in database {
        if not (ch.isalnum() or ch == '_') {
            return False;
        }
    }
    return True;
}


impl sqlstate_of(err: Exception) -> str {
    for arg in getattr(err, 'args', ()) {
        if isinstance(arg, dict) {
            return str(arg.get('C') or '');
        }
    }
    return '';
}


impl holds_no_data(info: ConnInfo, database: str) -> bool {
    import from jaclang.jac0core.constant { Constants as Con }
    import from jaclang.vendor.pgload { connect }
    try {
        conn: any = connect(
            info.user,
            host=info.host,
            port=info.port,
            unix_socket_dir=info.unix_socket_dir,
            database=database,
            password=info.password or None
        );
    } except Exception as e {
        logger.warning(f"could not inspect {database}: {e}");
        return False;
    }
    try {
        listed = conn.run(
            'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()'
        )
            or [];
        tables = [str(row[0]) for row in listed];
        for table in sorted(tables) {
            if table in DERIVED_TABLES {
                continue;
            }
            if table == 'anchors' {
                rows = conn.run(
                    'SELECT count(*) FROM anchors WHERE id::text <> :sysroot',
                    sysroot=str(Con.SUPER_ROOT_UUID)
                );
            } elif table == 'kv_state' {
                rows = conn.run(
                    'SELECT count(*) FROM kv_state WHERE key <> :stamp',
                    stamp=SCHEMA_STAMP_KEY
                );
            } else {
                rows = conn.run(f'SELECT count(*) FROM "{table}"');
            }
            if int(rows[0][0]) > 0 {
                return False;
            }
        }
        return True;
    } except Exception as e {
        if sqlstate_of(e) == '42P01' {
            return True;
        }
        logger.warning(f"could not inspect {database}: {e}");
        return False;
    } finally {
        conn.close();
    }
}


impl admin_conninfo(info: ConnInfo) -> ConnInfo {
    return ConnInfo(
        host=info.host,
        port=info.port,
        user=info.user,
        password=info.password,
        database=MAINTENANCE_DB,
        unix_socket_dir=info.unix_socket_dir
    );
}


impl connect_admin(info: ConnInfo) -> any {
    import from jaclang.vendor.pgload { connect }
    admin = admin_conninfo(info);
    return connect(
        admin.user,
        host=admin.host,
        port=admin.port,
        unix_socket_dir=admin.unix_socket_dir,
        database=admin.database,
        password=admin.password or None
    );
}


impl ensure_registry(conn: any) -> bool {
    try {
        conn.run(_registry_ddl());
        for stmt in _heartbeat_column_ddl() {
            conn.run(stmt);
        }
        return True;
    } except Exception as e {
        logger.debug(f"database registry unavailable: {e}");
        return False;
    }
}


impl record_database(conn: any, database: str, kind: DbKind, owner_path: str) -> None {
    if not is_jac_database(database) {
        return;
    }
    sql = f"""
        INSERT INTO {REGISTRY_TABLE}
            (database, kind, owner_path, host, pid)
        VALUES (:db, :kind, :owner, :host, :pid)
        ON CONFLICT (database) DO UPDATE SET
            last_used_at = now(),
            last_heartbeat_at = now(),
            condemned_at = NULL,
            kind = excluded.kind,
            host = excluded.host,
            pid = excluded.pid,
            owner_path = CASE
                WHEN excluded.owner_path <> '' THEN excluded.owner_path
                ELSE {REGISTRY_TABLE}.owner_path
            END
        """;
    params = {
        'db': database,
        'kind': str(kind.value),
        'owner': owner_path,
        'host': this_host(),
        'pid': os.getpid()
    };
    try {
        conn.run(sql, **params);
        return;
    } except Exception as e {
        logger.debug(f"{REGISTRY_TABLE} not writable yet ({e}); creating it");
    }
    if not ensure_registry(conn) {
        return;
    }
    try {
        conn.run(sql, **params);
    } except Exception as e {
        logger.debug(f"could not record {database} in {REGISTRY_TABLE}: {e}");
    }
}


impl forget_database(conn: any, database: str) -> None {
    try {
        conn.run(f"DELETE FROM {REGISTRY_TABLE} WHERE database = :db", db=database);
    } except Exception as e {
        logger.debug(f"could not forget {database}: {e}");
    }
}


def _records_sql(predicate: str) -> str {
    return f"""
        SELECT d.datname,
               pg_database_size(d.datname),
               r.database IS NOT NULL,
               coalesce(r.kind, ''),
               coalesce(r.owner_path, ''),
               coalesce(r.host, ''),
               coalesce(r.pid, 0),
               coalesce(r.created_at::text, ''),
               coalesce(r.last_used_at::text, ''),
               floor(extract(epoch FROM now() - r.last_heartbeat_at))::bigint,
               EXISTS (
                   SELECT 1 FROM pg_stat_activity a WHERE a.datname = d.datname
               ),
               floor(extract(epoch FROM now() - r.condemned_at))::bigint
        FROM pg_database d
        LEFT JOIN {REGISTRY_TABLE} r ON r.database = d.datname
        WHERE {predicate} AND NOT d.datistemplate
        ORDER BY d.datname
        """;
}


def _age_of(raw: any) -> int {
    return int(raw) if raw is not None else -1;
}


def _record_of(row: any) -> DbRecord {
    return DbRecord(
        database=str(row[0]),
        size_bytes=int(row[1] or 0),
        recorded=bool(row[2]),
        kind=str(row[3] or ''),
        owner_path=str(row[4] or ''),
        host=str(row[5] or ''),
        pid=int(row[6] or 0),
        created_at=str(row[7] or ''),
        last_used_at=str(row[8] or ''),
        heartbeat_age_seconds=_age_of(row[9]),
        has_sessions=bool(row[10]),
        condemned_age_seconds=_age_of(row[11])
    );
}


impl list_databases(conn: any) -> list[DbRecord] {
    ensure_registry(conn);
    rows = conn.run(
        _records_sql('d.datname LIKE :pattern'),
        pattern=DB_PREFIX.replace('_', '\\_') + '%'
    )
        or [];
    return [_record_of(row) for row in rows];
}


impl load_record(conn: any, database: str) -> (DbRecord | None) {
    try {
        rows = conn.run(_records_sql('d.datname = :db'), db=database) or [];
    } except Exception as e {
        logger.debug(f"could not re-read the registry row for {database}: {e}");
        return None;
    }
    return _record_of(rows[0]) if rows else None;
}


impl drop_database(conn: any, database: str, force: bool = False) -> bool {
    assert is_jac_database(database) , (
        f"refusing to drop {database!r}: only jac-owned databases "
        f"(named {DB_PREFIX}*) can be dropped"
    );
    suffix = ' WITH (FORCE)' if force else '';
    try {
        conn.run(f'DROP DATABASE IF EXISTS "{database}"{suffix}');
    } except Exception as e {
        logger.debug(f"could not drop {database}: {e}");
        return False;
    }
    forget_database(conn, database);
    return True;
}


impl process_alive(host: str, pid: int) -> bool {
    if pid <= 0 {
        return False;
    }
    if host and host != this_host() {
        return True;
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except PermissionError {
        return True;
    } except OSError {
        return True;
    }
}


impl dead_scratch_databases(records: list[DbRecord]) -> list[str] {
    return [
        rec.database
        for rec in records
        if rec.is_dead_scratch()
    ];
}


impl touch_heartbeat(conn: any, database: str) -> bool {
    try {
        conn.run(
            f"UPDATE {REGISTRY_TABLE} "
            "SET last_heartbeat_at = now(), condemned_at = NULL "
            "WHERE database = :db",
            db=database
        );
        return True;
    } except Exception as e {
        logger.debug(f"could not refresh the heartbeat for {database}: {e}");
        return False;
    }
}


impl condemn_stale_scratch(conn: any, records: list[DbRecord]) -> list[str] {
    marked: list[str] = [];
    for rec in records {
        if not rec.looks_abandoned() or rec.condemned_age_seconds >= 0 {
            continue;
        }
        try {
            conn.run(
                f"UPDATE {REGISTRY_TABLE} SET condemned_at = now() "
                "WHERE database = :db AND condemned_at IS NULL",
                db=rec.database
            );
            marked.append(rec.database);
        } except Exception as e {
            logger.debug(f"could not condemn {rec.database}: {e}");
        }
    }
    return marked;
}


impl drop_if_still_dead(conn: any, database: str) -> bool {
    fresh = load_record(conn, database);
    if fresh is None {
        return False;
    }
    if not fresh.is_dead_scratch() {
        logger.info(
            f"left {database} alone; its owner accounted for it before the drop"
        );
        return False;
    }
    return drop_database(conn, database, force=fresh.pid_confirmed_dead());
}


def _heartbeat_once(info: ConnInfo, database: str) -> bool {
    conn: (any | None) = None;
    try {
        conn = connect_admin(info);
        return touch_heartbeat(conn, database);
    } except Exception as e {
        logger.debug(f"heartbeat for {database} could not reach the registry: {e}");
        return False;
    } finally {
        if conn is not None {
            try {
                conn.close();
            } except Exception { }
        }
    }
}


def _heartbeat_loop(info: ConnInfo, database: str, stop: any) {
    failures = 0;
    warnings = 0;
    while not stop.`wait(SCRATCH_HEARTBEAT_SECONDS) {
        if _heartbeat_once(info, database) {
            if warnings > 0 {
                logger.warning(
                    f"heartbeat for the scratch database {database} recovered after "
                    f"{failures} failed attempt(s)"
                );
            }
            failures = 0;
            warnings = 0;
            continue;
        }
        failures += 1;
        silent = failures * SCRATCH_HEARTBEAT_SECONDS;
        if warnings == 0 and silent >= _HEARTBEAT_WARN_AFTER_SECONDS {
            warnings = 1;
            logger.warning(
                f"could not heartbeat the scratch database {database} for "
                f"{silent // 60} minute(s); the registry cannot tell that this "
                "process is alive while that lasts"
            );
        } elif warnings == 1 and silent >= UNREACHABLE_HOST_GRACE_SECONDS {
            warnings = 2;
            logger.warning(
                f"the scratch database {database} has not been heartbeated for "
                f"{silent // 60} minute(s); a jac process on another host may now "
                "mark it for reclamation, and will reclaim it if it is still "
                "silent and unused when it looks again"
            );
        }
    }
}


impl start_heartbeat(info: ConnInfo, database: str) -> None {
    if not is_jac_database(database) {
        return;
    }
    stop = Event();
    with _heartbeat_lock {
        if database in _heartbeats {
            return;
        }
        _heartbeats[database] = stop;
    }
    Thread(
        target=_heartbeat_loop,
        args=(info, database, stop),
        daemon=True,
        name='jac-db-heartbeat'
    ).start();
}


impl stop_heartbeat(database: str) -> None {
    with _heartbeat_lock {
        stop = _heartbeats.pop(database, None);
    }
    if stop is not None {
        stop.set();
    }
}


impl expired_databases(conn: any, days: int, keep: str) -> list[str] {
    if days <= 0 {
        return [];
    }
    if not ensure_registry(conn) {
        return [];
    }
    rows = conn.run(
        f"""
        SELECT r.database FROM {REGISTRY_TABLE} r
        JOIN pg_database d ON d.datname = r.database
        WHERE r.last_used_at < now() - make_interval(days => :days)
          AND r.database <> :keep
        ORDER BY r.database
        """,
        days=days,
        keep=keep
    )
        or [];
    return [
        str(row[0])
        for row in rows
        if is_jac_database(str(row[0]))
    ];
}


impl DbRecord.is_scratch -> bool {
    return self.kind == DbKind.SCRATCH.value
        or self.database.startswith(SCRATCH_PREFIX);
}


impl DbRecord.is_tracked_scratch -> bool {
    return self.is_scratch() and self.recorded and self.pid > 0;
}


impl DbRecord.is_dead_scratch -> bool {
    if not self.is_tracked_scratch() {
        return False;
    }
    if self.pid_confirmed_dead() {
        return True;
    }
    return self.looks_abandoned()
        and self.condemned_age_seconds >= SCRATCH_CONDEMN_SEPARATION_SECONDS;
}


impl DbRecord.pid_confirmed_dead -> bool {
    return not process_alive(self.host, self.pid);
}


impl DbRecord.heartbeat_stopped -> bool {
    if self.heartbeat_age_seconds < 0 {
        return False;
    }
    checkable = not self.host or self.host == this_host();
    grace = LIVE_PID_GRACE_SECONDS if checkable else UNREACHABLE_HOST_GRACE_SECONDS;
    return self.heartbeat_age_seconds >= grace;
}


impl DbRecord.looks_abandoned -> bool {
    return self.is_tracked_scratch()
        and self.heartbeat_stopped()
        and not self.has_sessions;
}


impl DbRecord.dead_scratch_reason -> str {
    if self.pid_confirmed_dead() {
        return f"its process (pid {self.pid}) is gone";
    }
    return (
        f"nothing is connected to it, nothing has heartbeated it for "
        f"{self.heartbeat_age_seconds // 60} minute(s), and it was already found "
        f"that way {self.condemned_age_seconds // 60} minute(s) ago "
        f"(recorded pid {self.pid} on {self.host or 'this host'})"
    );
}


impl DbRecord.is_orphaned -> bool {
    if not self.recorded or self.is_scratch() or not self.owner_path {
        return False;
    }
    return not os.path.isdir(self.owner_path);
}


impl DbRecord.state -> str {
    if self.is_scratch() {
        if self.is_dead_scratch() {
            return 'dead scratch';
        }
        return 'silent scratch' if self.looks_abandoned() else 'scratch';
    }
    if not self.recorded {
        return 'unattributed';
    }
    if not self.owner_path {
        return 'unknown owner';
    }
    return 'orphaned' if self.is_orphaned() else 'live';
}
