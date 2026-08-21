"""P2 end-to-end: bun-hosted walker persists through BunStore + Postgres.

Skips when embedded Postgres or the bun runtime is unavailable — same pattern
as jaclang/scale/tests/server/test_pg_job_store.jac.
"""

import json;
import os;
import subprocess;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.session { project_db_name }
import from jaclang.runtimelib.store { PgStore }


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


def _bun_available -> bool {
    try {
        proc = subprocess.run(
            ['bun', '--version'], capture_output=True, text=True, timeout=10
        );
        return proc.returncode == 0;
    } except Exception {
        return False;
    }
}


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


def _write_project(tmp: str, source: str) {
    with open(os.path.join(tmp, 'counter.jac'), 'w') as f {
        f.write(source);
    }
    with open(os.path.join(tmp, 'jac.toml'), 'w') as f {
        f.write('[project]\n' + 'name = "counter"\n' + 'entry-point = "counter.jac"\n');
    }
}


test "bun service persists root-connected nodes through shared Postgres schema" {
    if not _bun_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        store = _pg_store(tmp);
        if store is None {
            return;
        }
        _write_project(tmp, _PERSIST_SVC);
        artifact = build_bun_service_artifact('counter', tmp);
        assert artifact.exists();
        info = store.conninfo;
        env = os.environ.copy();
        env['PORT'] = '9876';
        env['JAC_PG_HOST'] = info.host or '127.0.0.1';
        env['JAC_PG_PORT'] = str(info.port);
        env['JAC_PG_USER'] = info.user;
        env['JAC_PG_DATABASE'] = info.database;
        if info.unix_socket_dir {
            env['JAC_PG_SOCKET'] = info.unix_socket_dir;
        }
        proc = subprocess.Popen(
            ['bun', str(artifact)],
            cwd=tmp,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );
        try {
            ready = False;
            for _ in range(40) {
                ping = subprocess.run(
                    ['curl', '-sf', 'http://127.0.0.1:9876/functions'],
                    capture_output=True,
                    text=True,
                    timeout=2
                );
                if ping.returncode == 0 {
                    ready = True;
                    break;
                }
                time.sleep(0.25);
            }
            assert ready , "bun persist service never became ready on /functions";

            call = subprocess.run(
                [
                    'curl',
                    '-sf',
                    '-X',
                    'POST',
                    'http://127.0.0.1:9876/function/bump',
                    '-H',
                    'Content-Type: application/json',
                    '-d',
                    '{}'
                ],
                capture_output=True,
                text=True,
                timeout=10
            );
            assert call.returncode == 0 , f"bump call failed: {call.stderr}";
            payload = json.loads(call.stdout or '{}');
            assert payload.get('ok') is True , f"unexpected envelope: {payload}";
            assert payload.get('data', {}).get('result') == 1;

            store.ensure_schema({});
            rows = store.rows(
                "SELECT count(*) FROM anchors WHERE kind = 'NodeAnchor'", {}
            );
            assert int(rows[0][0]) >= 1 , "bump must persist at least one node anchor";
        } finally {
            proc.terminate();
            try {
                proc.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                proc.kill();
            }
            store.close();
        }
    }
}
