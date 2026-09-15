"""End-to-end tests for the app-facing token API on a served app.

Drives a real `jac run --serve` subprocess: single-use redemption, expiry,
revocation, purpose isolation, and the concurrent double-consume drill in
which exactly one of N parallel accepts may win.
"""

import contextlib;
import glob;
import shutil;
import subprocess;
import time;
import uuid;
import requests;
import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }
import from jaclang.scale.tests.support { get_free_port, register_user, start_server }

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures" / "app_tokens";

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

def _call(base: str, name: str, token: str, payload: dict[str, any]) -> dict[str, any] {
    res = requests.post(
        f"{base}/function/{name}",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
        timeout=20
    );
    body = res.json();
    if isinstance(body, list) and len(body) == 2 {
        body = body[1];
    }
    data = body.get("data") if isinstance(body, dict) else None;
    result = data.get("result") if isinstance(data, dict) else None;
    assert isinstance(result, dict) , f"unexpected body for {name}: {body!r}";
    return result;
}

test "invitation tokens: single use, expiry, revocation, purpose isolation" {
    _cleanup();
    port = get_free_port();
    base = f"http://localhost:{port}";
    _prewarm();
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        run = uuid.uuid4().hex[:8];
        auth = register_user(base, f"tok_owner_{run}");

        # Round trip with payload.
        tok = _call(base, "invite", auth, {"role": "viewer", "ttl": 60})["token"];
        assert _call(base, "peek", auth, {"token": tok})["found"];
        got = _call(base, "accept", auth, {"token": tok});
        assert got["ok"] and got["role"] == "viewer" , f"got {got!r}";

        # Single use: a second redeem loses.
        again = _call(base, "accept", auth, {"token": tok});
        assert not again["ok"] , "token redeemed twice";

        # Purpose isolation: a different purpose cannot redeem it.
        tok2 = _call(base, "invite", auth, {"role": "admin", "ttl": 60})["token"];
        wrong = _call(base, "accept_other_purpose", auth, {"token": tok2});
        assert not wrong["ok"] , "cross-purpose redeem succeeded";
        assert _call(base, "accept", auth, {"token": tok2})["ok"];

        # Expiry.
        tok3 = _call(base, "invite", auth, {"role": "viewer", "ttl": 1})["token"];
        time.sleep(2);
        assert not _call(base, "accept", auth, {"token": tok3})["ok"] , (
            "expired token redeemed"
        );

        # Revocation by subject.
        tok4 = _call(base, "invite", auth, {"role": "viewer", "ttl": 60})["token"];
        revoked = _call(base, "cancel_all", auth, {})["revoked"];
        assert revoked >= 1 , f"revoke reported {revoked}";
        assert not _call(base, "accept", auth, {"token": tok4})["ok"] , (
            "revoked token redeemed"
        );

        # Concurrent double-consume: exactly one of 8 parallel accepts wins.
        tok5 = _call(base, "invite", auth, {"role": "viewer", "ttl": 60})["token"];
        def _try_accept(_i: int) -> bool {
            with contextlib.suppress(Exception) {
                return _call(base, "accept", auth, {"token": tok5})["ok"];
            }
            return False;
        }
        with ThreadPoolExecutor(max_workers=8) as pool {
            wins = list(pool.map(_try_accept, range(8)));
        }
        assert wins.count(True) == 1 , (
            f"expected exactly one winner, got {wins.count(True)} of {len(wins)}"
        );
    } finally {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.`wait(timeout=10);
        }
        _cleanup();
    }
}
