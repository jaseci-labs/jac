# P2 end-to-end: `POST /walker/<name>` dispatches against a real bun artifact.
#
# Companion to test_bun_persist_e2e_p2.jac (which covers functions): this
# pins the walker half of the HTTP surface — descriptor wiring
# (__jacOspDesc/__jacOspRT) must survive Bun.build so pub walkers execute
# through the OSP kernel, and nodes they create must land in Postgres via
# BunStore. Skips when embedded Postgres or bun is unavailable.

import from pathlib { Path }
import tempfile;
import from jaclang.bun_service_builder { build_bun_service_artifact }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { project_db_name }
import from jaclang.data.store { PgStore }
import from tests.support {
    bun_runtime_available,
    get_json,
    post_json,
    spawn_bun_artifact,
    stop_process,
    wait_service_ready,
    write_sv_project
}


glob _WALKER_SVC: str = (
         'node Thing {\n'
         '    has label: str = "made-by-walker";\n'
         '}\n'
         'walker:pub touch {\n'
         '    can go with Root entry {\n'
         '        here ++> Thing();\n'
         '        report "ok";\n'
         '    }\n'
         '}\n'
     );


def _pg_conninfo(tmp: str) -> (any | None) {
    try {
        target = str(Path(tmp) / 'walksvc.jac');
        rt = PgRuntime(
            data_dir=str(Path(tmp) / 'pgdata'),
            database=project_db_name(tmp, target),
            owner_path=tmp
        );
        return rt.ensure();
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


test "pub walker serves over HTTP and persists through BunStore" {
    if not bun_runtime_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        info = _pg_conninfo(tmp);
        if info is None {
            return;
        }
        write_sv_project(tmp, 'walksvc', _WALKER_SVC);
        artifact = build_bun_service_artifact('walksvc', tmp);
        # The bundle must retain the osp descriptor wiring: without it the
        # walker route can only answer 500 ("No walker runtime available").
        bundle = Path(artifact).read_text(encoding='utf-8');
        assert '__jacOspDesc' in bundle , (
            "artifact lost __jacOspDesc — walker descriptors did not survive "
            + "bundling; POST /walker/<name> would 500"
        );
        assert '__jacOspRT' in bundle , "artifact lost __jacOspRT";
        proc = spawn_bun_artifact(str(artifact), tmp, 9878, info);
        store = None;
        try {
            ready = wait_service_ready(9878);
            assert ready , "bun walker service never became ready";
            (listed_ok, listed) = get_json(9878, '/walkers');
            assert listed_ok and 'touch' in listed , f"walker listing: {listed}";

            for _ in range(2) {
                (ok, payload) = post_json(9878, '/walker/touch', '{}');
                assert ok , f"walker call failed: {payload}";
                result = payload.get('data', {}).get('result', {});
                assert result.get('reports') == ['ok'] , (
                    f"walker reports missing: {payload}"
                );
            }

            # Nodes the walker created must be durable, not just in-memory.
            store = PgStore(conninfo=info, ensure_cb=None);
            store.ensure_schema({});
            rows = store.rows(
                "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'", {}
            );
            assert int(rows[0][0]) >= 3 , (
                f"expected root + spawned Things persisted, got {rows[0][0]}"
            );
        } finally {
            stop_process(proc);
            if store is not None {
                store.close();
            }
        }
    }
}
