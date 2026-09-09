"""End-to-end tests for fail-closed root binding on a served app.

A request that asserts a caller identity whose stored root cannot be bound
must be rejected with a 401, never continued on the execution context's
existing (system) root and never surfaced as a 500 traceback. Drives a real
`jac run --serve` subprocess; the fault is injected with real SQL against the
server's identity store through a fixture endpoint.
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

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures" / "root_bind";

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

def _whoami(base: str, token: str) -> requests.Response {
    res = requests.post(
        f"{base}/function/whoami",
        json={},
        headers={"Authorization": f"Bearer {token}"},
        timeout=15
    );
    return res;
}

def _corrupt(base: str, username: str, new_root_id: str) -> dict {
    res = requests.post(
        f"{base}/function/corrupt_root",
        json={"username": username, "new_root_id": new_root_id},
        timeout=15
    );
    body = res.json();
    if isinstance(body, list) and len(body) == 2 {
        body = body[1];
    }
    return body;
}

test "unresolvable and malformed root ids are rejected with 401, not 500" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    _prewarm();
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        run = uuid.uuid4().hex[:8];
        user = f"bindfail_{run}";
        token = register_user(base, user);

        # Positive control: the bind works before the fault is injected.
        assert _whoami(base, token).status_code == 200 , "control request failed";

        # Variant 1: well-formed UUID that resolves to no anchor.
        ghost = uuid.uuid4().hex;
        injected = _corrupt(base, user, ghost);
        assert injected.get("data", {}).get("result", {}).get("ok") , (
            f"fault injection failed: {injected!r}"
        );
        res = _whoami(base, token);
        assert res.status_code == 401 , (
            f"unresolvable root must be rejected with 401, got {res.status_code}"
        );
        assert res.json().get("error", {}).get("code") == "IDENTITY_UNRESOLVABLE" , res.text;

        # Variant 2: malformed root id.
        injected = _corrupt(base, user, "not-a-uuid");
        assert injected.get("data", {}).get("result", {}).get("ok") , (
            f"fault injection failed: {injected!r}"
        );
        res = _whoami(base, token);
        assert res.status_code == 401 , (
            f"malformed root must be rejected with 401, got {res.status_code}"
        );
        assert res.json().get("error", {}).get("code") == "IDENTITY_UNRESOLVABLE" , res.text;

        # A fresh user is unaffected.
        other = register_user(base, f"bindok_{run}");
        assert _whoami(base, other).status_code == 200 , "healthy user was rejected";
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.`wait(timeout=10);
        }
        _cleanup();
    }
}
