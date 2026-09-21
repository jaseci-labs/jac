"""End-to-end tests for /user/add-identity, /user/send-verification,
/user/verify-identity, /user/forgot-password, and /user/reset-password against
a server running with a fake in-process emailer (see
fixtures/identity_api/test_emailer_fake.jac).
"""

import contextlib;
import os;
import glob;
import shutil;
import subprocess;
import time;
import requests;
import from pathlib { Path }
import from jaclang.scale.tests.support {
    extract,
    get_free_port,
    register_user,
    start_server,
    stop_server
}

glob FIXTURES_DIR: Path = Path(__file__).parent.parent
         / "fixtures"
         / "identity_api";

# =============================================================================
# Helpers
# =============================================================================
def _cleanup {
    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for f in `glob.`glob(str(FIXTURES_DIR / pattern)) {
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

def _emailer_pythonpath -> dict[str, str] {
    # jac.toml names the provider by dotted path ('test_emailer_fake:FakeEmailer'),
    # so the fixture dir must be importable inside the server process.
    return {
        "PYTHONPATH": str(FIXTURES_DIR) + os.pathsep + os.environ.get("PYTHONPATH", "")
    };
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
        proc = start_server(
            FIXTURES_DIR, FIXTURES_DIR / "test_api.jac", port, env=_emailer_pythonpath()
        );
        primary = _unique_user("alice");
        secondary = f"{primary}_alt";
        email_addr = f"{primary}@example.com";
        token = register_user(base, primary, "pw12345");

        # 1. Unauthenticated → 401
        r = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "username", "value": "x"}},
            timeout=5
        );
        assert r.status_code == 401;

        # 2. Add second username → 200 added (verified=False).
        rj = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "username", "value": secondary}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert extract(rj)["status"] == "added";
        assert extract(rj)["verified"] == False;

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
        rj = requests.post(
            f"{base}/user/add-identity",
            json={"identity": {"type": "email", "value": email_addr}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert extract(rj)["status"] == "added";
        assert extract(rj)["verified"] == False;

        # 5. send-verification for that email → 202 pending_verification + mail sent.
        rj = requests.post(
            f"{base}/user/send-verification",
            json={"identity": {"type": "email", "value": email_addr}},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        ).json();
        assert extract(rj)["status"] == "pending_verification";
        assert extract(rj)["email_sent"] == True;

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
        stop_server(proc);
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
        proc = start_server(
            FIXTURES_DIR, FIXTURES_DIR / "test_api.jac", port, env=_emailer_pythonpath()
        );
        bob_user = _unique_user("bob");
        register_user(base, bob_user, "pw12345");

        # forgot-password for known user → 200.
        r = requests.post(
            f"{base}/user/forgot-password",
            json={"identity": {"type": "username", "value": bob_user}},
            timeout=5
        );
        assert r.status_code == 200;
        assert extract(r.json())["status"] == "ok";

        # forgot-password for unknown user → still 200 (no leak).
        r = requests.post(
            f"{base}/user/forgot-password",
            json={"identity": {"type": "username", "value": _unique_user("nobody")}},
            timeout=5
        );
        assert r.status_code == 200;
        assert extract(r.json())["status"] == "ok";

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
        stop_server(proc);
        _cleanup();
    }
}
