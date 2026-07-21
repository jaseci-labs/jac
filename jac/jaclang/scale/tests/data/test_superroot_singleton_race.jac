"""Regression test for #7605: concurrent find-or-create on system_root must converge on one node."""

import contextlib;
import gc;
import json;
import os;
import time;
import from pathlib { Path }
import from concurrent.futures { ThreadPoolExecutor }

import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jaclang.scale.tests.server_support { get_free_port, start_server }

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "superroot_singleton_app.jac",
     CONCURRENCY = 40;


def _touch(base_url: str) -> tuple {
    try {
        res = requests.post(f"{base_url}/walker/touch_hub", json={}, timeout=30);
        return (res.status_code, res.text);
    } except Exception as e {
        return (-1, str(e));
    }
}


def _linked_hub_count(base_url: str) -> int {
    res = requests.post(f"{base_url}/walker/count_hubs", json={}, timeout=30);
    body = res.json();
    data = body.get("data", body) if isinstance(body, dict) else {};
    reports = data.get("reports", []) if isinstance(data, dict) else [];
    return reports[0]["hubs"] if reports else -1;
}


def _assert_converges(base_url: str, label: str) -> None {
    results: list = [];
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool {
        futures = [pool.submit(_touch, base_url) for i in range(CONCURRENCY)];
        for f in futures {
            results.append(f.result());
        }
    }

    failures = [];
    for (status, text) in results {
        parsed = None;
        with contextlib.suppress(Exception) {
            parsed = json.loads(text);
        }
        has_error = isinstance(parsed, dict) and parsed.get("error");
        if status != 200 or has_error {
            failures.append((status, text[:200]));
        }
    }
    assert not failures , (
        f"{label}: {len(failures)}/{CONCURRENCY} find-or-create requests failed "
        f"on the shared system_root (issue #7605 WriteConflict). "
        f"First failures: {failures[:4]}"
    );

    linked = _linked_hub_count(base_url);
    assert linked == 1 , (
        f"{label}: expected exactly 1 singleton linked to system_root after "
        f"{CONCURRENCY} concurrent find-or-create calls, found {linked}. "
        f"Duplicate singletons on the shared super root (issue #7605)."
    );
}


test "concurrent find-or-create on system_root converges to one node (Mongo + Redis)" {
    redis_container = RedisContainer("redis:latest", port=6379);
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    os.environ["REDIS_URL"] = f"redis://{redis_host}:{redis_port}/0";

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    mongo_client = MongoClient(mongo_uri);
    os.environ["MONGODB_URI"] = mongo_uri;

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        _assert_converges(base_url, "Mongo+Redis");
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        system_dbs = {"admin", "config", "local"};
        for db_name in mongo_client.list_database_names() {
            if db_name not in system_dbs {
                mongo_client.drop_database(db_name);
            }
        }
        mongo_client.close();
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.5);
        gc.collect();
    }
}


test "concurrent find-or-create on system_root converges to one node (SQLite)" {
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
        _assert_converges(base_url, "SQLite");
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
