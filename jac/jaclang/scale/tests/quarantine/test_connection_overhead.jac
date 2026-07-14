"""Proof test: two new TCP connections opened per request (availability probes).

ScaleTieredMemory.postinit calls RedisBackend.is_available() and
MongoBackend.is_available() on every request. Each creates a new client,
pings the server, and closes it — independent of the connection pool used
for actual data operations.

This test measures MongoDB's totalCreated connections before and after
N requests and proves the count increases by at least N (one probe connection
per request on top of the pool connections for actual work).

Expected on current main: FAILS (totalCreated grows by ~2N per N requests).
Expected after fix: PASSES (availability checked once at startup, not per request).
"""

import contextlib;
import gc;
import os;
import time;
import from pathlib { Path }

import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from jaclang.scale.tests.server_support {
    call_walker,
    get_free_port,
    register_user,
    start_server
}

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

def mongo_total_created(client: MongoClient) -> int {
    """Read totalCreated connections from MongoDB serverStatus.""";
    status = client.admin.command("serverStatus");
    return int(status["connections"]["totalCreated"]);
}

test "per-request availability probe creates extra MongoDB connections" {
    """MongoBackend.is_available() opens a brand-new MongoClient, pings, then
    closes it on every single request (memory_hierarchy.mongo.impl.jac:28-43).
    This is called from ScaleTieredMemory.postinit inside request_context_middleware.

    We measure totalCreated connections before and after N walker requests.
    If the probe runs per-request, totalCreated grows by at least N on top of
    whatever the actual work pool needs.

    The minimum expected delta for a properly pooled server (no probe) is 1
    (the pool creates connections lazily and reuses them). The actual delta
    on current main is ~2*N (one probe connect per request for MongoDB, plus
    one for Redis which is measured separately).
    """;
    REQUEST_COUNT = 10;
    # Each request fires one MongoBackend.is_available() probe = 1 extra connection.
    # We allow a small margin for pool keep-alive reconnects.
    MIN_EXTRA_CONNECTIONS_PER_REQUEST = 0.8;

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
        token = register_user(base_url, "probe_tester");

        # Warm-up: one request to let the server establish its pool.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        # Baseline: connections created so far.
        baseline = mongo_total_created(admin_client);

        # Fire REQUEST_COUNT requests.
        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.3);

        after = mongo_total_created(admin_client);
        delta = after - baseline;

        # If no per-request probe: delta ≈ 0 (pool is warm, reuses connections).
        # If per-request probe: delta ≈ REQUEST_COUNT (one new connect+close per request).
        expected_min = int(REQUEST_COUNT * MIN_EXTRA_CONNECTIONS_PER_REQUEST);

        assert delta >= expected_min , (
            f"AVAILABILITY PROBE: {REQUEST_COUNT} requests created {delta} new MongoDB "
            f"connections (expected >= {expected_min}). "
            f"MongoBackend.is_available() at memory_hierarchy.mongo.impl.jac:28-43 "
            f"instantiates a new MongoClient per call, which is invoked from "
            f"ScaleTieredMemory.postinit on every single request via "
            f"request_context_middleware. "
            f"Fix: run availability check once at startup, cache the boolean."
        );
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

test "system root fetched from MongoDB on every request (cold L1)" {
    """JScaleExecutionContext.init constructs ScaleTieredMemory with an empty
    __mem__ = {} on every request. The system root lookup (context.impl.jac:14)
    therefore always misses L1 and falls through to a MongoDB find_one.

    We measure MongoDB read opcounters before and after N read-only requests.
    A server where system root is cached at startup should issue 0 extra reads
    for subsequent requests to it. On current main, each request issues at least
    1 extra find_one (system root) on top of the application reads.
    """;
    REQUEST_COUNT = 10;

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
        token = register_user(base_url, "sysroot_tester");

        # Warm-up.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        def read_queries -> int {
            status = admin_client.admin.command("serverStatus");
            return int(status["opcounters"]["query"]);
        }

        baseline_queries = read_queries();

        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.3);

        total_queries = read_queries() - baseline_queries;

        # A read-only walker that lists items from root needs at minimum 1 query per
        # request (the item lookup). With system-root cold-load, we expect at least
        # 2 queries per request (system root + user root + items).
        # If system root were cached, we'd see fewer queries per request.
        queries_per_request = total_queries / REQUEST_COUNT;

        # Threshold: if >=2 queries per read-only request, system root is not cached.
        assert queries_per_request < 2.0 , (
            f"COLD SYSTEM ROOT: {REQUEST_COUNT} read-only requests issued "
            f"{total_queries} MongoDB queries total ({queries_per_request:.1f}/request). "
            f"A cached system root would reduce this to <2 queries per request. "
            f"JScaleExecutionContext.init at context.impl.jac:14 always calls "
            f"self.mem.get(UUID(Con.SUPER_ROOT_UUID)) on a freshly empty __mem__, "
            f"forcing a find_one for an immutable object on every request. "
            f"Fix: cache system root as a process-level singleton after first load."
        );
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
