"""Lifecycle contracts for the shared embedded Postgres cluster (issue #8094).

The runtime creates one database per absolute project path in a cluster shared
by the whole machine. Before these contracts existed databases were only ever
created: internal work (deploy staging, test workers) minted permanent
databases keyed to temp paths, and nothing could ever drop one.

Every test owns an isolated cluster under a temp dir, so nothing here touches
the developer's shared cluster at ~/.cache/jac/pg/main.
"""

import io;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.data.pgembed { PgRuntime }

glob APP = "node Item {\n"
     "    has name: str;\n"
     "}\n"
     "\n"
     "with entry {\n"
     "    root ++> Item(name=\"x\");\n"
     "    print(\"items\", len([root-->]));\n"
     "}\n",
     # Reads root and writes nothing, so the database exists but holds only the
     # system root. It has to touch the graph at all: since #8101 the embedded
     # Postgres boots lazily, so a program that merely prints creates no
     # database for these fixtures to find.
     BARE_APP = "with entry {\n    print(\"items\", len([root-->]));\n}\n";


obj Cluster {
    has cache_home: str,
        data_dir: str,
        workspace: str,
        rt: any,
        bin_dir: str;
}


"""Point a directory at the source tree under test: the launcher otherwise
serves its own embedded jaclang snapshot to child processes."""
def _write_jac_toml(directory: str, name: str) {
    import jaclang;
    src = str(Path(jaclang.__file__).parent.parent);
    Path(os.path.join(directory, "jac.toml")).write_text(
        f"[project]\nname = \"{name}\"\n\n[dev]\njaclang_source = \"{src}\"\n"
    );
}


"""Boot a private cluster whose layout matches $JAC_CACHE_HOME/pg/main."""
def _start_cluster -> Cluster {
    cache_home = tempfile.mkdtemp(prefix="jac-dblife-");
    data_dir = os.path.join(cache_home, "pg", "main");
    workspace = os.path.join(cache_home, "ws");
    os.makedirs(workspace);
    _write_jac_toml(workspace, "dblifews");
    rt = PgRuntime(data_dir=data_dir, database="postgres");
    rt.ensure();
    return Cluster(
        cache_home=cache_home,
        data_dir=data_dir,
        workspace=workspace,
        rt=rt,
        bin_dir=str(rt._bin_dir or "")
    );
}


def _stop_cluster(cluster: Cluster) {
    try {
        cluster.rt.stop();
    } except Exception {}
    shutil.rmtree(cluster.cache_home, ignore_errors=True);
}


def _admin(cluster: Cluster) -> any {
    import from jaclang.data.pgload { connect }
    info = cluster.rt.conninfo();
    return connect(
        info.user,
        host=info.host,
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database="postgres"
    );
}


def _query(cluster: Cluster, sql: str) -> list {
    conn: any = _admin(cluster);
    try {
        return conn.run(sql);
    } finally {
        conn.close();
    }
}


def _exec(cluster: Cluster, sql: str) {
    conn: any = _admin(cluster);
    try {
        conn.run(sql);
    } finally {
        conn.close();
    }
}


def _exec_in(cluster: Cluster, database: str, sql: str) {
    import from jaclang.data.pgload { connect }
    info = cluster.rt.conninfo();
    conn: any = connect(
        info.user,
        host=info.host,
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=database
    );
    try {
        conn.run(sql);
    } finally {
        conn.close();
    }
}


def _jac_databases(cluster: Cluster) -> set[str] {
    return {
        str(r[0])
        for r in _query(
            cluster, "SELECT datname FROM pg_database WHERE datname LIKE 'jac\\_%'"
        )
    };
}


"""A project directory whose app writes one node into its own store."""
def _seed_project(name: str, app: str = "") -> str {
    proj = tempfile.mkdtemp(prefix=f"jac-{name}-");
    Path(os.path.join(proj, "app.jac")).write_text(app or APP);
    _write_jac_toml(proj, name);
    return proj;
}


def _child_env(cluster: Cluster, scratch: bool) -> dict {
    import jaclang;
    env = dict(os.environ);
    src = str(Path(jaclang.__file__).parent.parent);
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "");
    env["JAC_CACHE_HOME"] = cluster.cache_home;
    env["JAC_PG_DIST"] = cluster.bin_dir;
    env.pop("JAC_DB_URL", None);
    if scratch {
        env["JAC_DB_SCRATCH"] = "1";
    } else {
        env.pop("JAC_DB_SCRATCH", None);
    }
    return env;
}


