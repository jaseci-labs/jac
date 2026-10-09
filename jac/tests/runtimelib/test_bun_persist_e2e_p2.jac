"""P2 end-to-end: bun-hosted walker persists through BunStore + Postgres.

Skips when embedded Postgres or the bun runtime is unavailable — same pattern
as jaclang/scale/tests/server/test_pg_job_store.jac.
"""

import from pathlib { Path }
import tempfile;
import from jaclang.bun_service_builder { build_bun_service_artifact }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { project_db_name }
import from jaclang.data.store { PgStore }
import from tests.support {
    bun_runtime_available,
    post_json,
    spawn_bun_artifact,
    stop_process,
    wait_service_ready,
    write_sv_project
}


glob _PERSIST_SVC: str = (
         'node Counter {\n'
         '    has n: int = 0;\n'
         '}\n'
         'def:pub bump() -> int {\n'
         '    doc = Counter(n=1);\n'
         '    root ++> doc;\n'
         '    return doc.n;\n'
         '}\n'
     );


def _pg_store(tmp: str) -> (PgStore | None) {
    try {
        target = str(Path(tmp) / 'app.jac');
        rt = PgRuntime(
            data_dir=str(Path(tmp) / 'pgdata'),
            database=project_db_name(tmp, target),
            owner_path=tmp
        );
        return PgStore(conninfo=rt.ensure(), ensure_cb=rt.ensure);
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


test "bun service persists root-connected nodes through shared Postgres schema" {
    if not bun_runtime_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        store = _pg_store(tmp);
        if store is None {
            return;
        }
        write_sv_project(tmp, 'counter', _PERSIST_SVC);
        artifact = build_bun_service_artifact('counter', tmp);
        assert artifact.exists();
        info = store.conninfo;
        proc = spawn_bun_artifact(str(artifact), tmp, 9876, info);
        try {
            ready = wait_service_ready(9876);
            assert ready , "bun persist service never became ready on /functions";

            (ok, payload) = post_json(9876, '/function/bump', '{}');
            assert ok , "bump call failed";
            assert payload.get('ok') is True , f"unexpected envelope: {payload}";
            assert payload.get('data', {}).get('result') == 1;

            store.ensure_schema({});
            rows = store.rows(
                "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'", {}
            );
            assert int(rows[0][0]) >= 1 , "bump must persist at least one node anchor";
        } finally {
            stop_process(proc);
            store.close();
        }
    }
}
