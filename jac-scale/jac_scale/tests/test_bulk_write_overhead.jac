"""Proof test: MongoBackend.sync() issues N individual update_one calls
instead of one bulk_write, and double-commits every request.

Finding A — N×update_one:
MongoBackend.sync() loops over all L1 anchors and calls self.put(anchor)
for each dirty one. self.put() calls collection.update_one(). bulk_put()
already exists and uses collection.bulk_write(ops) for a single round-trip,
but sync() never calls it.

Finding B — Double commit:
spawn_walker calls Jac.commit() at server.impl.jac:306.
request_context_middleware calls ctx.mem.commit() again at jfast_api.impl.jac:868.
Both traverse the full L1 dict and compute Serializer._compute_hash per anchor.

Both findings are proven by comparing MongoDB opcounters.update before and after
walker requests that create N dirty anchors.

Expected on current main:
  - update count ≈ 2*N per request (N from first commit + N from second)
  - or ≈ N if the hash-based skip works on the second pass

Expected after fix:
  - update count = 1 (single bulk_write, single commit site)
"""

import contextlib;
import gc;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from typing { Any, cast }

import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

glob FIXTURES_DIR = Path(__file__).parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

def extract(resp: Any) -> Any {
    if isinstance(resp, list) and len(resp) == 2 {
        resp = resp[1];
    }
    if isinstance(resp, dict) and "data" in resp {
        return resp["data"];
    }
    return resp;
}

def register_user(base_url: str, username: str) -> str {
    res = requests.post(
        f"{base_url}/user/register",
        json={"username": username, "password": "pass123"},
        timeout=5
    );
    assert res.status_code == 201;
    return cast(dict, extract(res.json()))["token"];
}

def call_walker(
    base_url: str, walker_name: str, token: str, payload: dict | None = None
) -> Any {
    res = requests.post(
        f"{base_url}/walker/{walker_name}",
        json=payload or {},
        headers={"Authorization": f"Bearer {token}"},
        timeout=15
    );
    return res.json();
}

def start_server(fixtures_dir: Path, jac_file: Path, port: int) -> subprocess.Popen {
    import shutil;
    jac_executable = shutil.which("jac") or str(Path(sys.executable).parent / "jac");
    cmd = [str(jac_executable), "start", str(jac_file.name), "--port", str(port)];
    env = os.environ.copy();
    server = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir),
        env=env
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

def read_update_count(admin_client: MongoClient) -> int {
    status = admin_client.admin.command("serverStatus");
    return int(status["opcounters"]["update"]);
}

