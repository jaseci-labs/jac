"""Proof test: L2 Redis cache has no TTL — anchor keys never expire.

Every anchor written through ScaleTieredMemory is stored in Redis with
redis_client.set(key, data) when redis_default_ttl is 0 (the default).
Keys have TTL = -1 (never expire). As the graph grows, Redis memory grows
monotonically. There is no application-level eviction policy.

Expected on current main: FAILS (keys have TTL=-1, dbsize never shrinks).
Expected after fix: PASSES (TTL > 0 or LRU eviction configured).
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

test "L2 Redis: anchor keys have no TTL (default config — memory leak)" {
    """Every anchor is cached in Redis with redis_client.set(key, value) when
    redis_default_ttl is 0. TTL = -1 means the key never expires. Redis memory
    grows without bound as more anchors are written.

    This test creates BATCH_SIZE nodes, then inspects every anchor key in Redis
    and asserts that all keys have TTL = -1 (i.e., will never expire).
    """;
    BATCH_SIZE = 20;

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
        token = register_user(base_url, "leak_tester");
        # Seed: create BATCH_SIZE Item nodes in a single walker call.
        call_walker(base_url, "BulkCreate", token, {"count": BATCH_SIZE});
        # Small pause to allow async commit to complete.
        time.sleep(0.5);

        # Inspect every key Redis holds.
        all_keys = redis_client.keys("*");
        assert len(all_keys) > 0 , (
            "Redis is empty after BulkCreate — "
            "either the server didn't use Redis or commit path is broken."
        );

        no_ttl_keys: list = [];
        for key in all_keys {
            ttl = redis_client.ttl(key);
            # TTL -1 == no expiry set; TTL -2 == key doesn't exist (shouldn't happen).
            if ttl == -1 {
                no_ttl_keys.append(key);
            }
        }

        assert len(no_ttl_keys) == 0 , (
            f"MEMORY LEAK: {len(no_ttl_keys)}/{len(all_keys)} Redis keys have "
            f"TTL=-1 (never expire). "
            f"redis_default_ttl defaults to 0 in _get_db_config(), which causes "
            f"redis_client.set(key, value) with no expiry. "
            f"Every anchor ever written accumulates permanently in Redis. "
            f"Sample keys with no TTL: {[k.decode() for k in no_ttl_keys[:5]]}. "
            f"See memory_hierarchy.redis.impl.jac:71-79."
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

test "L2 Redis: dbsize grows monotonically — no eviction across request batches" {
    """Send three batches of BATCH_SIZE creates each, measuring Redis dbsize after
    each batch. Redis should grow. With a correct eviction policy it would plateau;
    with no TTL and no maxmemory-policy it grows without bound.

    This test proves the monotonic growth path — fixing it requires either
    a per-anchor TTL or an LRU eviction policy.
    """;
    BATCH_SIZE = 10;
    BATCHES = 3;

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
        token = register_user(base_url, "growth_tester");
        sizes: list[int] = [];

        for batch in range(BATCHES) {
            call_walker(base_url, "BulkCreate", token, {"count": BATCH_SIZE});
            time.sleep(0.3);
            sizes.append(redis_client.dbsize());
        }

        # Each batch should add keys — Redis size must strictly increase.
        for i in range(1, len(sizes)) {
            assert sizes[i] > sizes[i - 1] , (
                f"Redis dbsize did not grow after batch {i}: "
                f"{sizes}. This batch's anchors may not have been cached."
            );
        }

        # Flush Redis and verify keys are gone — then re-run a batch and confirm
        # they come back: proves the cache is the leak source, not MongoDB.
        redis_client.flushall();
        assert redis_client.dbsize() == 0;
        call_walker(base_url, "BulkCreate", token, {"count": BATCH_SIZE});
        time.sleep(0.3);
        size_after_flush = redis_client.dbsize();
        assert size_after_flush > 0 , (
            "After flushall+BulkCreate Redis is still empty — "
            "commit path is not writing to Redis."
        );

        # The key assertion: none of these re-added keys have a TTL.
        keys = redis_client.keys("*");
        no_ttl = [
            k
            for k in keys
            if redis_client.ttl(k) == -1
        ];
        assert no_ttl , (
            f"All {len(keys)} keys have a TTL set after reflush — "
            f"this test is no longer relevant; the leak may already be fixed."
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