"""Run `jac run app.jac` inside *proj* against *cluster*."""
def _run_app(cluster: Cluster, proj: str, scratch: bool = False) -> tuple {
    res = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(proj, "app.jac")],
        cwd=proj,
        env=_child_env(cluster, scratch),
        capture_output=True,
        text=True,
        timeout=600
    );
    return (res.returncode, res.stdout, res.stderr);
}


def _run_python(cluster: Cluster, script: str) -> tuple {
    res = subprocess.run(
        [sys.executable, "-c", script],
        cwd=cluster.workspace,
        env=_child_env(cluster, False),
        capture_output=True,
        text=True,
        timeout=600
    );
    return (res.returncode, res.stdout, res.stderr);
}


"""Run an app in a fresh project and return the database it created."""
def _project_database(cluster: Cluster, name: str, app: str = "") -> tuple[str, str] {
    before = _jac_databases(cluster);
    proj = _seed_project(name, app=app);
    (rc, out, err) = _run_app(cluster, proj);
    assert rc == 0 , f"run in {proj} failed: {err}";
    created = _jac_databases(cluster) - before;
    assert len(created) == 1 , f"expected one new database, got {created}";
    return (proj, sorted(created)[0]);
}


def _capture(body: any) -> tuple[int, str] {
    captured = io.StringIO();
    saved = sys.stdout;
    sys.stdout = captured;
    try {
        code = body();
    } finally {
        sys.stdout = saved;
    }
    return (int(code), captured.getvalue());
}


