import os;
import from pathlib { Path }
import from typing { Any }
import from jaclang.cli.console { console }


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
        for p in Path.cwd().glob("*.jac")
        if p.is_file()
    );
    target = str(jacs[0]) if len(jacs) == 1 else None;
    return project_db_name(base, target);
}


def _runtime_for(data_dir: str, tcp: bool = False, port: int = 5432) -> Any {
    import from jaclang.runtimelib.pgembed { PgRuntime }
    return PgRuntime(
        data_dir=data_dir, tcp=tcp, port=port, database=_project_database()
    );
}


def _open_store(rt: Any) -> Any {
    import from jaclang.runtimelib.store { PgStore }
    store = PgStore(conninfo=rt.ensure());
    store.ensure_schema({});
    return store;
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
        store.begin(serializable=False);
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
        store.begin(serializable=False);
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
        store.begin(serializable=False);
        for row in store.rows(query, {}) {
            console.print(' | '.join(str(c) for c in row));
        }
        store.commit();
    } finally {
        store.close();
    }
    return 0;
}


def _db_serve(data_dir: str, port: int) -> int {
    serve_dir = data_dir or os.environ.get('JAC_PGDATA') or '/var/lib/jac/pgdata';
    serve_port = int(os.environ.get('JAC_DB_PORT', str(port)));
    console.print(f"serving postgres from {serve_dir} on :{serve_port}");
    rt = _runtime_for(serve_dir, tcp=True, port=serve_port);
    return rt.serve();
}


impl db(
    action: str = "status", query: str = "", data_dir: str = "", port: int = 5432
) -> int {
    if action == 'serve' {
        return _db_serve(data_dir, port);
    }
    dd = _project_data_dir(data_dir);
    if action == 'status' {
        return _db_status(dd);
    }
    if action == 'inspect' {
        return _db_inspect(dd);
    }
    if action == 'sql' {
        return _db_sql(dd, query);
    }
    if action == 'stop' {
        rt = _runtime_for(dd);
        if rt.is_running() {
            rt.stop();
            console.print("stopped");
        } else {
            console.print("not running");
        }
        return 0;
    }
    console.error(f"unknown action: {action}");
    return 1;
}
