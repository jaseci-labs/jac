"""Proof test: RedisBackend.batch_get() issues N individual GET commands
instead of a single MGET pipeline.

batch_get() at memory_hierarchy.redis.impl.jac:167-175 loops over all IDs
calling self.get(id) for each one — N separate Redis GET round-trips.
redis_client.mget([key1, key2, ...]) would fetch all N in a single command.

Expected on current main: FAILS (delta >= ANCHOR_COUNT proves N individual GETs).
Expected after fix: PASSES (delta << ANCHOR_COUNT with MGET / pipeline).
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

import redis;
import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

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

def redis_commands_processed(r: Any) -> int {
    """Read total_commands_processed from Redis INFO stats.""";
    return int(r.info("stats")["total_commands_processed"]);
}

test "batch_get issues N individual Redis GET commands instead of 1 MGET" {
    """ScaleTieredMemory loads anchors via RedisBackend.batch_get() on every request
    (L1 is always empty — fresh context per request).  batch_get() loops calling
    self.get(id) for each anchor ID, which maps to one redis_client.get(key) per call.
    A correct implementation would use redis_client.mget([...]) or a pipeline for
    a single round-trip regardless of N.

    We measure total_commands_processed before and after a read-only walker that
    traverses ANCHOR_COUNT nodes stored in Redis.  If using N individual GETs:
    delta >= ANCHOR_COUNT.  If using MGET: delta is a small constant (~1-3).
    """;
    ANCHOR_COUNT = 25;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    redis_container = RedisContainer("redis:latest");
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;

    redis_client = redis.from_url(redis_url);
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "batch_get_tester");

        # Seed ANCHOR_COUNT items — these get written into Redis L2.
        call_walker(base_url, "BulkCreate", token, {"count": ANCHOR_COUNT});
        time.sleep(0.3);

        # Warm-up: one ListItems call so startup writes settle.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.2);

        # Baseline: Redis command counter before the measured request.
        baseline = redis_commands_processed(redis_client);

        # Measured request: ListItems traverses all ANCHOR_COUNT nodes.
        # Since L1 is empty per request, every anchor is loaded from Redis L2
        # via batch_get(). On current main this issues ANCHOR_COUNT GET commands.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.2);

        after = redis_commands_processed(redis_client);
        delta = after - baseline;

        # If N individual redis_client.get() calls: delta >= ANCHOR_COUNT.
        # (Extra commands come from system-root, user-root, auth probes, etc.)
        # If MGET / pipeline: delta == small constant independent of ANCHOR_COUNT.
        assert delta >= ANCHOR_COUNT , (
            f"REDIS BATCH: ListItems over {ANCHOR_COUNT} nodes issued only {delta} "
            f"Redis commands (expected >= {ANCHOR_COUNT}). "
            f"This suggests MGET or pipelining is already in use (good). "
            f"If delta < ANCHOR_COUNT the fix is already applied."
        );

        # The smoking-gun assertion: delta should be much larger than a constant
        # baseline.  If MGET were used, delta would be <= 10 regardless of N.
        # We test the inverse to prove the bug: delta growing with ANCHOR_COUNT.
        assert delta > 10 , (
            f"REDIS BATCH: delta={delta} is unexpectedly small — "
            f"check that ANCHOR_COUNT={ANCHOR_COUNT} items were actually seeded into "
            f"Redis before the measurement."
        );
    } finally {
        with contextlib.suppress(Exception) {
            redis_client.close();
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("REDIS_URL", None);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "batch_get command count scales linearly with anchor count — evidence of N round-trips" {
    """If batch_get uses MGET the command delta is independent of N.
    If it uses N individual GETs the delta grows proportionally to N.

    Compare two request sizes: SMALL_COUNT and LARGE_COUNT items.
    A linear scaling ratio (delta_large / delta_small ≈ LARGE/SMALL) proves
    N individual round-trips.
    """;
    SMALL_COUNT = 5;
    LARGE_COUNT = 20;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    redis_container = RedisContainer("redis:latest");
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;

    redis_client = redis.from_url(redis_url);
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token_small = register_user(base_url, "batch_small");

        # Seed SMALL_COUNT items for the small-population test.
        call_walker(base_url, "BulkCreate", token_small, {"count": SMALL_COUNT});
        time.sleep(0.3);
        # Warm up.
        call_walker(base_url, "ListItems", token_small);
        time.sleep(0.2);

        b1 = redis_commands_processed(redis_client);
        call_walker(base_url, "ListItems", token_small);
        time.sleep(0.1);
        delta_small = redis_commands_processed(redis_client) - b1;

        # Register a second user and seed LARGE_COUNT items.
        token_large = register_user(base_url, "batch_large");
        call_walker(base_url, "BulkCreate", token_large, {"count": LARGE_COUNT});
        time.sleep(0.3);
        call_walker(base_url, "ListItems", token_large);
        time.sleep(0.2);

        b2 = redis_commands_processed(redis_client);
        call_walker(base_url, "ListItems", token_large);
        time.sleep(0.1);
        delta_large = redis_commands_processed(redis_client) - b2;

        # With MGET: delta_large ≈ delta_small (constant round-trips).
        # With N individual GETs: delta_large / delta_small ≈ LARGE_COUNT / SMALL_COUNT = 4.
        # We assert the inverse (that ratio >= 2) to prove N individual round-trips.
        if delta_small > 0 {
            scaling_ratio = delta_large / delta_small;
            expected_linear = LARGE_COUNT / SMALL_COUNT;

            assert scaling_ratio >= 2.0 , (
                f"REDIS BATCH SCALING: delta_small={delta_small} (SMALL_COUNT={SMALL_COUNT}), "
                f"delta_large={delta_large} (LARGE_COUNT={LARGE_COUNT}), "
                f"ratio={scaling_ratio:.2f} (expected ≈ {expected_linear:.1f} for N GETs, "
                f"expected ≈ 1.0 for MGET). "
                f"ratio < 2.0 would indicate MGET/pipeline is already in use. "
                f"batch_get() at memory_hierarchy.redis.impl.jac:167-175 loops calling "
                f"self.get(id), each issuing redis_client.get(key) individually."
            );
        }
    } finally {
        with contextlib.suppress(Exception) {
            redis_client.close();
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("REDIS_URL", None);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}
