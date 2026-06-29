"""End-to-end tests for /user/add-identity, /user/send-verification,
/user/verify-identity, /user/forgot-password, and /user/reset-password against
a server running with a fake in-process emailer (see
fixtures/identity_api/test_emailer_fake.jac).
"""

import contextlib;
import gc;
import glob;
import shutil;
import socket;
import subprocess;
import sys;
import time;
import requests;
import from pathlib { Path }
import from typing { Any }
import from jaclang.scale.tests.auth_test_helpers {
    data as _data,
    register_and_login as _register_and_login
}
import from jaclang.scale.tests.server_support { get_free_port }

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures" / "identity_api";

# =============================================================================
# Helpers
# =============================================================================
def _cleanup {
    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for f in glob.glob(str(FIXTURES_DIR / pattern)) {
            with contextlib.suppress(Exception) {
                Path(f).unlink();
            }
        }
    }
    jac_dir = FIXTURES_DIR / ".jac";
    if jac_dir.exists() {
        with contextlib.suppress(Exception) {
            shutil.rmtree(jac_dir);
        }
    }
}

def _unique_user(prefix: str) -> str {
    # Repo-root .jac/data/users.db accumulates across tests, so each run
    # picks a fresh username to avoid collisions with prior state.
    import time;
    return f"{prefix}_ident_{int(time.time() * 1000)}";
}

def _start_server(port: int) -> subprocess.Popen {
    import os;
    base_url = f"http://localhost:{port}";
    jac_exe = Path(sys.executable).parent / "jac";
    # Make the fake-emailer Python module discoverable by the dotted-path
    # provider in jac.toml ('test_emailer_fake:FakeEmailer').
    env = dict(os.environ);
    env['PYTHONPATH'] = str(FIXTURES_DIR) + os.pathsep + env.get('PYTHONPATH', '');
    proc = subprocess.Popen(
        [str(jac_exe), "start", "test_api.jac", "--port", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(FIXTURES_DIR),
        env=env
    );
    for _ in range(60) {
        if proc.poll() is not None {
            (out, err) = proc.communicate();
            raise RuntimeError(f"Server died.\nSTDOUT: {out}\nSTDERR: {err}");
        }
        try {
            r = requests.get(f"{base_url}/healthz", timeout=2);
            if r.status_code == 200 {
                return proc;
            }
        } except requests.RequestException {
            time.sleep(0.5);
        }
    }
    proc.terminate();
    proc.wait();
    raise RuntimeError("Server failed to start within 30s");
}

def _stop_server(proc: subprocess.Popen | None) {
    if proc {
        proc.terminate();
        with contextlib.suppress(subprocess.TimeoutExpired) {
            proc.wait(timeout=5);
        }
        with contextlib.suppress(Exception) {
            proc.kill();
            proc.wait();
        }
    }
    time.sleep(0.2);
    gc.collect();
}

# =============================================================================
# Test 1: add-identity + send-verification contract
# =============================================================================
test "add_identity_contract" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    proc: subprocess.Popen | None = None;
    try {
        proc = _start_server(port);
        primary = _unique_user("alice");
        secondary = f"{primary}_alt";
        email_addr = f"{primary}@example.com";
        token = _register_and_login(base, primary, "pw12345");

        # 1. Unauthenticated → 401
        r = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "username", "value": "x"}},
            timeout=5
        );
        assert r.status_code == 401;

        # 2. Add second username → 200 added (verified=False).
        r = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "username", "value": secondary}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert _data(r)["status"] == "added";
        assert _data(r)["verified"] == False;

        # 3. Duplicate identity → 409 IDENTITY_TAKEN.
        r = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "username", "value": primary}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert r.status_code == 409;
        assert r.json()["error"]["code"] == "IDENTITY_TAKEN";

        # 4. Add an email → 200 added, verified=False, NO email sent yet.
        r = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "email", "value": email_addr}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert _data(r)["status"] == "added";
        assert _data(r)["verified"] == False;

        # 5. send-verification for that email → 202 pending_verification + mail sent.
        r = requests.post(
            f"{base}/user/send-verification",
            json={"identity": {"type": "email", "value": email_addr}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert _data(r)["status"] == "pending_verification";
        assert _data(r)["email_sent"] == True;

        # 6. send-verification with no auth → 401.
        r = requests.post(
            f"{base}/user/send-verification",
            json={"identity": {"type": "email", "value": email_addr}},
            timeout=5
        );
        assert r.status_code == 401;

        # 7. send-verification for an email NOT on this user → 404.
        r = requests.post(
            f"{base}/user/send-verification",
            json={"identity": {"type": "email", "value": "not-mine@example.com"}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert r.status_code == 404;
    } finally {
        _stop_server(proc);
        _cleanup();
    }
}

# =============================================================================
# Test 2: forgot-password never leaks existence + reset-password rejects bad tokens
# =============================================================================
test "forgot_and_reset_password_contract" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    proc: subprocess.Popen | None = None;
    try {
        proc = _start_server(port);
        bob_user = _unique_user("bob");
        _register_and_login(base, bob_user, "pw12345");

        # forgot-password for known user → 200.
        r = requests.post(
            f"{base}/user/forgot-password",
            json={"identity": {"type": "username", "value": bob_user}},
            timeout=5
        );
        assert r.status_code == 200;
        assert _data(r.json())["status"] == "ok";

        # forgot-password for unknown user → still 200 (no leak).
        r = requests.post(
            f"{base}/user/forgot-password",
            json={"identity": {"type": "username", "value": _unique_user("nobody")}},
            timeout=5
        );
        assert r.status_code == 200;
        assert _data(r.json())["status"] == "ok";

        # reset-password with bogus token → 400 INVALID_TOKEN.
        r = requests.post(
            f"{base}/user/reset-password",
            json={"token": "not-a-real-token", "new_password": "newpw"},
            timeout=5
        );
        assert r.status_code == 400;
        assert r.json()["error"]["code"] == "INVALID_TOKEN";

        # verify-identity with bogus token → 400 INVALID_TOKEN.
        r = requests.post(
            f"{base}/user/verify-identity", json={"token": "bogus"}, timeout=5
        );
        assert r.status_code == 400;
        assert r.json()["error"]["code"] == "INVALID_TOKEN";
    } finally {
        _stop_server(proc);
        _cleanup();
    }
}