test "a scratch-mode run leaves no permanent database behind" {
    cluster = _start_cluster();
    scratch_proj = _seed_project("scratchrun");
    try {
        (proj, db_name) = _project_database(cluster, "plainrun");
        before = _jac_databases(cluster);

        (rc, out, err) = _run_app(cluster, scratch_proj, scratch=True);
        assert rc == 0 , f"scratch run failed: {err}";
        assert "items 1" in out , f"the scratch run never opened a store: {out!r}";

        names = _jac_databases(cluster);
        assert names == before , (
            f"internal (scratch) work left permanent databases behind: "
            f"{names - before}"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        shutil.rmtree(scratch_proj, ignore_errors=True);
        _stop_cluster(cluster);
    }
}


test "marked scratch bases share one database that dies with the process" {
    cluster = _start_cluster();
    script = (
        "import tempfile;"
        "from jaclang.server.session import mark_scratch_base;"
        "from jaclang.runtime.context import ExecutionContext;"
        "b1 = tempfile.mkdtemp(); b2 = tempfile.mkdtemp();"
        "mark_scratch_base(b1); mark_scratch_base(b2);"
        "c1 = ExecutionContext(base_path_dir=b1);"
        "print('LOC', c1.mem.data_location());"
        "c1.mem.store.kv_put('probe', 'kept');"
        "print('PROBE', c1.mem.store.kv_get('probe'));"
        "c1.close();"
        "c2 = ExecutionContext(base_path_dir=b2);"
        "print('LOC', c2.mem.data_location());"
        "print('PROBE', c2.mem.store.kv_get('probe'));"
        "c2.close()"
    );
    try {
        before = _jac_databases(cluster);
        (rc, out, err) = _run_python(cluster, script);
        assert rc == 0 , f"scratch-base child failed: {err}";
        locs = [
            line.split(" ", 1)[1]
            for line in out.splitlines()
            if line.startswith("LOC ")
        ];
        probes = [
            line.split(" ", 1)[1]
            for line in out.splitlines()
            if line.startswith("PROBE ")
        ];
        assert len(locs) == 2 and len(probes) == 2 , f"child printed {out!r}";
        assert "jac_scratch" in locs[0] , (
            f"a marked scratch base must not open a project database: {locs[0]}"
        );
        assert locs[0] == locs[1] , (
            f"every scratch base in one process shares one database: {locs}"
        );
        assert probes[0] == "kept" , f"the scratch store did not persist a write: {probes}";
        assert probes[1] == "None" , (
            f"a new scratch base must start empty, the way a fresh path did: {probes}"
        );
        names = _jac_databases(cluster);
        assert names == before , f"the scratch database outlived its process: {names}";
    } finally {
        _stop_cluster(cluster);
    }
}


test "opening a scratch store reaps scratch databases of dead processes" {
    import from jaclang.data.dbcatalog { DbKind, REGISTRY_TABLE }
    cluster = _start_cluster();
    scratch_proj = _seed_project("selfheal");
    dead = subprocess.Popen([sys.executable, "-c", "pass"]);
    dead.`wait();
    orphan = f"jac_scratch_{dead.pid}_crash";
    try {
        # A process killed hard (no atexit) leaves its scratch database behind.
        _exec(cluster, f'CREATE DATABASE "{orphan}"');
        _exec(
            cluster,
            f"INSERT INTO {REGISTRY_TABLE} (database, kind, owner_path, host, pid) "
            f"VALUES ('{orphan}', '{DbKind.SCRATCH.value}', '', "
            f"'{os.uname().nodename}', {dead.pid})"
        );
        (rc, out, err) = _run_app(cluster, scratch_proj, scratch=True);
        assert rc == 0 , f"scratch run failed: {err}";
        assert orphan not in _jac_databases(cluster) , (
            f"the next scratch store must reclaim {orphan}, whose process is gone"
        );
    } finally {
        shutil.rmtree(scratch_proj, ignore_errors=True);
        _stop_cluster(cluster);
    }
}


test "a new scratch base starts empty in every table, not just the core ones" {
    cluster = _start_cluster();
    # jac-scale keeps identities and jobs in tables the core schema never
    # names (jac_docs). A fresh temp path used to hand every test a brand new
    # database, so anything a plugin wrote was gone too; reusing one scratch
    # database only matches that if the wipe covers the whole schema.
    script = (
        "import tempfile;"
        "from jaclang.server.session import mark_scratch_base;"
        "from jaclang.runtime.context import ExecutionContext;"
        "b1 = tempfile.mkdtemp(); b2 = tempfile.mkdtemp();"
        "mark_scratch_base(b1); mark_scratch_base(b2);"
        "c1 = ExecutionContext(base_path_dir=b1);"
        "s = c1.mem.store;"
        "s.rows('CREATE TABLE IF NOT EXISTS plugin_docs (id text PRIMARY KEY)', {});"
        "s.rows(\"INSERT INTO plugin_docs (id) VALUES ('user1')\", {});"
        "print('ROWS', len(s.rows('SELECT id FROM plugin_docs', {})));"
        "c1.close();"
        "c2 = ExecutionContext(base_path_dir=b2);"
        "print('ROWS', len(c2.mem.store.rows('SELECT id FROM plugin_docs', {})));"
        "c2.close()"
    );
    try {
        (rc, out, err) = _run_python(cluster, script);
        assert rc == 0 , f"scratch-base child failed: {err}";
        counts = [
            line.split(" ", 1)[1]
            for line in out.splitlines()
            if line.startswith("ROWS ")
        ];
        assert counts == ["1", "0"] , (
            f"a plugin table must survive its own base and be empty for the "
            f"next one: {counts} ({out!r})"
        );
    } finally {
        _stop_cluster(cluster);
    }
}


test "a created database records its owning absolute path" {
    import from jaclang.data.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "owned");
        rows = _query(
            cluster,
            f"SELECT owner_path, kind FROM {REGISTRY_TABLE} "
            f"WHERE database = '{db_name}'"
        );
        assert len(rows) == 1 , (
            f"{db_name} recorded no owner in {REGISTRY_TABLE}: {rows}"
        );
        assert str(rows[0][0]) in (os.path.abspath(proj), os.path.realpath(proj)) , (
            f"recorded owner {rows[0][0]!r} is not {proj!r}"
        );
        assert str(rows[0][1]) == "project" , f"kind was {rows[0][1]!r}";
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db list reports every database without creating one" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "listed");
        before = _jac_databases(cluster);

        (code, text) = _capture(
            lambda { db.db(action="list", data_dir=cluster.data_dir); }
        );
        assert code == 0 , f"db list failed: {text}";
        assert db_name in text , f"db list omitted {db_name}: {text}";
        assert os.path.abspath(proj) in text or os.path.realpath(proj) in text , (
            f"db list omitted the owning path {proj}: {text}"
        );
        assert _jac_databases(cluster) == before , (
            "db list created a database as a side effect"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune drops orphaned databases only, and only when told to" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (gone, gone_db) = _project_database(cluster, "gone");
        (kept, kept_db) = _project_database(cluster, "kept");
        shutil.rmtree(gone, ignore_errors=True);

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir); }
        );
        assert code == 0 , f"db prune (dry run) failed: {text}";
        assert gone_db in text , f"the dry run did not name {gone_db}: {text}";
        assert kept_db not in text , (
            f"the dry run named the live project {kept_db}: {text}"
        );
        assert gone_db in _jac_databases(cluster) , "a dry run must not drop anything";

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        names = _jac_databases(cluster);
        assert gone_db not in names , f"{gone_db} survived prune: {names}";
        assert kept_db in names , (
            f"prune dropped {kept_db} whose owning path still exists: {names}"
        );
        shutil.rmtree(kept, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune reaps a scratch database whose process is gone" {
    import from jaclang.cli.commands { db }
    import from jaclang.data.dbcatalog { DbKind, REGISTRY_TABLE }
    cluster = _start_cluster();
    dead = subprocess.Popen([sys.executable, "-c", "pass"]);
    dead.`wait();
    orphan = f"jac_scratch_{dead.pid}_dead";
    try {
        _exec(cluster, f'CREATE DATABASE "{orphan}"');
        _exec(
            cluster,
            f"INSERT INTO {REGISTRY_TABLE} "
            "(database, kind, owner_path, host, pid) "
            f"VALUES ('{orphan}', '{DbKind.SCRATCH.value}', "
            f"'', '{os.uname().nodename}', {dead.pid})"
        );
        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        assert orphan not in _jac_databases(cluster) , (
            f"{orphan} belongs to dead pid {dead.pid} and must be reaped: {text}"
        );
    } finally {
        _stop_cluster(cluster);
    }
}


test "db prune --empty reclaims pre-tracking databases that hold no data" {
    import from jaclang.cli.commands { db }
    import from jaclang.data.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (with_data, data_db) = _project_database(cluster, "legacydata");
        (no_data, bare_db) = _project_database(cluster, "legacybare", app=BARE_APP);
        # A store whose only content is a plugin's own table (jac-scale keeps
        # identities and jobs in jac_docs) is not empty either.
        (plugin, plugin_db) = _project_database(cluster, "legacyplugin", app=BARE_APP);
        _exec_in(
            cluster,
            plugin_db,
            "CREATE TABLE IF NOT EXISTS jac_docs (id text PRIMARY KEY)"
        );
        _exec_in(cluster, plugin_db, "INSERT INTO jac_docs (id) VALUES ('user1')");
        # Databases created before owner tracking have no registry row at all.
        _exec(
            cluster,
            f"DELETE FROM {REGISTRY_TABLE} WHERE database IN "
            f"('{data_db}', '{bare_db}', '{plugin_db}')"
        );

        (code, text) = _capture(
            lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
        );
        assert code == 0 , f"db prune -y failed: {text}";
        assert bare_db in _jac_databases(cluster) , (
            "plain prune must leave unattributed databases alone"
        );

        (code, text) = _capture(
            lambda { db.db(
                action="prune", data_dir=cluster.data_dir, yes=True, empty=True
            ); }
        );
        assert code == 0 , f"db prune --empty -y failed: {text}";
        names = _jac_databases(cluster);
        assert bare_db not in names , (
            f"{bare_db} holds no data and --empty should reclaim it: {text}"
        );
        assert data_db in names , (
            f"{data_db} holds user data and must survive --empty: {text}"
        );
        assert plugin_db in names , (
            f"{plugin_db} holds plugin rows and must survive --empty: {text}"
        );
        shutil.rmtree(with_data, ignore_errors=True);
        shutil.rmtree(no_data, ignore_errors=True);
        shutil.rmtree(plugin, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "db drop refuses without intent and drops with it" {
    import from jaclang.cli.commands { db }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "dropme");
        (code, text) = _capture(
            lambda { db.db(action="drop", query=db_name, data_dir=cluster.data_dir); }
        );
        assert db_name in _jac_databases(cluster) , (
            f"db drop without --yes must not drop anything: {text}"
        );

        (code, text) = _capture(
            lambda { db.db(
                action="drop", query=db_name, data_dir=cluster.data_dir, yes=True
            ); }
        );
        assert code == 0 , f"db drop -y failed: {text}";
        assert db_name not in _jac_databases(cluster) , f"{db_name} survived db drop";
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


test "the retention sweep is off by default and sweeps when configured" {
    import from jaclang.data.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    try {
        (proj, db_name) = _project_database(cluster, "stale");
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} SET last_used_at = now() - interval '90 days' "
            f"WHERE database = '{db_name}'"
        );

        cluster.rt.stop();
        plain = PgRuntime(data_dir=cluster.data_dir, database="postgres");
        plain.ensure();
        cluster.rt = plain;
        assert db_name in _jac_databases(cluster) , (
            f"{db_name} was swept even though retention defaults to off"
        );

        plain.stop();
        sweeping = PgRuntime(
            data_dir=cluster.data_dir, database="postgres", retention_days=30
        );
        sweeping.ensure();
        cluster.rt = sweeping;
        assert db_name not in _jac_databases(cluster) , (
            f"{db_name} is 90 days stale and retention_days=30 must sweep it"
        );
        shutil.rmtree(proj, ignore_errors=True);
    } finally {
        _stop_cluster(cluster);
    }
}


"""A scratch registry record as a container would leave one: the recorded host
never comes back, so the recorded pid can never be checked from here."""
def _scratch_record(
    host: str,
    pid: int,
    heartbeat_age: int,
    has_sessions: bool = False,
    condemned_age: int = -1
) -> any {
    import from jaclang.data.dbcatalog { DbKind, DbRecord }
    return DbRecord(
        database="jac_scratch_4242_abc",
        recorded=True,
        kind=DbKind.SCRATCH.value,
        host=host,
        pid=pid,
        heartbeat_age_seconds=heartbeat_age,
        has_sessions=has_sessions,
        condemned_age_seconds=condemned_age
    );
}


test "a scratch record from a host that never comes back is still reapable" {
    import from jaclang.data.dbcatalog {
        LIVE_PID_GRACE_SECONDS,
        SCRATCH_CONDEMN_SEPARATION_SECONDS,
        UNREACHABLE_HOST_GRACE_SECONDS,
        this_host
    }
    # Every pod gets a fresh hostname, so a record written by a previous pod
    # reads as alive forever and is never reaped: the self-healing property is
    # weakest exactly where crashed runs are most common. It takes a silent
    # heartbeat plus an earlier pass that already found it silent (see below).
    gone = _scratch_record(
        "pod-that-crashed",
        4242,
        UNREACHABLE_HOST_GRACE_SECONDS + 60,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert gone.is_dead_scratch() , (
        "a scratch record whose host is unreachable and whose heartbeat stopped "
        "long ago must become reapable"
    );
    fresh = _scratch_record("pod-still-running", 4242, 30);
    assert not fresh.is_dead_scratch() , (
        "a heartbeat that is still being written must protect the database"
    );
    # A stale heartbeat alone never condemns a database: an owner that is still
    # connected to it is alive whatever its heartbeat says.
    connected = _scratch_record(
        "pod-with-a-wedged-heartbeat",
        4242,
        UNREACHABLE_HOST_GRACE_SECONDS + 60,
        has_sessions=True,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert not connected.is_dead_scratch() , (
        "a scratch database something is connected to must never be reaped"
    );
    # Rows that predate the heartbeat column carry no age at all, and an
    # unknown age never authorises a drop.
    unknown = _scratch_record(
        "pod-from-an-older-release",
        4242,
        -1,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert not unknown.is_dead_scratch() , (
        "an unknown heartbeat age must fail in the safe direction"
    );
    # A pid this host can actually check answers the question outright, so a
    # stale heartbeat cannot condemn a live local run.
    mine = _scratch_record(
        this_host(),
        os.getpid(),
        UNREACHABLE_HOST_GRACE_SECONDS + 60,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert not mine.is_dead_scratch() , (
        "a live local pid must outweigh a stale heartbeat"
    );
    # Unless nothing has touched it for far longer than any run could go
    # unheard, which is what a recycled pid looks like.
    recycled = _scratch_record(
        this_host(),
        os.getpid(),
        LIVE_PID_GRACE_SECONDS + 60,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert recycled.is_dead_scratch() , (
        "a pid that answers but has not heartbeaten in a day is a reused pid"
    );
    assert LIVE_PID_GRACE_SECONDS > UNREACHABLE_HOST_GRACE_SECONDS , (
        "a checkable pid must earn more patience than an uncheckable one"
    );
}


test "one silent window never condemns a live owner behind a partition" {
    import from jaclang.data.dbcatalog {
        SCRATCH_CONDEMN_SEPARATION_SECONDS,
        UNREACHABLE_HOST_GRACE_SECONDS
    }
    # The two signals the reap rests on are not independent in the failure that
    # matters. One partition, one saturated connection pool, one credential
    # rotation stops the heartbeat AND drops the store's connection, at the same
    # instant, for the same reason. So the moment a second opinion is most
    # needed is the moment both signals lie together, and process_alive cannot
    # break the tie because the host is not this one. Silence observed once is
    # therefore never enough.
    partitioned = _scratch_record(
        "pod-behind-a-partition", 4242, UNREACHABLE_HOST_GRACE_SECONDS + 60
    );
    assert partitioned.looks_abandoned() , (
        "a silent record must still be a candidate for condemnation"
    );
    assert not partitioned.is_dead_scratch() , (
        "a single silent window must never authorise dropping a database that a "
        "live owner may still be behind"
    );
    # Being condemned by an earlier pass is not enough either: the two
    # observations have to be separated in time, so one partition window cannot
    # supply both of them.
    just_condemned = _scratch_record(
        "pod-behind-a-partition",
        4242,
        UNREACHABLE_HOST_GRACE_SECONDS + 60,
        condemned_age=60
    );
    assert not just_condemned.is_dead_scratch() , (
        "a condemnation from moments ago is the same observation, not a second one"
    );
    confirmed = _scratch_record(
        "pod-behind-a-partition",
        4242,
        UNREACHABLE_HOST_GRACE_SECONDS + 60,
        condemned_age=SCRATCH_CONDEMN_SEPARATION_SECONDS + 60
    );
    assert confirmed.is_dead_scratch() , (
        "silence that outlived an old condemnation is what a crashed run leaves"
    );
    # Any heartbeat at all clears the mark, so a partition the owner survives
    # costs it nothing: it is back to being an ordinary live scratch store.
    spoke_again = _scratch_record("pod-behind-a-partition", 4242, 30);
    assert not spoke_again.looks_abandoned() and not spoke_again.is_dead_scratch() , (
        "an owner that heartbeats again must start from a clean slate"
    );
    assert SCRATCH_CONDEMN_SEPARATION_SECONDS > 0 , (
        "the two observations must be separated by a real interval"
    );
}


test "silence is only ever read as abandonment on a scratch record" {
    import from jaclang.data.dbcatalog { DbKind, DbRecord, LIVE_PID_GRACE_SECONDS }
    # Only scratch stores heartbeat, so a project database is silent by
    # construction between runs. Nothing may read that as abandonment: it would
    # condemn every project database in the cluster on the first prune.
    project = DbRecord(
        database="jac_app_1a2b3c4d",
        recorded=True,
        kind=DbKind.PROJECT.value,
        owner_path="/does/not/matter",
        host="pod-that-ran-it",
        pid=4242,
        heartbeat_age_seconds=LIVE_PID_GRACE_SECONDS * 2
    );
    assert not project.looks_abandoned() , (
        "a project database must never be condemned for not heartbeating"
    );
    assert not project.is_dead_scratch();
    assert project.state() != "silent scratch";
    # Nor is a scratch database nobody recorded: with no owner on file there is
    # nothing to conclude from its silence.
    unrecorded = DbRecord(
        database="jac_scratch_4242_orphan",
        kind=DbKind.SCRATCH.value,
        host="pod-that-crashed",
        pid=4242,
        heartbeat_age_seconds=LIVE_PID_GRACE_SECONDS * 2
    );
    assert not unrecorded.looks_abandoned() and not unrecorded.is_dead_scratch();
}


"""Register *name* as a scratch database owned by a host this machine is not."""
def _seed_scratch(cluster: Cluster, name: str, silent_for: str = "") {
    import from jaclang.data.dbcatalog { DbKind, REGISTRY_TABLE }
    _exec(cluster, f'CREATE DATABASE "{name}"');
    _exec(
        cluster,
        f"INSERT INTO {REGISTRY_TABLE} (database, kind, owner_path, host, pid) "
        f"VALUES ('{name}', '{DbKind.SCRATCH.value}', '', 'pod-{name}', 4242)"
    );
    if silent_for {
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} SET last_heartbeat_at = "
            f"now() - interval '{silent_for}' WHERE database = '{name}'"
        );
    }
}


def _prune(cluster: Cluster) -> tuple[int, str] {
    import from jaclang.cli.commands { db }
    return _capture(
        lambda { db.db(action="prune", data_dir=cluster.data_dir, yes=True); }
    );
}


test "db prune reaps a silent scratch database only after a second pass" {
    import from jaclang.data.dbcatalog { REGISTRY_TABLE }
    cluster = _start_cluster();
    stale = "jac_scratch_4242_stale";
    live = "jac_scratch_4243_live";
    try {
        _seed_scratch(cluster, stale, silent_for="2 hours");
        _seed_scratch(cluster, live);

        (code, text) = _prune(cluster);
        assert code == 0 , f"db prune -y failed: {text}";
        assert stale in _jac_databases(cluster) , (
            f"the first pass to find {stale} silent must only condemn it, since a "
            f"live owner behind a partition looks exactly like this: {text}"
        );
        marks = _query(
            cluster,
            f"SELECT condemned_at IS NOT NULL FROM {REGISTRY_TABLE} "
            f"WHERE database = '{stale}'"
        );
        assert bool(marks[0][0]) , f"the first pass recorded no condemnation: {text}";

        # Time passes with the heartbeat still silent, so a later pass is now
        # looking at a second, independent observation.
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} SET condemned_at = now() - interval '2 hours' "
            f"WHERE database = '{stale}'"
        );
        (code, text) = _prune(cluster);
        assert code == 0 , f"second db prune -y failed: {text}";
        names = _jac_databases(cluster);
        assert stale not in names , (
            f"{stale} has been silent across two separated passes and must be "
            f"reclaimed: {text}"
        );
        assert live in names , (
            f"{live} is still heartbeating and must survive prune: {text}"
        );
    } finally {
        _stop_cluster(cluster);
    }
}


test "an owner that reconnects before the drop keeps its database" {
    import from jaclang.data.dbcatalog { REGISTRY_TABLE }
    import from jaclang.data.pgload { connect }
    cluster = _start_cluster();
    reconnected = "jac_scratch_4244_back";
    try {
        _seed_scratch(cluster, reconnected, silent_for="2 hours");
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} SET condemned_at = now() - interval '2 hours' "
            f"WHERE database = '{reconnected}'"
        );
        # The owner is back and using its store again, whatever the registry
        # still says. A forced drop would terminate this connection and delete
        # the run's state underneath it.
        info = cluster.rt.conninfo();
        owner: any = connect(
            info.user,
            host=info.host,
            port=info.port,
            unix_socket_dir=info.unix_socket_dir,
            database=reconnected
        );
        try {
            owner.run("SELECT 1");
            (code, text) = _prune(cluster);
            assert code == 0 , f"db prune -y failed: {text}";
            assert reconnected in _jac_databases(cluster) , (
                f"a live connection must veto the drop, not be killed by it: {text}"
            );
            assert owner.run("SELECT 1") , (
                "the owner's session was terminated by the reap"
            );
        } finally {
            owner.close();
        }
    } finally {
        _stop_cluster(cluster);
    }
}


