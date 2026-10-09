# P2 end-to-end: cl_stdlib modules execute real work inside a bun artifact.
#
# The compiler-level suite (tests/compiler/test_host_bun_stdlib_p2.jac) pins
# that stdlib imports compile and emit JS; this test goes further and executes
# a service through real Bun.build + Bun.serve, asserting computed results
# over HTTP — the behavior those substring greps approximate.

import re;
import hashlib;
import tempfile;
import from pathlib { Path }
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


glob _STDLIB_SVC: str = (
         'import from datetime { datetime }\n'
         'import hashlib;\n'
         'import uuid;\n'
         'import json;\n'
         '\n'
         'def:pub sha_hex(text: str) -> str {\n'
         '    return hashlib.sha256(text.encode()).hexdigest();\n'
         '}\n'
         '\n'
         'def:pub now_iso() -> str {\n'
         '    return datetime.now().isoformat();\n'
         '}\n'
         '\n'
         'def:pub new_uuid() -> str {\n'
         '    return str(uuid.uuid4());\n'
         '}\n'
         '\n'
         'def:pub encode(payload: dict) -> str {\n'
         '    return json.dumps(payload);\n'
         '}\n'
     ),
     _UUID_RE: str = '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';


def _pg_conninfo(tmp: str) -> (any | None) {
    try {
        target = str(Path(tmp) / 'stdlibsvc.jac');
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


test "cl_stdlib functions compute real results over HTTP on the bun host" {
    if not bun_runtime_available() {
        print('[skip] bun runtime unavailable');
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        info = _pg_conninfo(tmp);
        if info is None {
            return;
        }
        write_sv_project(tmp, 'stdlibsvc', _STDLIB_SVC);
        artifact = build_bun_service_artifact('stdlibsvc', tmp);
        proc = spawn_bun_artifact(str(artifact), tmp, 9877, info);
        try {
            ready = wait_service_ready(9877, expect_substring='sha_hex');
            assert ready , "bun stdlib service never served /functions";

            # hashlib: exact digest parity with the Python computation.
            expected = hashlib.sha256('jac'.encode()).hexdigest();
            (ok, payload) = post_json(9877, '/function/sha_hex', '{"text": "jac"}');
            assert ok , f"sha_hex call failed: {payload}";
            got = payload.get('data', {}).get('result');
            assert got == expected , f"digest mismatch: {got} != {expected}";

            # datetime: wall-clock ISO string, not a stub epoch.
            (ok, payload) = post_json(9877, '/function/now_iso', '{}');
            assert ok , f"now_iso call failed: {payload}";
            iso = payload.get('data', {}).get('result');
            assert isinstance(iso, str) and 'T' in iso , (
                f"isoformat not returned: {iso}"
            );

            # uuid: v4 shape with version/variant nibbles.
            (ok, payload) = post_json(9877, '/function/new_uuid', '{}');
            assert ok , f"new_uuid call failed: {payload}";
            uid = payload.get('data', {}).get('result');
            assert isinstance(uid, str) and re.`match(_UUID_RE, uid) , (
                f"not a v4 uuid: {uid}"
            );

            # json: round-trip of a dict payload.
            (ok, payload) = post_json(
                9877, '/function/encode', '{"payload": {"a": 1}}'
            );
            assert ok , f"encode call failed: {payload}";
            encoded = payload.get('data', {}).get('result');
            import json as json_mod;
            decoded = None;
            try {
                decoded = json_mod.loads(encoded);
            } except Exception {
                ;
            }
            assert decoded == {'a': 1} , f"json round-trip failed: {encoded}";
        } finally {
            stop_process(proc);
        }
    }
}
