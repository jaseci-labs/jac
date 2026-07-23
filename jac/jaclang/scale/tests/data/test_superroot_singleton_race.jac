"""Regression test for #7605: concurrent find-or-create on the system root.

Simultaneous unauthenticated requests race to find-or-create a singleton
node under the shared system root. Losing writers must replay against the
winner's committed state — every request succeeds and the graph converges
on exactly one singleton, instead of surfacing WriteConflict 409/500s or
accumulating duplicates.

Pattern mirrors test_persistence_race.jac: real backends via testcontainers,
real server via `jac start` subprocess, real HTTP requests, plus a
SQLite-fallback variant.
"""

import contextlib;
import gc;
import os;
import shutil;
import time;
import from pathlib { Path }
import from concurrent.futures { ThreadPoolExecutor, as_completed }

import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jaclang.scale.tests.server_support { get_free_port, start_server }

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "superroot_singleton_app.jac",
     HAMMER_REQUESTS = 40;


def _spawn_walker(base_url: str, walker_name: str) -> dict {
    res = requests.post(f"{base_url}/walker/{walker_name}", json={}, timeout=30);
    body: dict = {};
    with contextlib.suppress(Exception) {
        body = res.json();
    }
    data = body.get("data", body) if isinstance(body, dict) else {};
    reports = data.get("reports", []) if isinstance(data, dict) else [];
    first = reports[0] if reports else {};
    return {
        "status": res.status_code,
        "error": body.get("error") if isinstance(body, dict) else None,
        "count": first.get("count", -1) if isinstance(first, dict) else -1,
        "body": res.text[:200]
    };
}


def _hammer_and_assert(base_url: str, label: str) {
    outcomes: list = [];
    with ThreadPoolExecutor(max_workers=HAMMER_REQUESTS) as pool {
        futures = [
            pool.submit(_spawn_walker, base_url, "touch_hub")
            for _ in range(HAMMER_REQUESTS)
        ];
        for f in as_completed(futures) {
            outcomes.append(f.result());
        }
    }

    rejected = [
        o
        for o in outcomes
        if o["status"] != 200 or o["error"]
    ];
    assert not rejected , (
        f"{label}: {len(rejected)}/{HAMMER_REQUESTS} concurrent find-or-create "
        f"requests were rejected instead of replayed (#7605). "
        f"Samples: {[(o['status'], o['body']) for o in rejected[:3]]}"
    );

    # Convergence: the graph holds exactly one singleton, checked from a
    # fresh request context (not any hammer participant's view).
    seen = _spawn_walker(base_url, "count_hubs");
    assert seen["status"] == 200 and seen["count"] == 1 , (
        f"{label}: expected exactly 1 singleton under the system root, "
        f"observer saw count={seen['count']} (#7605 duplicate singletons)."
    );

    # Steady state: a late find-or-create finds the winner, creates nothing.
    late = _spawn_walker(base_url, "touch_hub");
    assert late["status"] == 200 and late["count"] == 1 , (
        f"{label}: post-race find-or-create disturbed the singleton "
        f"(count={late['count']})."
    );
}


def _stop(server: any) {
    if server {
        server.terminate();
        with contextlib.suppress(Exception) {
            server.wait(timeout=2);
        }
    }
}


test "concurrent find-or-create on system root converges (Mongo + Redis)" {
    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    os.environ["REDIS_URL"] = (
        f"redis://{redis_container.get_container_host_ip()}"
        f":{redis_container.get_exposed_port(6379)}/0"
    );

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    mongo_client = MongoClient(mongo_uri);
    os.environ["MONGODB_URI"] = mongo_uri;

    port = get_free_port();
    server = start_server(FIXTURES_DIR, JAC_FILE, port);
    try {
        _hammer_and_assert(f"http://localhost:{port}", "Mongo+Redis");
    } finally {
        _stop(server);
        for db_name in mongo_client.list_database_names() {
            if db_name not in {"admin", "config", "local"} {
                mongo_client.drop_database(db_name);
            }
        }
        mongo_client.close();
        mongo_container.stop();
        redis_container.stop();
        for k in ["MONGODB_URI", "REDIS_URL"] {
            os.environ.pop(k, None);
        }
        time.sleep(0.5);
        gc.collect();
    }
}


test "concurrent find-or-create on system root converges (SQLite)" {
    for k in ["MONGODB_URI", "REDIS_URL"] {
        os.environ.pop(k, None);
    }
    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        shutil.rmtree(data_dir);
    }

    port = get_free_port();
    server = start_server(FIXTURES_DIR, JAC_FILE, port);
    try {
        _hammer_and_assert(f"http://localhost:{port}", "SQLite");
    } finally {
        _stop(server);
        time.sleep(0.3);
        gc.collect();
        if data_dir.exists() {
            shutil.rmtree(data_dir);
        }
    }
}
