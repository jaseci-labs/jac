"""Shared harness for the scale test suites.

One home for the helpers every served-app test needs: a free TCP port, the
TransportResponse unwrap, a registered user's token, a `jac run --serve`
subprocess that is ready before the test proceeds, and the between-run
database scrub. Not a test module: the runner collects `test_*.jac` only.

    import from jaclang.scale.tests.support { get_free_port, start_server }
"""

import contextlib;
import gc;
import glob;
import os;
import shutil;
import socket;
import subprocess;
import time;
import unittest;
import requests;
import from pathlib { Path }
import from typing { cast }
import from jaclang.testing.test_runner { STRICT_ENV, strict_mode }

"""A port nothing is listening on."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""The jac binary `zig build` writes, resolved from this file's depth in tests/."""
def pod_binary -> Path {
    return Path(__file__).parents[3] / "zig-out" / "bin" / "jac";
}

"""The pod binary, or a named skip that JAC_TEST_STRICT turns into a failure.

Mirrors `jaclang.testing.requires`, which cannot express a build artifact:
this one is neither an importable module nor a tool on PATH.
"""
def require_pod_binary -> Path {
    binary = pod_binary();
    if not binary.is_file() {
        detail = f"missing build artifact '{binary}' (run `zig build` to produce it)";
        if strict_mode() {
            raise AssertionError(
                f"{detail}; {STRICT_ENV} is set, so this is a failure"
            );
        }
        raise unittest.SkipTest(detail);
    }
    return binary;
}

"""Delete SQLite, legacy shelf, and client-build leftovers under fixtures_dir."""
def cleanup_db_files(fixtures_dir: Path) {
    for pattern in [
        "*.db",
        "*.db-wal",
        "*.db-shm",
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir"
    ] {
        for db_file in `glob.`glob(pattern) {
            with contextlib.suppress(Exception) {
                Path(db_file).unlink();
            }
        }
    }

    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for db_file in `glob.`glob(str(fixtures_dir / pattern)) {
            with contextlib.suppress(Exception) {
                Path(db_file).unlink();
            }
        }
    }

    client_build_dir = fixtures_dir / ".jac";
    if client_build_dir.exists() {
        with contextlib.suppress(Exception) {
            shutil.rmtree(client_build_dir);
        }
    }
}

"""Unwrap a TransportResponse envelope down to its data payload.

Accepts the `[status, body]` pair some transports return as well as the bare
body, and returns the input unchanged when it carries no `data` key.
"""
def extract(resp: any) -> any {
    if isinstance(resp, list) and len(resp) == 2 {
        resp = resp[1];
    }
    if isinstance(resp, dict) and "data" in resp {
        return resp["data"];
    }
    return resp;
}

"""Register a username/password user, then log in and return the token.

Registration is idempotent: a repeat call for the same username is answered
with IDENTITY_TAKEN, which is ignored, and the login still yields a token.
"""
def register_user(base_url: str, username: str, password: str = "pass123") -> str {
    requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        },
        timeout=5
    );
    res = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        },
        timeout=5
    );
    assert res.status_code == 200 , f"login failed: {res.status_code} {res.text}";
    return cast(dict, extract(res.json()))["token"];
}

"""Start `jac run --serve` in fixtures_dir and block until /healthz answers 200.

`env` overlays the inherited environment, for fixtures that need a variable
set for the server process (a PYTHONPATH entry, say). A server that exits
before answering is reported immediately with its output rather than waited
out. The 300s budget covers a cold compile cache, where the first boot must
compile the app before it can serve /healthz.
"""
def start_server(
    fixtures_dir: Path, jac_file: Path, port: int, env: dict[str, str] | None = None
) -> subprocess.Popen {
    import from jaclang.scale.runtime.context.util { jac_executable }
    cmd = [jac_executable(), "run", "--serve", "--port", str(port), str(jac_file.name)];
    proc_env = os.environ.copy();
    if env {
        proc_env.update(env);
    }
    server = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir),
        env=proc_env
    );
    base_url = f"http://localhost:{port}";
    # A subprocess that has to compile the tree cold takes minutes, and a
    # health check that answers anything but 200 used to burn the whole budget
    # without pausing, so the wait is a wall clock that sleeps on every outcome
    # short of ready. A server that exits still ends the wait immediately.
    deadline = time.monotonic() + 300.0;
    while time.monotonic() < deadline {
        if server.poll() is not None {
            (stdout, stderr) = server.communicate();
            raise RuntimeError(
                f"server exited before serving {jac_file.name} on port {port}"
                f"\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
            );
        }
        try {
            r = requests.get(f"{base_url}/healthz", timeout=1);
            if r.status_code == 200 {
                return server;
            }
        } except Exception {}
        time.sleep(1);
    }
    server.kill();
    (stdout, stderr) = server.communicate(timeout=5);
    raise RuntimeError(
        f"server did not answer /healthz for {jac_file.name} on port {port} "
        f"within 300s\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}"
    );
}

"""Terminate a server started by start_server, escalating to kill if it lingers.

Tolerates None so a caller's `finally` needs no guard, and yields the port
before returning: a terminated child can hold the listening socket briefly.
"""
def stop_server(server: subprocess.Popen | None) {
    if server {
        server.terminate();
        try {
            server.`wait(timeout=5);
        } except subprocess.TimeoutExpired {
            server.kill();
            server.`wait();
        }
    }
    time.sleep(0.2);
    gc.collect();
}


import from jaclang.server.identity.user_manager { UserManager }
import from jaclang.server.server { EndpointHost }
import from jaclang.server.serving.endpoint { JEndPoint }


"""An endpoint host that only records what gets registered on it."""
obj RecordingHost(EndpointHost) {
    has _endpoints: list[JEndPoint] = [],
        users: (UserManager | None) = None,
        metrics: any = None,
        emailer: any = None,
        base_path: str = "";

    has user_manager: UserManager { getter; }

    def add_endpoint(ep: JEndPoint) {
        self._endpoints.append(ep);
    }

    def identity -> UserManager {
        if self.users is None {
            raise RuntimeError("RecordingHost has no user manager attached");
        }
        return self.users;
    }
}

impl RecordingHost.user_manager.getter -> UserManager {
    return self.identity();
}
