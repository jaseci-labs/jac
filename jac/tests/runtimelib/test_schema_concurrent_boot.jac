"""Concurrent first boot against a fresh database (issue #8166).

`ensure_schema` guarded its DDL with a process-local lock (`_schema_gate` plus
the `_schema_ready` set), but the resource it protects is the database, which
every replica of a scaled deploy shares. One process was always fine, and a
restart against an existing schema was fine, so the defect only showed when two
replicas booted a fresh database together: Postgres `IF NOT EXISTS` is a catalog
check followed by a create, not an atomic operation, so the loser died with
SQLSTATE 23505 on `pg_type_typname_nsp_index` / `pg_class_relname_nsp_index`.

Every test here owns a private cluster under a temp dir, so nothing touches the
developer's shared cluster at ~/.cache/jac/pg/main.
"""

import os;
import shutil;
import tempfile;
import threading;
import time;
import from typing { Any }

import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store {
    ConnInfo,
    PgStore,
    SCHEMA_STAMP_KEY,
    _SCHEMA_SQL
}


obj Cluster {
    has cache_home: str,
        rt: Any;
}


"""Boot a private cluster whose layout matches $JAC_CACHE_HOME/pg/main."""
def _start_cluster -> Cluster {
    cache_home = tempfile.mkdtemp(prefix="jac-schema-race-");
    rt = PgRuntime(
        data_dir=os.path.join(cache_home, "pg", "main"), database="postgres"
    );
    rt.ensure();
    return Cluster(cache_home=cache_home, rt=rt);
}


def _stop_cluster(cluster: Cluster) {
    try {
        cluster.rt.stop();
    } except Exception { }
    shutil.rmtree(cluster.cache_home, ignore_errors=True);
}


def _raw(cluster: Cluster, database: str) -> Any {
    import from jaclang.vendor.pgload { connect }
    info = cluster.rt.conninfo();
    return connect(
        info.user,
        host=info.host,
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=database
    );
}


def _query(cluster: Cluster, database: str, sql: str) -> list {
    conn: Any = _raw(cluster, database);
    try {
        return conn.run(sql) or [];
    } finally {
        conn.close();
    }
}


"""An empty database plus the ConnInfo a store needs to reach it."""
def _fresh_db(cluster: Cluster, name: str) -> ConnInfo {
    admin: Any = _raw(cluster, "postgres");
    try {
        admin.run(f"DROP DATABASE IF EXISTS {name}");
        admin.run(f"CREATE DATABASE {name}");
    } finally {
        admin.close();
    }
    info = cluster.rt.conninfo();
    return ConnInfo(
        host=info.host,
        port=info.port,
        user=info.user,
        database=name,
        unix_socket_dir=info.unix_socket_dir
    );
}


def _table_count(cluster: Cluster, database: str) -> int {
    rows = _query(
        cluster,
        database,
        "SELECT count(*) FROM pg_tables WHERE schemaname = current_schema()"
    );
    return int(rows[0][0]) if rows else 0;
}


"""Wait until some backend in *database* is parked on a lock.

The observer holds one connection open for the whole poll: the store it is
watching runs its DDL under lock_timeout = 5s, so reconnecting per poll could
burn the budget and turn the duplicate-key race into a lock timeout.
"""
def _wait_for_lock_wait(
    cluster: Cluster, database: str, timeout: float = 20.0
) -> bool {
    conn: Any = _raw(cluster, database);
    try {
        deadline = time.monotonic() + timeout;
        while time.monotonic() < deadline {
            rows = conn.run(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() AND wait_event_type = 'Lock'"
            );
            if rows and int(rows[0][0]) > 0 {
                return True;
            }
            time.sleep(0.02);
        }
        return False;
    } finally {
        conn.close();
    }
}


test "replicas booting one fresh database together all survive" {
    cluster = _start_cluster();
    stores: list = [];
    try {
        ci = _fresh_db(cluster, "jac_race_boot");
        racers = 4;
        for _i in range(racers) {
            stores.append(
                PgStore(
                    conninfo=ConnInfo(
                        host=ci.host,
                        port=ci.port,
                        user=ci.user,
                        database=ci.database,
                        unix_socket_dir=ci.unix_socket_dir
                    )
                )
            );
        }
        gate = threading.Barrier(racers);
        failures: list = [];

        def boot(store: Any) {
            gate.wait(60);
            try {
                store.ensure_schema({});
            } except Exception as e {
                failures.append(e);
            }
        }
        threads = [
            threading.Thread(target=boot, args=(s, ), name="jac-boot-racer")
            for s in stores
        ];
        for t in threads {
            t.start();
        }
        for t in threads {
            t.join(300);
        }
        assert failures == [] , (
            f"{len(failures)} of {racers} replicas died booting a fresh database: "
            f"{[repr(e) for e in failures]}"
        );
        assert stores[0].kv_get(SCHEMA_STAMP_KEY) is not None , (
            "the schema is not stamped, so every later boot redoes the DDL"
        );
        assert _table_count(cluster, ci.database) >= 4 , (
            "the shared tables are missing after a concurrent boot"
        );
    } finally {
        for s in stores {
            try {
                s.close();
            } except Exception { }
        }
        _stop_cluster(cluster);
    }
}


