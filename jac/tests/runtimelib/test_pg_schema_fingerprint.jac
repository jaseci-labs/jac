"""The schema fingerprint is a pure function of the schema (#9160).

A server computes the schema fingerprint twice while it boots: once in
`shared_store()` (`PgStore.ensure_schema_once`) and again when the outbox
worker derives its own store (`PgOutboxStore.ensure_tables`). Since 0.37.5 the
outbox registered its tables with the store as a side effect of importing
`jaclang.server.outbox`, so the two fingerprints differed, every boot rewrote
the stamp twice, and no restart ever took the fast path: each replica re-ran
the schema DDL under the other replicas' open transactions (5s lock stalls per
promoted field, or `SessionConflictError` against a TCP database).

Pinned here:

  stable   -- the fingerprint does not depend on what the process has
              imported; the boot sequence applies the schema DDL exactly once
              per database;
  restart  -- a fresh store against an unchanged schema runs no DDL at all;
  complete -- the base schema carries the outbox and docs tables, so
              nothing has to extend it later.

The boot sequence runs in a child interpreter so that `jaclang.server.outbox`
is provably not imported before the first schema step, whichever suites ran
earlier in this process.
"""

import json;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support { compiler_python_command }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { shared_pg_data_dir, project_db_name }
import from jaclang.data.store { ConnInfo, PgStore, SCHEMA_STAMP_KEY }

glob PROMOTIONS: dict[str, list[str]] = {'Session': ['id'], 'Run': ['id']},
     PLUGIN_TABLES = ['jac_outbox', 'jac_outbox_seen', 'jac_docs'],
     # The two schema steps a server runs, in the order it runs them:
     # shared_store() ensures the schema, then the outbox worker derives its
     # store. Each DDL run and the stamp after each step are reported back.
     BOOT_SCRIPT = """
import json
import sys
from jaclang.data.store import ConnInfo, PgStore, SCHEMA_STAMP_KEY

info = ConnInfo(**json.loads(sys.argv[1]))
promotions = json.loads(sys.argv[2])
ddl_runs = []
real_apply = PgStore._apply_schema_ddl


def counted_apply(store):
    ddl_runs.append(1)
    real_apply(store)


PgStore._apply_schema_ddl = counted_apply
primary = PgStore(conninfo=info, promotions=dict(promotions))
primary.rows('SELECT 1', {})
primary.ensure_schema_once(dict(promotions))
after_shared_store = primary.kv_get(SCHEMA_STAMP_KEY)
outbox_preloaded = 'jaclang.server.outbox' in sys.modules
import jaclang.server.outbox as outbox
worker = outbox._derive_worker_store(primary)
after_worker = primary.kv_get(SCHEMA_STAMP_KEY)
worker.close()
primary.close()
print(json.dumps({
    'after_shared_store': after_shared_store,
    'after_worker': after_worker,
    'ddl_runs': len(ddl_runs),
    'outbox_preloaded': outbox_preloaded,
}))
""";


def _fresh_db(td: str) -> tuple[any, ...] {
    target = str(Path(td) / 'app.jac');
    rt = PgRuntime(
        data_dir=shared_pg_data_dir(),
        database=project_db_name(td, target),
        owner_path=td
    );
    return (rt, rt.ensure());
}


def _conninfo_json(info: ConnInfo) -> str {
    return json.dumps(
        {
            'host': info.host,
            'port': info.port,
            'user': info.user,
            'password': info.password,
            'database': info.database,
            'unix_socket_dir': info.unix_socket_dir
        }
    );
}


def _boot_in_child(info: ConnInfo) -> dict[str, any] {
    res = subprocess.run(
        compiler_python_command(
            BOOT_SCRIPT, _conninfo_json(info), json.dumps(PROMOTIONS)
        ),
        capture_output=True,
        text=True,
        timeout=600
    );
    assert res.returncode == 0 , f"the child boot failed:\n{res.stderr}";
    lines = [
        line
        for line in res.stdout.splitlines()
        if line.startswith('{')
    ];
    assert lines , f"the child boot reported nothing:\n{res.stdout}\n{res.stderr}";
    boot = json.loads(lines[-1]);
    assert not boot['outbox_preloaded'] , (
        'jaclang.server.outbox was imported before the first schema step, so'
        ' the child cannot reproduce the server boot order'
    );
    return boot;
}


def _present_tables(store: PgStore) -> list[str] {
    rows = store.rows(
        'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()', {}
    );
    return sorted(str(row[0]) for row in rows);
}


obj _CountingStore(PgStore) {
    has ddl_runs: int = 0;

    def _apply_schema_ddl {
        self.ddl_runs += 1;
        super._apply_schema_ddl();
    }
}


test "a server boot applies the schema DDL once and a restart applies none" {
    with TemporaryDirectory() as td {
        (rt, info) = _fresh_db(td);
        boot = _boot_in_child(info);
        assert boot['after_shared_store'] == boot['after_worker'] , (
            'importing jaclang.server.outbox changed the schema fingerprint'
            f" ({boot['after_shared_store']} -> {boot['after_worker']}): the"
            ' fingerprint must be a function of the schema, not of the imports'
        );
        assert boot['ddl_runs'] == 1 , (
            f"one server boot ran the schema DDL {boot['ddl_runs']} time(s);"
            ' expected exactly once'
        );
        restarted = _CountingStore(
            conninfo=info, ensure_cb=rt.ensure, promotions=dict(PROMOTIONS)
        );
        try {
            restarted.ensure_schema(dict(PROMOTIONS));
            assert restarted.ddl_runs == 0 , (
                'a fresh process booting against an unchanged schema ran the'
                f" DDL {restarted.ddl_runs} time(s) instead of taking the fast path"
            );
            assert restarted.kv_get(SCHEMA_STAMP_KEY) == boot['after_worker'] , (
                'the restarted store computed a different fingerprint than the'
                ' one the boot stamped'
            );
        } finally {
            restarted.close();
        }
    }
}


test "the base schema carries the outbox and docs tables" {
    with TemporaryDirectory() as td {
        (rt, info) = _fresh_db(td);
        store = PgStore(conninfo=info, ensure_cb=rt.ensure);
        try {
            store.ensure_schema({});
            tables = _present_tables(store);
            missing = [
                name
                for name in PLUGIN_TABLES
                if name not in tables
            ];
            assert missing == [] , (
                f"ensure_schema left {missing} uncreated: the store owns the"
                ' outbox and docs tables, nothing may extend the schema after'
                ' the fact'
            );
        } finally {
            store.close();
        }
    }
}
