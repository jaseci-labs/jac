"""P2 end-to-end: stateless `def:pub` function served over HTTP on the bun host.

Skips when embedded Postgres or the bun runtime is unavailable — same pattern
as test_bun_persist_e2e_p2.jac. Unlike that test, the service performs no graph
operations; this pins the "stateless def:pub functions become HTTP endpoints"
promise from docs/reference/cli/index.md.
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


glob _STATELESS_SVC: str = (
         'def:pub greet(name: str) -> str {\n'
         '    return f"hello {name}";\n'
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


def _write_project(tmp: str, source: str) {
    with open(os.path.join(tmp, 'greeter.jac'), 'w') as f {
        f.write(source);
    }
    with open(os.path.join(tmp, 'jac.toml'), 'w') as f {
        f.write('[project]\n' + 'name = "greeter"\n' + 'entry-point = "greeter.jac"\n');
    }
}


test "stateless def:pub function serves over HTTP on the bun host" {
    if not _bun_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        info = _pg_conninfo(tmp);
        if info is None {
            return;
        }
        _write_project(tmp, _STATELESS_SVC);
        artifact = build_bun_service_artifact('greeter', tmp);
        env = os.environ.copy();
        env['PORT'] = '9875';
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
                    ['curl', '-sf', 'http://127.0.0.1:9875/functions'],
                    capture_output=True,
                    text=True,
                    timeout=2
                );
                if ping.returncode == 0 and 'greet' in ping.stdout {
                    ready = True;
                    break;
                }
                time.sleep(0.25);
            }
            assert ready , "bun stateless service never served /functions";

            call = subprocess.run(
                [
                    'curl',
                    '-sf',
                    '-X',
                    'POST',
                    'http://127.0.0.1:9875/function/greet',
                    '-H',
                    'Content-Type: application/json',
                    '-d',
                    '{"name": "jac"}'
                ],
                capture_output=True,
                text=True,
                timeout=10
            );
            assert call.returncode == 0 , f"greet call failed: {call.stderr}";
            payload = json.loads(call.stdout or '{}');
            assert payload.get('ok') is True , f"unexpected envelope: {payload}";
            assert payload.get('data', {}).get('result') == 'hello jac';
        } finally {
            proc.terminate();
            try {
                proc.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                proc.kill();
            }
        }
    }
}
