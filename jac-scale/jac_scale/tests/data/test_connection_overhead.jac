"""Efficiency guards: authenticated requests must not do redundant MongoDB work.

Two regression checks against a live MongoDB:
  1. The per-request availability probe reuses the pooled client (no new
     connection per request).
  2. The system root is served from the process cache (never re-fetched from
     MongoDB after warm-up).
"""

import contextlib;
import datetime;
import gc;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from typing { cast }

import requests;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from jaclang.jac0core.constant { Constants as Con }

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}

def extract(resp: any) -> any {
    if isinstance(resp, list) and len(resp) == 2 {
        resp = resp[1];
    }
    if isinstance(resp, dict) and "data" in resp {
        return resp["data"];
    }
    return resp;
}

def register_user(base_url: str, username: str) -> str {
    requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    res = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert res.status_code == 200;
    return cast(dict, extract(res.json()))["token"];
}

def call_walker(
    base_url: str, walker_name: str, token: str, payload: dict | None = None
) -> any {
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

"""Read totalCreated connections from MongoDB serverStatus."""
def mongo_total_created(client: MongoClient) -> int {
    status = client.admin.command("serverStatus");
    return int(status["connections"]["totalCreated"]);
}

"""Count profiled _anchors finds since `since`, optionally for one _id."""
def count_profiled_anchor_finds(
    client: MongoClient, since: any, id_filter: (str | None) = None
) -> int {
    query: dict = {"ts": {"$gte": since}, "ns": "jac_db._anchors", "op": "query"};
    if id_filter is not None {
        query["command.filter._id"] = id_filter;
    }
    return client["jac_db"]["system.profile"].count_documents(query);
}

"""N requests open ~0 new MongoDB connections (shared client, cached probe)."""
test "authenticated requests reuse the pooled MongoDB connection" {
    REQUEST_COUNT = 10;
    # One pooled top-up / keep-alive reconnect is tolerated; a per-request probe
    # would instead create one connection per request.
    MAX_NEW_CONNECTIONS = 1;

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

        # Warm-up: let the server establish its pool and cache the probe result.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        baseline = mongo_total_created(admin_client);

        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.3);

        delta = mongo_total_created(admin_client) - baseline;

        assert delta <= MAX_NEW_CONNECTIONS , (
            f"CONNECTION REUSE REGRESSION: {REQUEST_COUNT} requests opened {delta} "
            f"new MongoDB connections (expected <= {MAX_NEW_CONNECTIONS}). "
            f"MongoBackend shares one MongoClient via _process_cache and caches "
            f"is_available(), so no per-request connection should be created. "
            f"A growing count means a throwaway client or uncached probe was "
            f"reintroduced on the request hot path."
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

"""After warm-up the system root never hits MongoDB (served from L1 cache)."""
test "system root is served from process cache, never re-fetched from MongoDB" {
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
    profiling_on = False;

    try {
        token = register_user(base_url, "sysroot_tester");

        # Warm-up seeds _process_cache['system_root'] in the server process.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        admin_client["jac_db"].command("profile", 2);
        profiling_on = True;
        since = datetime.datetime.now(datetime.timezone.utc);

        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.4);

        total_anchor_finds = count_profiled_anchor_finds(admin_client, since);
        super_root_finds = count_profiled_anchor_finds(
            admin_client, since, Con.SUPER_ROOT_UUID
        );

        # Sanity: the profiler must be capturing finds (the user root is read
        # every request), else a 0 system-root count would be vacuously true.
        assert total_anchor_finds >= REQUEST_COUNT , (
            f"PROFILER INACTIVE: only {total_anchor_finds} _anchors finds captured "
            f"for {REQUEST_COUNT} requests; expected >= {REQUEST_COUNT}. "
            f"The system-root assertion below would be meaningless without a live "
            f"profiler."
        );

        assert super_root_finds == 0 , (
            f"SYSTEM ROOT RE-FETCH REGRESSION: {super_root_finds} MongoDB finds for "
            f"_id={Con.SUPER_ROOT_UUID} across {REQUEST_COUNT} post-warm-up requests "
            f"(expected 0). JScaleExecutionContext.init must seed "
            f"_process_cache['system_root'] into L1 so the lookup hits L1 instead "
            f"of issuing a find_one for an immutable object on every request."
        );
    } finally {
        with contextlib.suppress(Exception) {
            if profiling_on {
                admin_client["jac_db"].command("profile", 0);
            }
        }
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
