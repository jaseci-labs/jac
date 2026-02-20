"""Test for restspec decorator functionality."""

import contextlib;
import gc;
import glob;
import socket;
import subprocess;
import time;
import requests;
import shutil;
import sys;
import from pathlib { Path }
import from typing { Any }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Extract data from response envelope."""
def _extract_data(response: dict[str, Any] | list[Any]) -> Any {
    if isinstance(response, list) and len(response) == 2 {
        response = response[1];
    }
    if isinstance(response, dict) and "data" in response {
        return response["data"];
    }
    return response;
}

"""Cleanup database files."""
def _cleanup_db_files(fixtures_dir: Path) -> None {
    for pattern in ["*.db", "*.db-wal", "*.db-shm", "anchor_store*"] {
        for f in glob.glob(pattern) {
            with contextlib.suppress(Exception) {
                Path(f).unlink();
            }
        }
    }
    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for f in glob.glob(str(fixtures_dir / pattern)) {
            with contextlib.suppress(Exception) {
                Path(f).unlink();
            }
        }
    }
    client_dir = fixtures_dir / ".jac";
    if client_dir.exists() {
        with contextlib.suppress(Exception) {
            shutil.rmtree(client_dir);
        }
    }
}

"""Start the jac-scale server in a subprocess."""
def _start_server(
    fixtures_dir: Path, test_file: Path, port: int, base_url: str
) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [str(jac_executable), "start", test_file.name, "--port", str(port)];

    server_process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir)
    );

    max_attempts = 50;
    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(f"Server died: {stdout}\n{stderr}") ;
        }
        try {
            requests.get(f"{base_url}/docs", timeout=1);
            return server_process;
        } except requests.RequestException {
            time.sleep(0.5);
        }
    }
    server_process.kill();
    raise RuntimeError("Server failed to start") ;
}

"""Stop the server process."""
def _stop_server(server_process: subprocess.Popen | None) -> None {
    if server_process {
        server_process.terminate();
        try {
            server_process.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            server_process.wait();
        }
    }
    time.sleep(0.5);
    gc.collect();
}

# Setup shared state
glob fixtures_dir: Path = Path(__file__).parent / "fixtures",
     test_file: Path = fixtures_dir / "test_restspec.jac",
     port: int = get_free_port(),
     base_url: str = f"http://localhost:{port}",
     server_process: subprocess.Popen | None = None;

"""Setup and start the restspec server."""
def setup_restspec_server -> subprocess.Popen {
    if not test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {test_file}") ;
    }
    _cleanup_db_files(fixtures_dir);
    return _start_server(fixtures_dir, test_file, port, base_url);
}

"""Teardown the restspec server."""
def teardown_restspec_server(server_proc: subprocess.Popen | None) -> None {
    _stop_server(server_proc);
    _cleanup_db_files(fixtures_dir);
}

test "custom method walker" {
    sp = setup_restspec_server();
    try {
        response = requests.get(f"{base_url}/walker/GetWalker", timeout=5);
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["reports"][0]["message"] == "GetWalker executed";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "custom path walker" {
    sp = setup_restspec_server();
    try {
        response = requests.get(f"{base_url}/custom/walker", timeout=5);
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["reports"][0]["message"] == "CustomPathWalker executed";
        assert data["reports"][0]["path"] == "/custom/walker";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "post method walker" {
    sp = setup_restspec_server();
    try {
        response = requests.post(f"{base_url}/walker/PostWalker", timeout=5);
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["reports"][0]["message"] == "PostWalker executed";
        assert data["reports"][0]["method"] == "POST";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "default method walker" {
    sp = setup_restspec_server();
    try {
        response = requests.post(f"{base_url}/walker/DefaultWalker", timeout=5);
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["reports"][0]["message"] == "DefaultWalker executed";
        assert data["reports"][0]["method"] == "DEFAULT";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "custom method func" {
    sp = setup_restspec_server();
    try {
        requests.post(
            f"{base_url}/user/register", json={"username": "u1", "password": "p1"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u1", "password": "p1"}
        );
        token = _extract_data(login.json())["token"];

        response = requests.get(
            f"{base_url}/function/get_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["result"]["message"] == "get_func executed";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "custom path func" {
    sp = setup_restspec_server();
    try {
        requests.post(
            f"{base_url}/user/register", json={"username": "u1", "password": "p1"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u1", "password": "p1"}
        );
        token = _extract_data(login.json())["token"];

        response = requests.get(
            f"{base_url}/custom/func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["result"]["message"] == "custom_path_func executed";
        assert data["result"]["path"] == "/custom/func";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "post method func" {
    sp = setup_restspec_server();
    try {
        requests.post(
            f"{base_url}/user/register", json={"username": "u1", "password": "p1"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u1", "password": "p1"}
        );
        token = _extract_data(login.json())["token"];

        response = requests.post(
            f"{base_url}/function/post_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["result"]["message"] == "post_func executed";
        assert data["result"]["method"] == "POST";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "default method func" {
    sp = setup_restspec_server();
    try {
        requests.post(
            f"{base_url}/user/register", json={"username": "u1", "password": "p1"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u1", "password": "p1"}
        );
        token = _extract_data(login.json())["token"];

        response = requests.post(
            f"{base_url}/function/default_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["result"]["message"] == "default_func executed";
        assert data["result"]["method"] == "DEFAULT";
    } finally {
        teardown_restspec_server(sp);
    }
}

test "get walker with params" {
    sp = setup_restspec_server();
    try {
        params: dict[str, str | int] = {"name": "Alice", "age": 30};
        response = requests.get(
            f"{base_url}/walker/GetWalkerWithParams", params=params, timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["reports"][0]["message"] == "GetWalkerWithParams executed";
        assert data["reports"][0]["name"] == "Alice";
        assert data["reports"][0]["age"] == 30;
    } finally {
        teardown_restspec_server(sp);
    }
}

test "get func with params" {
    sp = setup_restspec_server();
    try {
        requests.post(
            f"{base_url}/user/register", json={"username": "u1", "password": "p1"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u1", "password": "p1"}
        );
        token = _extract_data(login.json())["token"];

        params: dict[str, str | int] = {"name": "Bob", "age": 40};
        response = requests.get(
            f"{base_url}/function/get_func_with_params",
            headers={"Authorization": f"Bearer {token}"},
            params=params,
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_data(response.json());
        assert data["result"]["message"] == "get_func_with_params executed";
        assert data["result"]["name"] == "Bob";
        assert data["result"]["age"] == 40;
    } finally {
        teardown_restspec_server(sp);
    }
}

test "openapi specs" {
    sp = setup_restspec_server();
    try {
        spec = requests.get(f"{base_url}/openapi.json").json();
        paths = spec["paths"];

        assert "/custom/walker" in paths;
        assert "get" in paths["/custom/walker"];

        assert "/custom/func" in paths;
        assert "get" in paths["/custom/func"];

        assert "/walker/GetWalker" in paths;
        assert "get" in paths["/walker/GetWalker"];
        assert "post" not in paths["/walker/GetWalker"];

        assert "/walker/PostWalker" in paths;
        assert "post" in paths["/walker/PostWalker"];
        assert "get" not in paths["/walker/PostWalker"];

        assert "/walker/DefaultWalker" in paths;
        assert "post" in paths["/walker/DefaultWalker"];
        assert "get" not in paths["/walker/DefaultWalker"];
    } finally {
        teardown_restspec_server(sp);
    }
}

# ============================================================================
# Path Parameter Tests (regression for @restspec path param bug)
# Single server instance for all path-param assertions — no per-case restart.
# ============================================================================
test "restspec path parameters" {
    sp = setup_restspec_server();
    try {
        # Obtain an auth token (functions require auth, walkers are public)
        requests.post(
            f"{base_url}/user/register", json={"username": "u_pp", "password": "p_pp"}
        );
        login = requests.post(
            f"{base_url}/user/login", json={"username": "u_pp", "password": "p_pp"}
        );
        auth = {"Authorization": f"Bearer {_extract_data(login.json())['token']}"};

        # --- OpenAPI schema: routes registered with correct path templates ---
        spec = requests.get(f"{base_url}/openapi.json", timeout=5).json();
        paths = spec["paths"];
        assert "/items/{item_id}" in paths and "get" in paths["/items/{item_id}"];
        assert "/users/{user_id}/orders" in paths
        and "get" in paths["/users/{user_id}/orders"];
        assert "/orgs/{org_id}/repos/{repo_id}" in paths
        and "get" in paths["/orgs/{org_id}/repos/{repo_id}"];
        assert "/resources/{resource_id}/update" in paths
        and "post" in paths["/resources/{resource_id}/update"];
        assert "/nodes/{node_id}" in paths and "get" in paths["/nodes/{node_id}"];
        assert "/projects/{project_id}/tasks/{task_id}" in paths
        and "get" in paths["/projects/{project_id}/tasks/{task_id}"];

        # OpenAPI marks the path param as in=path, required=true
        item_params = paths["/items/{item_id}"]["get"]["parameters"];
        pp = next(
            p
            for p in item_params
            if p["name"] == "item_id"
        );
        assert pp["in"] == "path" and pp["required"] == True;

        # --- Function: single path param ---
        r = requests.get(f"{base_url}/items/abc123", headers=auth, timeout=5);
        assert r.status_code == 200;
        d = _extract_data(r.json())["result"];
        assert d["item_id"] == "abc123" and d["message"] == "get_item executed";

        # --- Function: path param + explicit query param ---
        r = requests.get(
            f"{base_url}/users/u42/orders",
            headers=auth,
            params={"status": "pending"},
            timeout=5
        );
        assert r.status_code == 200;
        d = _extract_data(r.json())["result"];
        assert d["user_id"] == "u42" and d["status"] == "pending";

        # --- Function: path param + default query param ---
        r = requests.get(f"{base_url}/users/u99/orders", headers=auth, timeout=5);
        assert r.status_code == 200;
        d = _extract_data(r.json())["result"];
        assert d["user_id"] == "u99" and d["status"] == "all";

        # --- Function: multiple path params ---
        r = requests.get(
            f"{base_url}/orgs/myorg/repos/myrepo", headers=auth, timeout=5
        );
        assert r.status_code == 200;
        d = _extract_data(r.json())["result"];
        assert d["org_id"] == "myorg" and d["repo_id"] == "myrepo";

        # --- Function: POST with path param + JSON body ---
        r = requests.post(
            f"{base_url}/resources/res-001/update",
            headers=auth,
            json={"name": "widget", "value": 42},
            timeout=5
        );
        assert r.status_code == 200;
        d = _extract_data(r.json())["result"];
        assert d["resource_id"] == "res-001"
        and d["name"] == "widget"
        and d["value"] == 42;

        # --- Walker: single path param (walkers are public, no auth needed) ---
        r = requests.get(f"{base_url}/nodes/node-xyz", timeout=5);
        assert r.status_code == 200;
        d = _extract_data(r.json())["reports"][0];
        assert d["node_id"] == "node-xyz" and d["message"] == "GetNodeWalker executed";

        # --- Walker: multiple path params ---
        r = requests.get(f"{base_url}/projects/proj-1/tasks/task-2", timeout=5);
        assert r.status_code == 200;
        d = _extract_data(r.json())["reports"][0];
        assert d["project_id"] == "proj-1" and d["task_id"] == "task-2";
        assert d["message"] == "GetProjectTaskWalker executed";
    } finally {
        teardown_restspec_server(sp);
    }
}