test "an open scratch database keeps its own registry heartbeat fresh" {
    import time;
    import from jaclang.data { dbcatalog as catalog }
    import from jaclang.data.dbcatalog {
        DbKind,
        REGISTRY_TABLE,
        start_heartbeat,
        stop_heartbeat
    }
    cluster = _start_cluster();
    beating = "jac_scratch_4244_beat";
    saved = catalog.SCRATCH_HEARTBEAT_SECONDS;
    catalog.SCRATCH_HEARTBEAT_SECONDS = 1;
    try {
        _exec(cluster, f'CREATE DATABASE "{beating}"');
        _exec(
            cluster,
            f"INSERT INTO {REGISTRY_TABLE} "
            "(database, kind, owner_path, host, pid) "
            f"VALUES ('{beating}', '{DbKind.SCRATCH.value}', '', 'pod-x', 4244)"
        );
        # Backdate it far enough that only a real heartbeat can explain a
        # fresh timestamp.
        _exec(
            cluster,
            f"UPDATE {REGISTRY_TABLE} "
            "SET last_heartbeat_at = now() - interval '2 hours' "
            f"WHERE database = '{beating}'"
        );
        start_heartbeat(cluster.rt.conninfo(), beating);
        deadline = time.monotonic() + 30;
        age = -1;
        while time.monotonic() < deadline {
            rows = _query(
                cluster,
                "SELECT floor(extract(epoch FROM now() - last_heartbeat_at))"
                f"::bigint FROM {REGISTRY_TABLE} WHERE database = '{beating}'"
            );
            age = int(rows[0][0]);
            if age < 60 {
                break;
            }
            time.sleep(0.5);
        }
        assert age >= 0 and age < 60 , (
            f"the heartbeat never refreshed the record (age {age}s), so a live "
            f"scratch database would eventually look reapable"
        );
    } finally {
        stop_heartbeat(beating);
        catalog.SCRATCH_HEARTBEAT_SECONDS = saved;
        _stop_cluster(cluster);
    }
}


