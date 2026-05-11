"""Proof test: async routes don't actually run concurrently.

Every route in serve.endpoints.impl.jac is declared `async def` but every
walker runs synchronously on the event loop. Under any blocking IO call
(time.sleep, pymongo, redis-py, byllm) the loop is pinned for the full
duration and subsequent requests serialize.

Issue: #5486.

This test fires N concurrent slow walkers. If async is honest, total wall
clock is ~= SLOW_SEC. If the event loop is blocked, total wall clock is
~= N * SLOW_SEC.

Expected on current main: FAILS (wall-clock ~ N * SLOW_SEC).
Expected after async fix: PASSES (wall-clock ~ SLOW_SEC).
"""

import contextlib;
import gc;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from concurrent.futures { ThreadPoolExecutor, as_completed }

import requests;

glob FIXTURES_DIR = Path(__file__).parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

def register_user(base_url: str, username: str) -> str {
    res = requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert res.status_code == 201 , f"register failed: {res.status_code} {res.text}";
    login = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert login.status_code == 200 , f"login failed: {login.status_code} {login.text}";
    body = login.json();
    if isinstance(body, list) and len(body) == 2 {
        body = body[1];
    }
    return body["data"]["token"];
}

def start_server(fixtures_dir: Path, jac_file: Path, port: int) -> subprocess.Popen {
    import shutil;
    jac_executable = shutil.which("jac") or str(Path(sys.executable).parent / "jac");
    cmd = [str(jac_executable), "start", str(jac_file.name), "--port", str(port)];
    server = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir),
        env=os.environ.copy()
    );
    base_url = f"http://localhost:{port}";
    for _ in range(30) {
        try {
            r = requests.get(f"{base_url}/healthz", timeout=1);
            if r.status_code == 200 {
                return server;
            }
        } except Exception {
            time.sleep(1);
        }
    }
    (stdout, stderr) = server.communicate(timeout=2);
    raise RuntimeError(f"server failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}");
}

test "N concurrent slow walkers must complete in ~1 SLOW_SEC (async honesty)" {
    SLOW_SEC = 2.0;
    CONCURRENCY = 5;
    # If the event loop is unblocked, 5 parallel 2s sleeps finish in ~2s.
    # If the loop blocks per-walker, they serialize: ~10s + overhead.
    # Generous threshold: 2x slowest-acceptable concurrent wall-clock.
    MAX_ALLOWED_SEC = SLOW_SEC * 2.5;

    # Use SQLite backend — we want to prove blocking is loop-level, not driver-level.
    for k in ["MONGODB_URI", "REDIS_URL"] {
        os.environ.pop(k, None);
    }

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "slow_tester");

        def call_slow -> float {
            t0 = time.time();
            r = requests.post(
                f"{base_url}/walker/Slow",
                json={"seconds": SLOW_SEC},
                headers={"Authorization": f"Bearer {token}"},
                timeout=30
            );
            assert r.status_code == 200;
            return time.time() - t0;
        }

        # Warm up a single request first so connection/JIT overhead isn't
        # counted in the concurrent window.
        _ = call_slow();

        wall_start = time.time();
        with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool {
            futures = [pool.submit(call_slow) for _ in range(CONCURRENCY)];
            per_request = [f.result() for f in as_completed(futures)];
        }
        wall_elapsed = time.time() - wall_start;

        serialized_lower_bound = SLOW_SEC * CONCURRENCY * 0.9;

        assert wall_elapsed < MAX_ALLOWED_SEC , (
            f"ASYNC BLOCKED: {CONCURRENCY} concurrent {SLOW_SEC}s walkers "
            f"took {wall_elapsed:.2f}s wall-clock (>= {serialized_lower_bound:.2f}s "
            f"indicates serialized execution; < {MAX_ALLOWED_SEC:.2f}s would indicate "
            f"honest concurrency). Per-request latencies: "
            f"{[round(t, 2) for t in sorted(per_request)]}. "
            f"Every route is `async def` but every driver and byllm is blocking — "
            f"the event loop is pinned per walker. See issue #5486."
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}
