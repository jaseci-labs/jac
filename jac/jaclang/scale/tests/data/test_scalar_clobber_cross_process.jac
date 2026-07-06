"""Cross-process regression tests for scalar-clobber bugs in _put_node_atomic.

Two `jac start` processes share Mongo + Redis, simulating two pods with
independent L1 caches and no cross-pod cache invalidation.

Test 1 — issue #5997 (_put_node_atomic atomic path):
  Pod1 writes a=42. Pod2 (stale L1: a=0) writes b=99 AND adds an edge.
  The edge delta triggers _put_node_atomic. The fix (dot-notation dirty-only
  writes) must leave a=42 intact.

Test 2 — issue #6022 (dispatch guard):
  Pod1 writes a=42. Pod2 (stale L1: a=0) writes b=99 with NO edge change.
  The dispatch guard must route this to put_partial (not _put_node_atomic).
  put_partial writes only data.archetype.b — a=42 must survive.
  Before the fix, edge_delta() returned an empty tuple (not None) for every
  DB-loaded node, so _put_node_atomic was always reached and the stale
  archetype snapshot clobbered a.
"""

import contextlib;
import gc;
import os;
import socket;
import subprocess;
import sys;
import time;
import from pathlib { Path }
import from typing { cast }

import requests;
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jaclang.scale.tests.server_support { get_free_port }

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "clobber_app.jac";

def extract(json_response: any) -> any {
    if isinstance(json_response, list) and len(json_response) == 2 {
        json_response = json_response[1];
    }
    if isinstance(json_response, dict) and "data" in json_response {
        return json_response["data"];
    }
    return json_response;
}

def register_and_login(base_url: str, username: str) -> str {
    res = requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert res.status_code == 201 , f"register failed: {res.status_code} {res.text}";
    login_res = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert login_res.status_code == 200 , f"login failed: {login_res.status_code}";
    return cast(dict, extract(login_res.json()))["token"];
}

def login(base_url: str, username: str) -> str {
    login_res = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": "pass123"}
        },
        timeout=5
    );
    assert login_res.status_code == 200 , f"login failed on pod2: {login_res.status_code}";
    return cast(dict, extract(login_res.json()))["token"];
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

def start_pod(
    fixtures_dir: Path, jac_file: Path, port: int, env_extra: dict
) -> subprocess.Popen {
    import shutil;
    jac_executable = shutil.which("jac") or str(Path(sys.executable).parent / "jac");
    cmd = [str(jac_executable), "start", str(jac_file.name), "--port", str(port)];
    env = os.environ.copy();
    env.update(env_extra);
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
    raise RuntimeError(f"pod failed to start\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}");
}

def stop_pods(pods: list) {
    for pod in pods {
        pod.terminate();
        with contextlib.suppress(Exception) {
            pod.wait(timeout=5);
        }
    }
}

"""Poll ReadCounter until both fields match expected values or timeout elapses.

Returns the last observed counter dict — callers assert on the result so
the failure message always shows the actual vs expected values.
"""
def poll_counter(
    base_url: str, token: str, expected_a: int, expected_b: int, timeout: float = 5.0
) -> dict[str, any] {
    deadline = time.time() + timeout;
    result: dict[str, any] = {};
    while time.time() < deadline {
        raw: any = extract(call_walker(base_url, "ReadCounter", token));
        result = cast(dict[str, any], cast(list, raw["reports"])[0]);
        if result.get("a") == expected_a and result.get("b") == expected_b {
            return result;
        }
        time.sleep(0.1);
    }
    return result;
}