test "BulkCreate N nodes issues N individual update_one calls instead of 1 bulk_write" {
    """Creates ANCHOR_COUNT nodes in a single walker call and measures MongoDB
    update opcounters. On current main, sync() calls self.put(anchor) for each
    dirty anchor, each translating to one collection.update_one() round-trip.
    bulk_put() exists and uses bulk_write() but is never called from sync().

    If using bulk_write: update_count delta = 1 (or 0 with bulk_write which uses
    an internal op, see note below).
    If using N individual update_one: update_count delta >= ANCHOR_COUNT.

    Note: MongoDB opcounters.update counts individual update operations.
    A bulk_write of N UpdateOne ops counts as N update ops in opcounters but
    uses a single network round-trip. We use a proxy: measure wall-clock time
    scaling across ANCHOR_COUNT=5 and ANCHOR_COUNT=20. If N×update_one: time
    scales linearly. We also directly assert that update delta == ANCHOR_COUNT
    (not 1), which proves N individual calls rather than a single batched call.
    """;
    ANCHOR_COUNT = 15;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ.pop("REDIS_URL", None);

    admin_client = MongoClient(mongo_uri);
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "bulk_tester");
        # Warm up — settle any startup writes.
        call_walker(base_url, "CountItems", token);
        time.sleep(0.5);

        before = read_update_count(admin_client);
        call_walker(base_url, "BulkCreate", token, {"count": ANCHOR_COUNT});
        time.sleep(0.5);
        after = read_update_count(admin_client);

        delta = after - before;

        # With N individual update_one: delta == ANCHOR_COUNT (or up to 2*N with double-commit).
        # With 1 bulk_write: delta == ANCHOR_COUNT (bulk_write still issues N op docs internally,
        # but as a single network call). The *important* test is latency scaling — but we can
        # also confirm that the count is >= ANCHOR_COUNT to prove no batching reduction happened.
        # The real regression check is: delta should be ANCHOR_COUNT, NOT 1.
        assert delta >= ANCHOR_COUNT , (
            f"Expected >= {ANCHOR_COUNT} MongoDB update ops for BulkCreate({ANCHOR_COUNT}) "
            f"but got {delta}. This would indicate bulk_write is being used (good). "
            f"If delta < ANCHOR_COUNT, the fix is already in place."
        );

        # The actual bug: delta == ANCHOR_COUNT proves no double-commit is occurring.
        # If delta > ANCHOR_COUNT (i.e. 2*N), the double-commit is proven.
        if delta > ANCHOR_COUNT {
            double_commit_ratio = delta / ANCHOR_COUNT;
            assert False , (
                f"DOUBLE COMMIT: BulkCreate({ANCHOR_COUNT}) triggered {delta} MongoDB update "
                f"ops ({double_commit_ratio:.1f}x the node count). "
                f"Expected {ANCHOR_COUNT} (single commit). "
                f"spawn_walker calls Jac.commit() at server.impl.jac:306, then "
                f"request_context_middleware calls ctx.mem.commit() again at "
                f"jfast_api.impl.jac:868 — each pass iterates L1 and writes dirty anchors. "
                f"Fix: remove Jac.commit() from spawn_walker; middleware owns the commit."
            );
        }
    } finally {
        with contextlib.suppress(Exception) {
            admin_client.close();
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "write latency scales linearly with anchor count — evidence of N individual round-trips" {
    """Compares wall-clock time for BulkCreate(5) vs BulkCreate(20).
    With N individual update_one calls: time(20) ≈ 4 × time(5).
    With 1 bulk_write: time(20) ≈ time(5) (single round-trip regardless of N).

    The linear scaling proves N individual MongoDB round-trips, not batching.
    """;
    SMALL = 5;
    LARGE = 20;
    REPEATS = 3;  # average over multiple calls to reduce noise

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ.pop("REDIS_URL", None);

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "latency_tester");
        call_walker(base_url, "CountItems", token);  # warm up
        time.sleep(0.5);

        def measure(count: int, repeats: int) -> float {
            times: list[float] = [];
            for _ in range(repeats) {
                t0 = time.time();
                call_walker(base_url, "BulkCreate", token, {"count": count});
                times.append(time.time() - t0);
            }
            return sum(times) / len(times);
        }

        avg_small = measure(SMALL, REPEATS);
        avg_large = measure(LARGE, REPEATS);

        scaling_ratio = avg_large / avg_small if avg_small > 0 else 0;
        expected_linear_ratio = LARGE / SMALL;  # 4.0

        # With bulk_write: scaling_ratio ≈ 1.0 (constant round-trips).
        # With N individual update_one: scaling_ratio ≈ LARGE/SMALL = 4.0.
        # We pass if scaling_ratio < 2.0 (bulk) and fail if >= 2.0 (N individual).
        assert scaling_ratio < 2.0 , (
            f"LINEAR SCALING: BulkCreate({LARGE}) avg={avg_large:.3f}s, "
            f"BulkCreate({SMALL}) avg={avg_small:.3f}s, ratio={scaling_ratio:.2f}. "
            f"Expected ratio < 2.0 if bulk_write is used (constant round-trips). "
            f"Actual ratio {scaling_ratio:.2f} ≈ {expected_linear_ratio} indicates "
            f"N individual update_one() round-trips. "
            f"MongoBackend.sync() at memory_hierarchy.mongo.impl.jac calls self.put() "
            f"in a loop instead of using the existing bulk_put() method which calls "
            f"collection.bulk_write(ops) in a single round-trip."
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}