test "a boot that cannot take the schema lock still survives the race" {
    import unittest.mock;

    cluster = _start_cluster();
    stores: list = [];
    try {
        ci = _fresh_db(cluster, "jac_race_unguarded");
        racers = 4;
        for _i in range(racers) {
            stores.append(
                PgStore(
                    conninfo=ConnInfo(
                        host=ci.host,
                        port=ci.port,
                        user=ci.user,
                        database=ci.database,
                        unix_socket_dir=ci.unix_socket_dir
                    )
                )
            );
        }
        gate = threading.Barrier(racers);
        failures: list = [];

        def boot(store: Any) {
            gate.wait(60);
            try {
                store.ensure_schema({});
            } except Exception as e {
                failures.append(e);
            }
        }
        with unittest.mock.patch.object(
            PgStore, "_acquire_schema_lock", return_value=False
        ) {
            threads = [
                threading.Thread(target=boot, args=(s, ), name="jac-unguarded-racer")
                for s in stores
            ];
            for t in threads {
                t.start();
            }
            for t in threads {
                t.join(300);
            }
        }
        assert failures == [] , (
            f"{len(failures)} of {racers} replicas died booting with no schema "
            f"lock held; the sqlstate backstop must carry the degraded path: "
            f"{[repr(e) for e in failures]}"
        );
        assert _table_count(cluster, ci.database) >= 4 , (
            "the unguarded boot left the schema incomplete"
        );
        assert stores[0].kv_get(SCHEMA_STAMP_KEY) is not None , (
            "the unguarded boot never stamped the schema"
        );
    } finally {
        for s in stores {
            try {
                s.close();
            } except Exception { }
        }
        _stop_cluster(cluster);
    }
}


test "losing a create race to another session does not fail the boot" {
    cluster = _start_cluster();
    store: Any = None;
    rival: Any = None;
    try {
        ci = _fresh_db(cluster, "jac_race_dup");
        store = PgStore(conninfo=ci);
        rival = _raw(cluster, ci.database);
        rival.run("BEGIN");
        rival.run(_SCHEMA_SQL[0]);
        outcome: dict = {};

        def boot {
            try {
                store.ensure_schema({});
                outcome["ok"] = True;
            } except Exception as e {
                outcome["err"] = e;
            }
        }
        t = threading.Thread(target=boot, name="jac-dup-victim");
        t.start();
        assert _wait_for_lock_wait(cluster, ci.database) , (
            "the booting store never reached the contended CREATE TABLE"
        );
        assert "err" not in outcome , f"boot failed early: {outcome.get('err')!r}";
        rival.run("COMMIT");
        t.join(300);
        assert outcome.get("ok") is True , (
            f"a store that lost a create race to a concurrent session raised "
            f"instead of accepting the winner's objects: {outcome.get('err')!r}"
        );
        assert store.kv_get(SCHEMA_STAMP_KEY) is not None , (
            "the loser returned without stamping the schema"
        );
    } finally {
        for c in [rival, store] {
            if c is not None {
                try {
                    c.close();
                } except Exception { }
            }
        }
        _stop_cluster(cluster);
    }
}


test "the schema critical section is a lock every replica can see" {
    cluster = _start_cluster();
    store: Any = None;
    rival: Any = None;
    try {
        ci = _fresh_db(cluster, "jac_race_lock");
        store = PgStore(conninfo=ci);
        key = store._schema_lock_key();
        rival = _raw(cluster, ci.database);
        taken = rival.run(f"SELECT pg_try_advisory_lock({key})");
        assert bool(taken[0][0]) , "an unrelated session could not take the schema lock";
        outcome: dict = {};

        def boot {
            try {
                store.ensure_schema({});
                outcome["ok"] = True;
            } except Exception as e {
                outcome["err"] = e;
            }
        }
        t = threading.Thread(target=boot, name="jac-lock-waiter");
        t.start();
        time.sleep(3.0);
        assert _table_count(cluster, ci.database) == 0 , (
            "schema DDL ran while another session held the schema lock; the "
            "critical section is not database-scoped"
        );
        assert not outcome , f"the boot finished past the held lock: {outcome}";
        rival.run(f"SELECT pg_advisory_unlock({key})");
        t.join(300);
        assert outcome.get("ok") is True , (
            f"the waiting store never completed: {outcome.get('err')!r}"
        );
        assert _table_count(cluster, ci.database) >= 4 , (
            "the store that waited out the lock never created the schema"
        );
    } finally {
        for c in [rival, store] {
            if c is not None {
                try {
                    c.close();
                } except Exception { }
            }
        }
        _stop_cluster(cluster);
    }
}
