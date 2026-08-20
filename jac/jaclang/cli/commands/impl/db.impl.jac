import os;
import from enum { StrEnum }
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.store { TxnIsolation }
import from jaclang.runtimelib.dbcatalog { DbRecord, MAINTENANCE_DB }


enum DbAction(StrEnum) {
    STATUS = 'status',
    SERVE = 'serve',
    STOP = 'stop',
    INSPECT = 'inspect',
    SQL = 'sql',
    FETCH = 'fetch',
    LIST = 'list',
    DROP = 'drop',
    PRUNE = 'prune'
}


obj PruneCandidate {
    has record: DbRecord,
        reason: str,
        force: bool = False;
}


def _parse_action(action: str) -> (DbAction | None) {
    for candidate in DbAction {
        if candidate.value == action {
            return candidate;
        }
    }
    return None;
}


def _project_data_dir(explicit: str) -> str {
    if explicit {
        return str(Path(explicit).expanduser());
    }
    import from jaclang.runtimelib.session { shared_pg_data_dir }
    return shared_pg_data_dir();
}


def _project_database -> str {
    import from jaclang.runtimelib.session { project_db_name }
    base = str(Path.cwd());
    jacs = sorted(
        p
        for p in Path.cwd().`glob("*.jac")
        if p.is_file()
    );
    target = str(jacs[0]) if len(jacs) == 1 else None;
    return project_db_name(base, target);
}


def _runtime_for(data_dir: str, tcp: bool = False, port: int = 5432) -> any {
    import from jaclang.runtimelib.pgembed { PgRuntime }
    return PgRuntime(
        data_dir=data_dir,
        tcp=tcp,
        port=port,
        database=_project_database(),
        owner_path=str(Path.cwd())
    );
}


def _catalog_runtime(data_dir: str) -> any {
    import from jaclang.runtimelib.pgembed { PgRuntime }
    return PgRuntime(data_dir=data_dir, database=MAINTENANCE_DB);
}


def _open_store(rt: any) -> any {
    import from jaclang.runtimelib.store { PgStore }
    store = PgStore(conninfo=rt.ensure());
    store.ensure_schema_once({});
    return store;
}


def _human_size(size_bytes: int) -> str {
    size = float(size_bytes);
    for unit in ['B', 'KB', 'MB', 'GB', 'TB'] {
        if size < 1024.0 or unit == 'TB' {
            return f"{size:.1f} {unit}" if unit != 'B' else f"{int(size)} B";
        }
        size /= 1024.0;
    }
    return f"{size_bytes} B";
}


def _cluster_missing(data_dir: str) -> bool {
    if os.path.isdir(data_dir) {
        return False;
    }
    console.print(f"data dir : {data_dir}");
    console.print("state    : no cluster yet (created on first `jac run`)");
    return True;
}


def _db_status(data_dir: str) -> int {
    rt = _runtime_for(data_dir);
    running = rt.is_running();
    console.print(f"data dir : {data_dir}");
    console.print(f"running  : {running}");
    if not running and not os.path.isdir(data_dir) {
        console.print("state    : no store yet (created on first `jac run`)");
        return 0;
    }
    store = _open_store(rt);
    try {
        store.begin(TxnIsolation.READ_COMMITTED);
        rows = store.rows(
            'SELECT kind, count(*) FROM anchors GROUP BY kind ORDER BY kind', {}
        );
        console.print(f"server   : PostgreSQL {store.server_version()}");
        for (kind, cnt) in rows {
            console.print(f"{kind:<12}: {cnt}");
        }
        store.commit();
    } finally {
        store.close();
    }
    return 0;
}


def _db_inspect(data_dir: str) -> int {
    rt = _runtime_for(data_dir);
    store = _open_store(rt);
    try {
        store.begin(TxnIsolation.READ_COMMITTED);
        rows = store.rows(
            """
            SELECT kind, arch_type, count(*) FROM anchors
            GROUP BY kind, arch_type ORDER BY kind, count(*) DESC
            """,
            {}
        );
        for (kind, atype, cnt) in rows {
            console.print(f"{kind:<12} {atype or '-':<24} {cnt}");
        }
        q = store.rows('SELECT count(*) FROM quarantine', {});
        console.print(f"quarantined : {q[0][0]}");
        store.commit();
    } finally {
        store.close();
    }
    return 0;
}


def _db_sql(data_dir: str, query: str) -> int {
    if not query {
        console.error("usage: jac db sql \"<statement>\"");
        return 1;
    }
    rt = _runtime_for(data_dir);
    store = _open_store(rt);
    try {
        store.begin(TxnIsolation.READ_COMMITTED);
        for row in store.rows(query, {}) {
            console.print(' | '.join(str(c) for c in row));
        }
        store.commit();
    } finally {
        store.close();
    }
    return 0;
}


def _db_fetch -> int {
    import from jaclang.runtimelib.pgembed { PgRuntime, dist_cache_dir }
    bin_dir = PgRuntime(data_dir=dist_cache_dir()).fetch_dist();
    console.success(f"embedded postgres binaries ready at {bin_dir}");
    return 0;
}


def _db_serve(data_dir: str, port: int) -> int {
    serve_dir = data_dir or os.environ.get('JAC_PGDATA') or '/var/lib/jac/pgdata';
    serve_port = int(os.environ.get('JAC_DB_PORT', str(port)));
    console.print(f"serving postgres from {serve_dir} on :{serve_port}");
    rt = _runtime_for(serve_dir, tcp=True, port=serve_port);
    return rt.serve();
}


def _db_list(data_dir: str) -> int {
    if _cluster_missing(data_dir) {
        return 0;
    }
    rt = _catalog_runtime(data_dir);
    records = rt.databases();
    total = sum(rec.size_bytes for rec in records);
    console.print(f"data dir : {data_dir}");
    console.print(f"databases: {len(records)} ({_human_size(total)})");
    if not records {
        return 0;
    }
    console.print("");
    console.print(
        f"{'NAME':<40} {'SIZE':>10}  {'KIND':<8} {'STATE':<13} {'LAST USED':<20} OWNER"
    );
    for rec in records {
        console.print(
            f"{rec.database:<40} {_human_size(rec.size_bytes):>10}  "
            f"{(rec.kind or '-'):<8} {rec.state():<13} "
            f"{(rec.last_used_at[:19] or '-'):<20} {rec.owner_path or '-'}"
        );
    }
    return 0;
}


def _prune_candidates(rt: any, records: list, empty: bool) -> list[PruneCandidate] {
    import from jaclang.runtimelib.dbcatalog { holds_no_data }
    info = rt.conninfo();
    out: list[PruneCandidate] = [];
    for rec in records {
        if rec.is_scratch() {
            if rec.is_dead_scratch() {
                out.append(
                    PruneCandidate(
                        record=rec,
                        reason=f"scratch store, {rec.dead_scratch_reason()}",
                        force=rec.pid_confirmed_dead()
                    )
                );
            }
            continue;
        }
        if rec.is_orphaned() {
            out.append(
                PruneCandidate(record=rec, reason=f"owner {rec.owner_path} is gone")
            );
            continue;
        }
        if empty and not rec.owner_path and holds_no_data(info, rec.database) {
            out.append(
                PruneCandidate(record=rec, reason="no recorded owner and no data")
            );
        }
    }
    return out;
}


def _db_prune(data_dir: str, yes: bool, empty: bool) -> int {
    if _cluster_missing(data_dir) {
        return 0;
    }
    import from jaclang.runtimelib.dbcatalog {
        condemn_stale_scratch,
        connect_admin,
        drop_database,
        drop_if_still_dead,
        list_databases
    }
    rt = _catalog_runtime(data_dir);
    conn: any = connect_admin(rt.ensure());
    try {
        records = list_databases(conn);
        candidates = _prune_candidates(rt, records, empty);
        marked = condemn_stale_scratch(conn, records) if yes else [];
        unattributed = len(
            [
                rec
                for rec in records
                if not rec.owner_path and not rec.is_scratch()
            ]
        );
        console.print(f"data dir : {data_dir}");
        if not candidates and not marked {
            console.print("nothing to prune");
        }
        for name in marked {
            console.print(
                f"marked {name}: its heartbeat stopped, so a later prune will "
                "reclaim it if it is still silent and unused by then"
            );
        }
        reclaim = 0;
        dropped = 0;
        for cand in candidates {
            rec = cand.record;
            reclaim += rec.size_bytes;
            if not yes {
                console.print(
                    f"would drop {rec.database} ({_human_size(rec.size_bytes)}): "
                    f"{cand.reason}"
                );
                continue;
            }
            gone = (
                drop_if_still_dead(conn, rec.database)
                    if rec.is_scratch()
                    else drop_database(conn, rec.database, force=cand.force)
            );
            if gone {
                dropped += 1;
                console.print(
                    f"dropped {rec.database} ({_human_size(rec.size_bytes)}): "
                    f"{cand.reason}"
                );
            } else {
                console.warning(
                    f"could not drop {rec.database}; it may still be in use"
                );
            }
        }
        if candidates and not yes {
            console.print(
                f"{len(candidates)} database(s), {_human_size(reclaim)} reclaimable; "
                "re-run with -y to drop them"
            );
        } elif dropped {
            console.success(
                f"dropped {dropped} database(s), reclaimed {_human_size(reclaim)}"
            );
        }
        if unattributed and not empty {
            console.print(
                f"{unattributed} database(s) have no recorded owner and were left "
                "alone; `jac db prune --empty` also considers the ones holding no "
                "data, and `jac db drop <name>` handles the rest"
            );
        }
    } finally {
        conn.close();
    }
    return 0;
}


def _db_drop(data_dir: str, database: str, yes: bool) -> int {
    import from jaclang.runtimelib.dbcatalog { is_jac_database }
    if not database {
        console.error("usage: jac db drop <database> -y");
        return 1;
    }
    if not is_jac_database(database) {
        console.error(
            f"{database} is not a jac database; only jac_* databases can be dropped"
        );
        return 1;
    }
    if _cluster_missing(data_dir) {
        return 1;
    }
    rt = _catalog_runtime(data_dir);
    known = {rec.database: rec for rec in rt.databases()};
    if database not in known {
        console.error(f"no such database in {data_dir}: {database}");
        return 1;
    }
    rec = known[database];
    if not yes {
        console.print(
            f"would drop {database} ({_human_size(rec.size_bytes)}, "
            f"{rec.state()}, owner {rec.owner_path or 'unknown'}); "
            "re-run with -y to drop it"
        );
        return 0;
    }
    if not rt.drop_database(database) {
        console.error(
            f"could not drop {database}; another process may still be connected"
        );
        return 1;
    }
    console.success(f"dropped {database} ({_human_size(rec.size_bytes)})");
    return 0;
}


impl db(
    action: str = "status",
    query: str = "",
    data_dir: str = "",
    port: int = 5432,
    yes: bool = False,
    empty: bool = False
) -> int {
    verb = _parse_action(action);
    if verb is None {
        console.error(f"unknown action: {action}");
        return 1;
    }
    if verb == DbAction.SERVE {
        return _db_serve(data_dir, port);
    }
    if verb == DbAction.FETCH {
        return _db_fetch();
    }
    dd = _project_data_dir(data_dir);
    if verb == DbAction.STATUS {
        return _db_status(dd);
    }
    if verb == DbAction.INSPECT {
        return _db_inspect(dd);
    }
    if verb == DbAction.SQL {
        return _db_sql(dd, query);
    }
    if verb == DbAction.LIST {
        return _db_list(dd);
    }
    if verb == DbAction.DROP {
        return _db_drop(dd, query, yes);
    }
    if verb == DbAction.PRUNE {
        return _db_prune(dd, yes, empty);
    }
    rt = _runtime_for(dd);
    if rt.is_running() {
        rt.stop();
        console.print("stopped");
    } else {
        console.print("not running");
    }
    return 0;
}
