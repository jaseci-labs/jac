"""End-to-end tests for cross-user field-write enforcement on a served app.

Every HTTP request in a worker shares one Session and one identity-mapped
anchor dict, so a mutation that survives a permission denial in memory is
committed later by whichever authorized principal flushes next. These tests
drive a real `jac run --serve` subprocess with two registered users and
assert the denied write never becomes visible to the owner.
"""

import contextlib;
import glob;
import shutil;
import subprocess;
import time;
import uuid;
import requests;
import from pathlib { Path }
import from jaclang.scale.tests.support { get_free_port, register_user, start_server }

glob FIXTURES_DIR: Path = Path(__file__).parent.parent
         / "fixtures"
         / "acl_field_write";

def _cleanup_dbs {
    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for f in `glob.`glob(str(FIXTURES_DIR / pattern)) {
            with contextlib.suppress(Exception) {
                Path(f).unlink();
            }
        }
    }
}

def _cleanup {
    _cleanup_dbs();
    for sub in [".jac", "dist"] {
        d = FIXTURES_DIR / sub;
        if d.exists() {
            with contextlib.suppress(Exception) {
                shutil.rmtree(d);
            }
        }
    }
}

"""Boot the app once with a generous window so the one-time compile cost is
paid outside start_server's health-poll contract."""
def _prewarm {
    import from jaclang.scale.runtime.context.util { jac_executable }
    port = get_free_port();
    proc = subprocess.Popen(
        [jac_executable(), "run", "--serve", "--port", str(port), "app.jac"],
        cwd=str(FIXTURES_DIR),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    );
    try {
        for _ in range(300) {
            if proc.poll() is not None {
                break;
            }
            try {
                r = requests.get(f"http://localhost:{port}/healthz", timeout=1);
                if r.status_code == 200 {
                    break;
                }
            } except Exception {
                time.sleep(1);
            }
        }
    } finally {
        proc.terminate();
        with contextlib.suppress(Exception) {
            proc.`wait(timeout=10);
        }
        _cleanup_dbs();
    }
}

"""POST /function/<name> with a bearer token; return the full response body."""
def _call(
    base_url: str, name: str, token: str, payload: dict[str, any]
) -> dict[str, any] {
    res = requests.post(
        f"{base_url}/function/{name}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=15
    );
    body = res.json();
    if isinstance(body, list) and len(body) == 2 {
        body = body[1];
    }
    assert isinstance(body, dict) , f"unexpected body: {body!r}";
    return body;
}

def _result(body: dict[str, any]) -> dict[str, any] {
    data = body.get("data");
    assert isinstance(data, dict) , f"no data in {body!r}";
    result = data.get("result");
    assert isinstance(result, dict) , f"no result in {data!r}";
    return result;
}

def _field_write_denials(body: dict[str, any]) -> list[any] {
    data = body.get("data");
    warnings = data.get("warnings", []) if isinstance(data, dict) else [];
    return [
        w
        for w in warnings
        if isinstance(w, dict) and w.get("operation") == "field_write"
    ];
}

test "denied field write is not laundered by a later authorized flush" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    _prewarm();
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        run = uuid.uuid4().hex[:8];
        tok_owner = register_user(base, f"acl_owner_{run}");
        tok_reader = register_user(base, f"acl_reader_{run}");

        reader_root = _result(_call(base, "whoami", tok_reader, {}))["root"];
        doc_id = _result(_call(base, "make_doc", tok_owner, {}))["id"];
        _call(base, "share_read", tok_owner, {"id": doc_id, "to_root": reader_root});

        # Positive control: the READ grant works before anything is denied.
        seen = _result(_call(base, "read_doc", tok_reader, {"id": doc_id}));
        assert seen["found"] , "reader cannot resolve the shared doc";
        assert seen["body"] == "original" , f"grant broken: {seen!r}";

        # READ-only reader attempts the write.
        attempt = _call(
            base, "write_doc", tok_reader, {"id": doc_id, "body": "TAMPERED"}
        );
        denials = _field_write_denials(attempt);
        assert denials , f"expected a field_write denial, got {attempt!r}";

        # The denied assignment must not stick to the shared in-memory anchor.
        body_now = _result(attempt)["body_now"];
        assert body_now == "original" , (
            f"denied write mutated the shared anchor: body_now={body_now!r}"
        );

        # Owner performs an ordinary write-bearing request of their own.
        _result(_call(base, "make_doc", tok_owner, {}));

        # The owner must still see their own value, in memory and at rest.
        after = _result(_call(base, "read_doc", tok_owner, {"id": doc_id}));
        assert after["body"] == "original" , (
            f"denied write was laundered into the store: {after!r}"
        );
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.`wait(timeout=10);
        }
        _cleanup();
    }
}

test "owner writes are unaffected by the gate" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    _prewarm();
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        run = uuid.uuid4().hex[:8];
        tok = register_user(base, f"acl_solo_{run}");
        doc_id = _result(_call(base, "make_doc", tok, {}))["id"];
        wrote = _call(base, "write_doc", tok, {"id": doc_id, "body": "mine"});
        assert not _field_write_denials(wrote) , f"owner write denied: {wrote!r}";
        assert _result(wrote)["body_now"] == "mine";
        got = _result(_call(base, "read_doc", tok, {"id": doc_id}));
        assert got["body"] == "mine" , f"owner write lost: {got!r}";
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.`wait(timeout=10);
        }
        _cleanup();
    }
}
