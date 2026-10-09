"""P2 end-to-end: stateless `def:pub` function served over HTTP on the bun host.

Skips when embedded Postgres or the bun runtime is unavailable — same pattern
as test_bun_persist_e2e_p2.jac. Unlike that test, the service performs no graph
operations; this pins the "stateless def:pub functions become HTTP endpoints"
promise from docs/reference/cli/index.md.
"""

import from pathlib { Path }
import tempfile;
import from jaclang.bun_service_builder { build_bun_service_artifact }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.server.session { project_db_name }
import from tests.support {
    bun_runtime_available,
    post_json,
    spawn_bun_artifact,
    stop_process,
    wait_service_ready,
    write_sv_project
}


glob _STATELESS_SVC: str = (
         'def:pub greet(name: str) -> str {\n' '    return f"hello {name}";\n' '}\n'
     );


def _pg_conninfo(tmp: str) -> (any | None) {
    try {
        target = str(Path(tmp) / 'app.jac');
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


test "stateless def:pub function serves over HTTP on the bun host" {
    if not bun_runtime_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        info = _pg_conninfo(tmp);
        if info is None {
            return;
        }
        write_sv_project(tmp, 'greeter', _STATELESS_SVC);
        artifact = build_bun_service_artifact('greeter', tmp);
        proc = spawn_bun_artifact(str(artifact), tmp, 9875, info);
        try {
            ready = wait_service_ready(9875, expect_substring='greet');
            assert ready , "bun stateless service never served /functions";

            (ok, payload) = post_json(9875, '/function/greet', '{"name": "jac"}');
            assert ok , "greet call failed";
            assert payload.get('ok') is True , f"unexpected envelope: {payload}";
            assert payload.get('data', {}).get('result') == 'hello jac';
        } finally {
            stop_process(proc);
        }
    }
}