test "_put_node_atomic: dirty-only writes do not clobber concurrent scalar changes from other pods (issue #5997)" {
    # Sequence:
    #   t=0  Pod1: Init Counter {a:0, b:0}
    #   t=1  Pod2: ReadCounter → warms pod2 L1 with {a:0, b:0}
    #   t=2  Pod1: SetA(42) → Mongo: {a:42, b:0}. Pod2's L1 is NOT updated.
    #   t=3  Pod2: SetBAndAddEdge(99) → dirty={b}, adds edge → _put_node_atomic
    #              Fix: writes only data.archetype.b; leaves data.archetype.a alone.
    #   t=4  Assert: a=42, b=99 both present in Mongo.
    mongo_c = MongoDbContainer("mongo:latest");
    redis_c = RedisContainer("redis:latest", port=6379);
    mongo_c.start();
    redis_c.start();

    mongo_uri = mongo_c.get_connection_url();
    redis_host = redis_c.get_container_host_ip();
    redis_port = redis_c.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";

    env_shared: dict = {"MONGODB_URI": mongo_uri, "REDIS_URL": redis_url};

    port1 = get_free_port();
    port2 = get_free_port();
    url1 = f"http://localhost:{port1}";
    url2 = f"http://localhost:{port2}";

    pod1 = start_pod(FIXTURES_DIR, JAC_FILE, port1, env_shared);
    pod2 = start_pod(FIXTURES_DIR, JAC_FILE, port2, env_shared);

    try {
        username = f"user_atomic_{int(time.time())}";
        token1 = register_and_login(url1, username);
        token2 = login(url2, username);

        # t=0: Init Counter on pod1.
        call_walker(url1, "Init", token1);

        # t=1: Warm pod2's L1 — it now has Counter{a:0, b:0}.
        call_walker(url2, "ReadCounter", token2);

        # t=2: Pod1 commits a=42. Pod2's L1 is stale (a=0).
        call_walker(url1, "SetA", token1, {"value": 42});

        # t=3: Pod2 commits b=99 AND adds an edge (triggers _put_node_atomic).
        #       Dirty set computed from pod2's L1: only {b}. a is NOT dirty.
        call_walker(
            url2, "SetBAndAddEdge", token2, {"value": 99, "item_name": "probe"}
        );

        # t=4: Poll pod1 until both writes are visible (up to 5 s) or return last seen state.
        final = poll_counter(url1, token1, expected_a=42, expected_b=99);

        assert final["a"] == 42 , (
            f"_put_node_atomic clobbered pod1's write: a={final['a']} (expected 42). "
            "dot-notation dirty-only write is not applied correctly. "
            "Regression: issue #5997."
        );
        assert final["b"] == 99 , (
            f"pod2's write was lost: b={final['b']} (expected 99)"
        );
    } finally {
        stop_pods([pod1, pod2]);
        mongo_c.stop();
        redis_c.stop();
        gc.collect();
    }
}


test "sync dispatch: scalar-only commit routes to put_partial, not _put_node_atomic" {
    # Sequence:
    #   t=0  Pod1: Init Counter {a:0, b:0}
    #   t=1  Pod2: ReadCounter → warms pod2 L1 with {a:0, b:0}
    #   t=2  Pod1: SetA(42) → Mongo: {a:42, b:0}. Pod2's L1 is NOT updated.
    #   t=3  Pod2: SetB(99) → dirty={b}, NO edge changes → must route to put_partial.
    #              put_partial writes only data.archetype.b; leaves data.archetype.a alone.
    #              Before the fix: edge_delta() returned (set(), set()) for DB-loaded nodes.
    #              delta is not None → _put_node_atomic was always reached regardless,
    #              and the stale snapshot clobbered a back to 0.
    #   t=4  Assert: a=42, b=99 both present in Mongo.
    mongo_c = MongoDbContainer("mongo:latest");
    redis_c = RedisContainer("redis:latest", port=6379);
    mongo_c.start();
    redis_c.start();

    mongo_uri = mongo_c.get_connection_url();
    redis_host = redis_c.get_container_host_ip();
    redis_port = redis_c.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";

    env_shared: dict = {"MONGODB_URI": mongo_uri, "REDIS_URL": redis_url};

    port1 = get_free_port();
    port2 = get_free_port();
    url1 = f"http://localhost:{port1}";
    url2 = f"http://localhost:{port2}";

    pod1 = start_pod(FIXTURES_DIR, JAC_FILE, port1, env_shared);
    pod2 = start_pod(FIXTURES_DIR, JAC_FILE, port2, env_shared);

    try {
        username = f"user_dispatch_{int(time.time())}";
        token1 = register_and_login(url1, username);
        token2 = login(url2, username);

        # t=0: Init Counter on pod1.
        call_walker(url1, "Init", token1);

        # t=1: Warm pod2's L1 — it now has Counter{a:0, b:0}.
        call_walker(url2, "ReadCounter", token2);

        # t=2: Pod1 commits a=42. Pod2's L1 is stale (a=0).
        call_walker(url1, "SetA", token1, {"value": 42});

        # t=3: Pod2 commits b=99, no edge changes.
        #       With the dispatch guard fix: goes to put_partial → writes only b.
        #       Without fix: _put_node_atomic called with stale snapshot → a reset to 0.
        call_walker(url2, "SetB", token2, {"value": 99});

        # t=4: Poll pod1 until both writes are visible (up to 5 s) or return last seen state.
        final = poll_counter(url1, token1, expected_a=42, expected_b=99);

        assert final["a"] == 42 , (
            f"Dispatch guard is broken: scalar-only commit on pod2 clobbered pod1's write. "
            f"a={final['a']} (expected 42). "
            "_put_node_atomic was called instead of put_partial, overwriting the archetype "
            "with pod2's stale snapshot. Regression: issue #6022."
        );
        assert final["b"] == 99 , (
            f"pod2's write was lost: b={final['b']} (expected 99)"
        );
    } finally {
        stop_pods([pod1, pod2]);
        mongo_c.stop();
        redis_c.stop();
        gc.collect();
    }
}
