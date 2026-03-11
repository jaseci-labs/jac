"""GTI Redis topology tests for jac-scale.

Tests the Redis/MongoDB path of the Graph Topology Index (GTI):
  - Qualified type names written to Redis after graph build
  - MRO fan-out: PostNode keys also populate BaseContent keys
  - Typed traversal (QueryByBase) returns correct results via GTI
  - Edge deletion removes the target from Redis topology keys
  - migrate_to_qualified_types: bare-name keys flushed, qualified restored

Requires Docker (testcontainers) and is therefore separated from the
pure-SQLite tests in tests/runtimelib/test_graph_index.jac.

All tests start a fresh Redis + MongoDB testcontainer pair and a jac
server subprocess pointing at fixtures/gti_scale_app.jac.
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
     GTI_JAC_FILE = FIXTURES_DIR / "gti_scale_app.jac";

glob MODULE_PREFIX = "gti_scale_app";
glob TOPO_PREFIX = "jac:topo";

# ---------------------------------------------------------------------------
# Shared helpers (mirrors test_memory_hierarchy.jac helpers)
# ---------------------------------------------------------------------------

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

def start_server(jac_file: Path, port: int) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [str(jac_executable), "start", str(jac_file.name), "--port", str(port)];
    server = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(FIXTURES_DIR),
        env=os.environ.copy()
    );
    base_url = f"http://localhost:{port}";
    for _ in range(30) {
        try {
            r = requests.get(f"{base_url}/docs", timeout=1);
            if r.status_code in (200, 404) {
                return server;
            }
        } except Exception {
            time.sleep(1);
        }
    }
    (stdout, stderr) = server.communicate(timeout=2);
    raise RuntimeError(
        f"jac start failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
    );
}

def stop_server(server: subprocess.Popen) -> None {
    if server {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
    }
}

def post_walker(base_url: str, walker_name: str, payload: dict) -> dict[str, Any] {
    res = requests.post(
        f"{base_url}/walker/{walker_name}",
        json=payload,
        timeout=5
    );
    assert res.status_code == 200 , (
        f"Walker {walker_name} failed: {res.status_code} - {res.text}"
    );
    body = res.json();
    # Unwrap TransportResponse envelope
    if isinstance(body, list) and len(body) == 2 {
        body = body[1];
    }
    if isinstance(body, dict) and "data" in body {
        body = body["data"];
    }
    return cast(dict[str, Any], body);
}

"""Return all Redis keys matching pattern (glob)."""
def topo_keys(redis_client: object, pattern: str) -> list[bytes] {
    return redis_client.keys(pattern);
}

"""Start Redis + MongoDB testcontainers, set env vars. Returns (redis_client, mongo_client, redis_container, mongo_container)."""
def setup_containers -> tuple {
    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    redis_client = redis.Redis(
        host=redis_host, port=int(redis_port), decode_responses=True
    );

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    mongo_client = MongoClient(mongo_uri);

    os.environ["REDIS_URL"] = redis_url;
    os.environ["MONGODB_URI"] = mongo_uri;

    return (redis_client, mongo_client, redis_container, mongo_container);
}

def teardown_containers(
    server: subprocess.Popen,
    redis_container: object,
    mongo_container: object,
    mongo_client: object
) -> None {
    stop_server(server);
    system_dbs = {"admin", "config", "local"};
    for db_name in mongo_client.list_database_names() {
        if db_name not in system_dbs {
            mongo_client.drop_database(db_name);
        }
    }
    redis_container.stop();
    mongo_container.stop();
    for key in ["REDIS_URL", "MONGODB_URI"] {
        os.environ.pop(key, None);
    }
    time.sleep(0.5);
    gc.collect();
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }
}

# ---------------------------------------------------------------------------
# Group 1 — Qualified names in Redis
# ---------------------------------------------------------------------------

test "redis gti - qualified type names written to Redis after graph build" {
    if not GTI_JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing fixture: {GTI_JAC_FILE}");
    }
    (redis_client, mongo_client, redis_c, mongo_c) = setup_containers();
    port = get_free_port();
    server = start_server(GTI_JAC_FILE, port);
    base_url = f"http://localhost:{port}";

    try {
        # Build a graph large enough to exceed the degree threshold (default 10)
        post_walker(base_url, "BuildGraph", {"n_post": 8, "n_other": 8});
        # Trigger a typed traversal so GTI index is populated (SAM miss → GTI → warm)
        post_walker(base_url, "QueryByBase", {});

        # Redis must have qualified-name keys for PostNode and BaseContent
        post_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.PostNode"
        );
        base_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.BaseContent"
        );
        assert len(post_keys) >= 1 , (
            f"Expected jac:topo:n:*:{MODULE_PREFIX}.PostNode keys, found none"
        );
        assert len(base_keys) >= 1 , (
            f"Expected jac:topo:n:*:{MODULE_PREFIX}.BaseContent keys, found none"
        );

        # Must NOT have bare (pre-migration) keys
        bare_post_keys = topo_keys(redis_client, f"{TOPO_PREFIX}:n:*:PostNode");
        assert len(bare_post_keys) == 0 , (
            f"Found bare 'PostNode' Redis keys — expected qualified names only: {bare_post_keys}"
        );
    } finally {
        teardown_containers(server, redis_c, mongo_c, mongo_client);
    }
}

test "redis gti - MRO fan-out writes BaseContent key for PostNode targets" {
    if not GTI_JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing fixture: {GTI_JAC_FILE}");
    }
    (redis_client, mongo_client, redis_c, mongo_c) = setup_containers();
    port = get_free_port();
    server = start_server(GTI_JAC_FILE, port);
    base_url = f"http://localhost:{port}";

    try {
        post_walker(base_url, "BuildGraph", {"n_post": 8, "n_other": 4});
        post_walker(base_url, "QueryByBase", {});

        # BaseContent key must contain exactly the PostNode target IDs (8)
        base_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.BaseContent"
        );
        assert len(base_keys) >= 1 , "Expected BaseContent topology key";
        base_member_count = redis_client.scard(base_keys[0]);
        assert base_member_count == 8 , (
            f"Expected 8 members in BaseContent key (one per PostNode), got {base_member_count}"
        );

        # OtherNode must NOT appear in BaseContent key
        other_ids_in_base = redis_client.smembers(base_keys[0]);
        post_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.PostNode"
        );
        post_members = redis_client.smembers(post_keys[0]) if post_keys else set();
        assert other_ids_in_base == post_members , (
            "BaseContent key must contain exactly the same IDs as PostNode key"
        );
    } finally {
        teardown_containers(server, redis_c, mongo_c, mongo_client);
    }
}

# ---------------------------------------------------------------------------
# Group 2 — Typed traversal correctness via GTI
# ---------------------------------------------------------------------------

test "redis gti - QueryByBase returns only PostNode results, not OtherNode" {
    if not GTI_JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing fixture: {GTI_JAC_FILE}");
    }
    (redis_client, mongo_client, redis_c, mongo_c) = setup_containers();
    port = get_free_port();
    server = start_server(GTI_JAC_FILE, port);
    base_url = f"http://localhost:{port}";

    try {
        post_walker(base_url, "BuildGraph", {"n_post": 8, "n_other": 8});
        result = post_walker(base_url, "QueryByBase", {});
        count = result.get("reports", [{}])[0].get("count", -1);
        assert count == 8 , (
            f"QueryByBase must return 8 PostNodes (not OtherNodes), got {count}"
        );
    } finally {
        teardown_containers(server, redis_c, mongo_c, mongo_client);
    }
}

# ---------------------------------------------------------------------------
# Group 3 — Edge deletion removes from Redis
# ---------------------------------------------------------------------------

test "redis gti - _gti_delete_edge_redis removes target from Redis key after del -->" {
    if not GTI_JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing fixture: {GTI_JAC_FILE}");
    }
    (redis_client, mongo_client, redis_c, mongo_c) = setup_containers();
    port = get_free_port();
    server = start_server(GTI_JAC_FILE, port);
    base_url = f"http://localhost:{port}";

    try {
        post_walker(base_url, "BuildGraph", {"n_post": 8, "n_other": 4});
        # Trigger GTI population
        post_walker(base_url, "QueryByBase", {});

        post_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.PostNode"
        );
        assert len(post_keys) >= 1 , "Expected PostNode Redis key";
        count_before = redis_client.scard(post_keys[0]);
        assert count_before == 8 , (
            f"Expected 8 PostNode members before deletion, got {count_before}"
        );

        # Delete one PostNode edge via the server
        del_result = post_walker(base_url, "DeleteFirstPost", {});
        assert del_result.get("reports", [{}])[0].get("deleted") == True , (
            "DeleteFirstPost must report deleted=True"
        );

        # After deletion the SREM must have removed the target from the key
        count_after = redis_client.scard(post_keys[0]);
        assert count_after == 7 , (
            f"Expected 7 PostNode members after deletion, got {count_after}"
        );
    } finally {
        teardown_containers(server, redis_c, mongo_c, mongo_client);
    }
}

# ---------------------------------------------------------------------------
# Group 4 — migrate_to_qualified_types Redis path
# ---------------------------------------------------------------------------

test "redis gti - migrate_to_qualified_types flushes bare keys and rebuilds qualified" {
    if not GTI_JAC_FILE.exists() {
        raise FileNotFoundError(f"Missing fixture: {GTI_JAC_FILE}");
    }
    (redis_client, mongo_client, redis_c, mongo_c) = setup_containers();
    port = get_free_port();
    server = start_server(GTI_JAC_FILE, port);
    base_url = f"http://localhost:{port}";

    try {
        post_walker(base_url, "BuildGraph", {"n_post": 8, "n_other": 4});
        post_walker(base_url, "QueryByBase", {});

        # Simulate pre-migration state: inject bare-name keys into Redis
        post_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.PostNode"
        );
        assert len(post_keys) >= 1;
        # Derive the source prefix from the existing qualified key
        # e.g.  jac:topo:n:{uuid}:gti_scale_app.PostNode  →  jac:topo:n:{uuid}
        src_prefix = post_keys[0].rsplit(":", 1)[0];
        bare_post_key = src_prefix + ":PostNode";
        bare_base_key = src_prefix + ":BaseContent";
        redis_client.sadd(bare_post_key, "fake-uuid-1");
        redis_client.sadd(bare_base_key, "fake-uuid-1");

        # Confirm bare keys exist before migration
        assert redis_client.exists(bare_post_key) , "bare PostNode key must exist before migration";

        # Call migration via the server walker
        mig_result = post_walker(base_url, "RunMigration", {});
        mig_report = mig_result.get("reports", [{}])[0];
        assert mig_report.get("backend") == "redis" , (
            f"Expected redis backend, got {mig_report}"
        );
        keys_flushed = int(mig_report.get("keys_flushed", 0));
        assert keys_flushed > 0 , "Expected at least one key flushed during migration";

        # Bare keys must be gone after migration
        assert not redis_client.exists(bare_post_key) , (
            "Bare 'PostNode' key must be deleted by migrate_to_qualified_types"
        );
        assert not redis_client.exists(bare_base_key) , (
            "Bare 'BaseContent' key must be deleted by migrate_to_qualified_types"
        );

        # Qualified keys must be recreated by rebuild_gti_redis
        rebuilt_post_keys = topo_keys(
            redis_client, f"{TOPO_PREFIX}:n:*:{MODULE_PREFIX}.PostNode"
        );
        assert len(rebuilt_post_keys) >= 1 , (
            "Qualified PostNode keys must be recreated after migration"
        );
        assert redis_client.scard(rebuilt_post_keys[0]) == 8 , (
            "Rebuilt PostNode key must have 8 members (one per PostNode)"
        );
    } finally {
        teardown_containers(server, redis_c, mongo_c, mongo_client);
    }
}
