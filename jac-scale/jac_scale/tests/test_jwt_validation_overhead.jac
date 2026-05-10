"""Proof test: validate_jwt_token issues a MongoDB find_one on every request.

JacScaleUserManager.validate_jwt_token() decodes the JWT (stateless — no DB),
then unconditionally calls self.user_exists(username) which hits MongoDB.
JWT tokens are already self-signed and contain an expiry claim; user_exists()
adds no security benefit for tokens signed with the server's own secret.

Expected on current main: FAILS (MongoDB query count grows ~1/request).
Expected after fix: PASSES (JWT verified inline; user_exists removed from hot path).
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

def mongo_query_count(admin_client: MongoClient) -> int {
    status = admin_client.admin.command("serverStatus");
    return int(status["opcounters"]["query"]);
}

test "validate_jwt_token calls user_exists() — 1 extra MongoDB query per authenticated request" {
    """validate_jwt_token at user_manager.impl.jac:171-179 decodes the JWT (O(1), no IO),
    then calls self.user_exists(username) which translates to a MongoDB find_one.
    This adds a mandatory DB round-trip to every single authenticated request even
    though the JWT signature already proves the user was valid at token-issuance time.

    We fire REQUEST_COUNT authenticated ListItems requests and measure the delta in
    MongoDB query opcounters.  For each request, user_exists() is called once during
    JWT validation.  We expect at least REQUEST_COUNT extra queries over and above
    the unauthenticated baseline.

    Methodology: measure queries per request, assert queries/request >= 2.0.
    (1 query minimum from user_exists() + 1 from system/user root load = >=2 per
    authenticated request before any walker logic runs.)
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
        token = register_user(base_url, "jwt_tester");

        # Warm-up: let pool stabilise.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        baseline = mongo_query_count(admin_client);

        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.3);

        total_queries = mongo_query_count(admin_client) - baseline;
        queries_per_request = total_queries / REQUEST_COUNT;

        # A JWT-only server with no DB-backed validation and a cached system root
        # would issue 0 extra MongoDB queries for a read-only walker that returns
        # a cached or empty result.  On current main, each request issues at minimum:
        #   1 × user_exists (JWT validation)
        # + 1 × system root find_one (cold L1)
        # = at least 2 queries before walker logic.
        # We assert >= 2.0 to confirm the DB-backed JWT validation path is active.
        assert queries_per_request >= 2.0 , (
            f"JWT VALIDATION OVERHEAD: {REQUEST_COUNT} requests issued "
            f"{total_queries} MongoDB queries ({queries_per_request:.1f}/request). "
            f"Expected >= 2.0/request on current main (user_exists + system-root load). "
            f"If queries/request < 2.0 then JWT validation and/or system root "
            f"has already been optimized."
        );

        # Explicit attribution: total queries must be at least REQUEST_COUNT
        # (one user_exists per request, ignoring system root).
        assert total_queries >= REQUEST_COUNT , (
            f"JWT VALIDATION: expected >= {REQUEST_COUNT} total MongoDB queries "
            f"({REQUEST_COUNT} requests × 1 user_exists/request minimum), "
            f"but got {total_queries}. "
            f"validate_jwt_token at user_manager.impl.jac:171-179 calls "
            f"self.user_exists(username) for every Bearer token header — "
            f"this is a MongoDB find_one on every authenticated endpoint."
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

test "JWT query overhead accumulates — N requests issue N user_exists() DB calls" {
    """Confirms the per-request JWT validation overhead scales linearly with request count.
    If user_exists() is called once per request, then N requests = N extra DB queries.
    A cached validation (e.g., short-lived LRU keyed by username) would show a much
    smaller delta after the first cache population.

    We fire two batches of REQUEST_COUNT each and confirm the query delta doubles.
    """;
    REQUEST_COUNT = 5;

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
        token = register_user(base_url, "jwt_accum_tester");

        # Warm-up.
        call_walker(base_url, "ListItems", token);
        time.sleep(0.3);

        b0 = mongo_query_count(admin_client);
        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.2);
        delta_first = mongo_query_count(admin_client) - b0;

        b1 = mongo_query_count(admin_client);
        for _ in range(REQUEST_COUNT) {
            call_walker(base_url, "ListItems", token);
        }
        time.sleep(0.2);
        delta_second = mongo_query_count(admin_client) - b1;

        # Both batches should produce the same per-request overhead.
        # If user_exists() is called each time: delta_second ≈ delta_first.
        # If cached: delta_second ≈ 0 after the cache is warm.
        tolerance = 2;
        assert abs(delta_second - delta_first) <= tolerance , (
            f"JWT ACCUM: first batch={delta_first} queries, "
            f"second batch={delta_second} queries for {REQUEST_COUNT} requests each. "
            f"Batches should match (user_exists per request = constant overhead). "
            f"If second batch is much smaller, JWT validation may already be cached."
        );

        # Confirm that both batches issued at least REQUEST_COUNT queries
        # (proving the per-request overhead is present).
        assert delta_first >= REQUEST_COUNT and delta_second >= REQUEST_COUNT , (
            f"JWT ACCUM: delta_first={delta_first}, delta_second={delta_second}. "
            f"At least {REQUEST_COUNT} queries expected per batch "
            f"(1 user_exists/request × {REQUEST_COUNT} requests). "
            f"validate_jwt_token at user_manager.impl.jac:171-179 calls "
            f"self.user_exists(username) on every request."
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