test "retention days come from [database] retention_days, off by default" {
    import from jaclang.server.session { retention_days_for }
    base = tempfile.mkdtemp(prefix="jac-retention-");
    try {
        assert retention_days_for(base) == 0 , "retention must default to off";
        Path(os.path.join(base, "jac.toml")).write_text(
            "[project]\nname = \"r\"\n\n[database]\nretention_days = 45\n"
        );
        assert retention_days_for(base) == 45 , (
            "[database] retention_days must be honored"
        );
        os.environ["JAC_DB_RETENTION_DAYS"] = "7";
        try {
            assert retention_days_for(base) == 7 , (
                "JAC_DB_RETENTION_DAYS must override jac.toml"
            );
        } finally {
            os.environ.pop("JAC_DB_RETENTION_DAYS", None);
        }
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


# ---------------------------------------------------------------------------
# CREATE DATABASE races between parallel workers
# ---------------------------------------------------------------------------
# `_ensure_database` checks pg_database and then creates, so a pool of workers
# provisioning the same database can have two of them both see no row and both
# issue CREATE DATABASE. The precompile step forks exactly such a pool, and the
# loser used to fail the whole seal. This reproduces the shape of that pool
# against a real cluster rather than asserting on an error message.

"""Have `workers` runtimes provision `database` at once; return what was raised.

Each worker opens its own admin connection inside `_ensure_database`, and the
barrier lines them all up on the check so the window between the SELECT and the
CREATE is actually contended.
"""
def _race_ensure(cluster: Cluster, database: str, workers: int) -> list {
    import threading;
    import from jaclang.data.pgembed { DbKind }
    barrier = threading.Barrier(workers);
    failures: list = [];
    lock = threading.Lock();

    def _worker {
        rt = PgRuntime(
            data_dir=cluster.data_dir,
            database=database,
            kind=DbKind.SCRATCH,
            owner_path=cluster.workspace
        );
        try {
            barrier.`wait();
            rt._ensure_database();
        } except Exception as e {
            with lock {
                failures.append(e);
            }
        }
    }
    threads = [threading.Thread(target=_worker) for _ in range(workers)];
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join();
    }
    return failures;
}


test "a pool of workers can provision the same database at once" {
    cluster = _start_cluster();
    try {
        # Several rounds on fresh names: one round can get lucky and serialise,
        # so a single green round would not prove much.
        for round in range(4) {
            database = f"jac_race_probe_{round}";
            failures = _race_ensure(cluster, database, 6);
            assert failures == [] , f"round {round} raised {[
                str(f) for f in failures
            ]}";
            rows = _query(
                cluster, f"SELECT 1 FROM pg_database WHERE datname = '{database}'"
            );
            assert rows , f"round {round} left no database behind";
        }
    } finally {
        _stop_cluster(cluster);
    }
}
