"""Proof test: concurrent walkers silently lose node/edge writes.

This test exercises the read-modify-write race in Anchor persistence
documented in issues #4616, #5446, #5451, #5475.

Pattern mirrors test_memory_hierarchy.jac exactly: real Mongo + Redis via
testcontainers, real server via `jac start` subprocess, real HTTP requests.

Expected outcome on current main: FAILS.
Expected outcome after CAS/versioning fix: PASSES.
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
import from concurrent.futures { ThreadPoolExecutor, as_completed }

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

def extract(json_response: Any) -> Any {
    if isinstance(json_response, list) and len(json_response) == 2 {
        json_response = json_response[1];
    }
    if isinstance(json_response, dict) and "data" in json_response {
        return json_response["data"];
    }
    return json_response;
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
    return cast(dict, extract(login.json()))["token"];
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
    raise RuntimeError(f"server failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}");
}

test "concurrent writes to same root must not lose edges (race condition proof)" {
    # 5 rounds, each: 1 AddItem + 20 concurrent Touch walkers on the same root.
    # On current main this reliably loses items because Touch walkers' sync()
    # uses stale root edge-lists and overwrites AddItem's newly-appended edge.
    ROUNDS = 5;
    CONCURRENT_TOUCHES = 20;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

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
        token = register_user(base_url, "race_tester");

        # Warm up root — ensure it's persisted before the storm.
        call_walker(base_url, "ListItems", token);

        expected = 0;
        for round_n in range(ROUNDS) {
            item_name = f"item_{round_n}";
            with ThreadPoolExecutor(max_workers=CONCURRENT_TOUCHES + 1) as pool {
                futures = [
                    pool.submit(
                        call_walker, base_url, "AddItem", token, {"name": item_name}
                    )
                ];
                for _ in range(CONCURRENT_TOUCHES) {
                    futures.append(pool.submit(call_walker, base_url, "Touch", token));
                }
                for f in as_completed(futures) {
                    _ = f.result();
                }
            }
            expected += 1;
            time.sleep(0.2);
        }

        final = cast(dict, extract(call_walker(base_url, "ListItems", token)));
        reports = final.get("reports", []);
        actual_count = reports[0]["count"] if reports else -1;

        assert actual_count == expected , (
            f"DATA LOSS: created {expected} items across {ROUNDS} rounds of "
            f"1 AddItem + {CONCURRENT_TOUCHES} concurrent Touch walkers, "
            f"but only {actual_count} survived in the graph. "
            f"Missing items are evidence of read-modify-write race on root edges. "
            f"See issues #4616, #5446, #5451, #5475."
        );
    } finally {
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        system_dbs = {"admin","config","local"};
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
        if data_dir.exists() {
            import shutil;
            shutil.rmtree(data_dir);
        }
    }
}

test "sqlite backend: concurrent writes to same root must not lose edges" {
    # Same race, but against the default SQLite backend — no testcontainers.
    # Proves the bug exists in jaclang core, not just jac-scale's Mongo layer.
    ROUNDS = 5;
    CONCURRENT_TOUCHES = 20;

    data_dir = FIXTURES_DIR / ".jac" / "data";
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }

    for k in ["MONGODB_URI", "REDIS_URL"] {
        os.environ.pop(k, None);
    }

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "race_tester_sqlite");
        call_walker(base_url, "ListItems", token);

        expected = 0;
        for round_n in range(ROUNDS) {
            with ThreadPoolExecutor(max_workers=CONCURRENT_TOUCHES + 1) as pool {
                futures = [
                    pool.submit(
                        call_walker,
                        base_url,
                        "AddItem",
                        token,
                        {"name": f"sqlite_{round_n}"}
                    )
                ];
                for _ in range(CONCURRENT_TOUCHES) {
                    futures.append(pool.submit(call_walker, base_url, "Touch", token));
                }
                for f in as_completed(futures) {
                    _ = f.result();
                }
            }
            expected += 1;
            time.sleep(0.2);
        }

        final = cast(dict, extract(call_walker(base_url, "ListItems", token)));
        reports = final.get("reports", []);
        actual_count = reports[0]["count"] if reports else -1;

        assert actual_count == expected , (
            f"SQLite DATA LOSS: created {expected}, visible {actual_count}. "
            f"SqliteMemory.put() and .sync() both do unconditional INSERT OR REPLACE."
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
