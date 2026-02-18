"""Test for jac-scale serve command and REST API server."""

import asyncio;
import contextlib;
import gc;
import glob;
import json;
import socket;
import subprocess;
import sys;
import time;
import uuid;
import shutil;
import requests;
import pytest;
import jwt as pyjwt;
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }
import from typing { Any, cast }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Extract data from TransportResponse envelope format."""
def _extract_transport_response_data(
    json_response: dict[str, Any] | list[Any]
) -> dict[str, Any] | list[Any] {
    if isinstance(json_response, list) and len(json_response) == 2 {
        body: dict[str, Any] = json_response[1];
        json_response = body;
    }

    if (
        isinstance(json_response, dict)
        and "ok" in json_response
        and "data" in json_response
    ) {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            result: dict[str, Any] = {
                "error": error_info.get("message", "Unknown error")
            };
            if "code" in error_info {
                result["error_code"] = error_info["code"];
            }
            if "details" in error_info {
                result["error_details"] = error_info["details"];
            }
            return result;
        }
    }

    return json_response;
}

"""Delete SQLite database files and legacy shelf files."""
def _cleanup_db_files(fixtures_dir: Path) -> None {
    for pattern in [
        "*.db",
        "*.db-wal",
        "*.db-shm",
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir"
    ] {
        for db_file in glob.glob(pattern) {
            with contextlib.suppress(Exception) {
                Path(db_file).unlink();
            }
        }
    }

    for pattern in ["*.db", "*.db-wal", "*.db-shm"] {
        for db_file in glob.glob(str(fixtures_dir / pattern)) {
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

"""Start the jac-scale server in a subprocess."""
def _start_server(
    fixtures_dir: Path,
    test_file: Path,
    port: int,
    base_url: str,
    extra_args: list[str] | None = None
) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";

    cmd = [
        str(jac_executable),
        "start",
        test_file.name if not extra_args else str(test_file),
        "--port",
        str(port)
    ];
    if extra_args {
        cmd.extend(extra_args);
    }

    server_process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir) if not extra_args else None
    );

    max_attempts = 50;
    server_ready = False;

    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(
                f"Server process terminated unexpectedly.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            ) ;
        }

        try {
            response = requests.get(f"{base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                print(f"Server started successfully on port {port}");
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(2);
        }
    }

    if not (server_ready) {
        server_process.terminate();
        try {
            (stdout, stderr) = server_process.communicate(timeout=2);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            (stdout, stderr) = server_process.communicate();
        }
        raise RuntimeError(
            f"Server failed to start after {max_attempts} attempts.\n"
            f"STDOUT: {stdout}\nSTDERR: {stderr}"
        ) ;
    }

    return server_process;
}

"""Stop server process."""
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

"""Make HTTP request to server and return JSON response."""
def _request(
    base_url: str,
    method: str,
    path: str,
    data: dict[str, Any] | None = None,
    token: str | None = None,
    timeout: int = 5,
    max_retries: int = 60,
    retry_interval: float = 2.0
) -> dict[str, Any] {
    url = f"{base_url}{path}";
    headers = {"Content-Type": "application/json"};

    if token {
        headers["Authorization"] = f"Bearer {token}";
    }

    response = None;
    for attempt in range(max_retries) {
        response = requests.request(
            method=method, url=url, json=data, headers=headers, timeout=timeout
        );

        if response.status_code == 503 {
            print(
                f"[DEBUG] {path} returned 503, retrying ({attempt + 1}/{max_retries})..."
            );
            time.sleep(retry_interval);
            continue;
        }

        break;
    }

    assert response is not None , "No response received";
    json_response: Any = response.json();
    return _extract_transport_response_data(json_response);
}

"""Create an expired JWT token for testing."""
def _create_expired_token(username: str, days_ago: int = 1) -> str {
    secret = "supersecretkey_for_testing_only!";
    algorithm = "HS256";

    past_time = datetime.now(UTC) - timedelta(days=days_ago);
    payload = {
        "username": username,
        "exp": past_time + timedelta(hours=1),
        "iat": past_time
    };
    return pyjwt.encode(payload, secret, algorithm=algorithm);
}

"""Create a token that's too old to refresh."""
def _create_very_old_token(username: str, days_ago: int = 15) -> str {
    secret = "supersecretkey_for_testing_only!";
    algorithm = "HS256";

    past_time = datetime.now(UTC) - timedelta(days=days_ago);
    payload = {
        "username": username,
        "exp": past_time + timedelta(hours=1),
        "iat": past_time
    };
    return pyjwt.encode(payload, secret, algorithm=algorithm);
}

# Shared state for main TestJacScaleServe
glob sv_fixtures_dir: Path = Path(
         __file__
     ).parent / "fixtures",
     sv_test_file: Path = sv_fixtures_dir / "test_api.jac",
     sv_port: int = get_free_port(),
     sv_base_url: str = f"http://localhost:{sv_port}",
     sv_ws_url: str = f"ws://localhost:{sv_port}";

"""Setup and start the serve server."""
def setup_serve_server -> subprocess.Popen {
    if not sv_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {sv_test_file}") ;
    }
    _cleanup_db_files(sv_fixtures_dir);
    return _start_server(sv_fixtures_dir, sv_test_file, sv_port, sv_base_url);
}

"""Teardown the serve server."""
def teardown_serve_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(sv_fixtures_dir);
}

test "server root endpoint" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/docs", timeout=5);
        assert response.status_code == 200;
    } finally {
        teardown_serve_server(sp);
    }
}

test "user creation" {
    sp = setup_serve_server();
    try {
        result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "testuser1", "password": "testpass123"}
        );
        assert "username" in result;
        assert "token" in result;
        assert "root_id" in result;
        assert result["username"] == "testuser1";
    } finally {
        teardown_serve_server(sp);
    }
}

test "user login" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "loginuser", "password": "loginpass"}
        );
        login_result = _request(
            sv_base_url,
            "POST",
            "/user/login",
            {"username": "loginuser", "password": "loginpass"}
        );

        assert "token" in login_result;
        assert login_result["username"] == "loginuser";
        assert login_result["root_id"] == create_result["root_id"];
    } finally {
        teardown_serve_server(sp);
    }
}

test "user login wrong password" {
    sp = setup_serve_server();
    try {
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "failuser", "password": "correctpass"}
        );
        login_result = _request(
            sv_base_url,
            "POST",
            "/user/login",
            {"username": "failuser", "password": "wrongpass"}
        );
        assert "error" in login_result;
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with missing token" {
    sp = setup_serve_server();
    try {
        refresh_result = _request(sv_base_url, "POST", "/user/refresh-token", {});

        if "detail" in refresh_result {
            assert isinstance(refresh_result["detail"], list);
            error_entry = refresh_result["detail"][0];
            assert error_entry["loc"] == ["body", "token"];
            assert error_entry["type"] == "missing";
        } else {
            assert "error" in refresh_result;
            assert refresh_result["error"] in [
                "Token is required",
                "Invalid or expired token"
            ];
        }
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with bearer prefix" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "refresh_bearer", "password": "password123"}
        );
        original_token = create_result["token"];

        refresh_result = _request(
            sv_base_url,
            "POST",
            "/user/refresh-token",
            {"token": f"Bearer {original_token}"}
        );

        assert "token" in refresh_result;
        assert "message" in refresh_result;
        assert refresh_result["message"] == "Token refreshed successfully";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with empty token" {
    sp = setup_serve_server();
    try {
        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": ""}
        );
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Token is required";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with invalid token" {
    sp = setup_serve_server();
    try {
        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": "invalid.token.here"}
        );
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with malformed token" {
    sp = setup_serve_server();
    try {
        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": "not.a.jwt"}
        );
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token too old" {
    sp = setup_serve_server();
    try {
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "refresh_old", "password": "password123"}
        );
        very_old_token = _create_very_old_token("refresh_old", days_ago=15);
        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": very_old_token}
        );
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token with nonexistent user" {
    sp = setup_serve_server();
    try {
        fake_token = _create_expired_token("nonexistent", days_ago=1);
        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": fake_token}
        );
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token multiple times" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "refresh_multi", "password": "password123"}
        );
        token1 = create_result["token"];

        refresh_result1 = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": token1}
        );
        token2 = refresh_result1["token"];
        assert token2 != token1;

        refresh_result2 = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": token2}
        );
        token3 = refresh_result2["token"];
        assert token3 != token2;
        assert token3 != token1;
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh token preserves username" {
    sp = setup_serve_server();
    try {
        username = "refresh_preserve";
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "password123"}
        );
        original_token = create_result["token"];

        refresh_result = _request(
            sv_base_url, "POST", "/user/refresh-token", {"token": original_token}
        );
        new_token = refresh_result["token"];

        secret = "supersecretkey_for_testing_only!";
        algorithm = "HS256";

        original_payload = pyjwt.decode(original_token, secret, algorithms=[algorithm]);
        new_payload = pyjwt.decode(new_token, secret, algorithms=[algorithm]);

        assert original_payload["username"] == username;
        assert new_payload["username"] == username;
        assert original_payload["username"] == new_payload["username"];
    } finally {
        teardown_serve_server(sp);
    }
}

test "refresh endpoint in openapi docs" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/openapi.json", timeout=5);
        assert response.status_code == 200;

        openapi_spec = response.json();
        paths = openapi_spec.get("paths", {});

        assert "/user/refresh-token" in paths;
        refresh_endpoint = paths["/user/refresh-token"];
        assert "post" in refresh_endpoint;

        post_spec = refresh_endpoint["post"];
        assert post_spec["summary"] == "Refresh JWT token";
        assert "User APIs" in post_spec["tags"];
    } finally {
        teardown_serve_server(sp);
    }
}

test "call function add numbers" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "adduser", "password": "pass"}
        );
        token = create_result["token"];

        result = _request(
            sv_base_url,
            "POST",
            "/function/add_numbers",
            {"a": 10, "b": 25},
            token=token
        );

        assert "result" in result;
        assert result["result"] == 35;
    } finally {
        teardown_serve_server(sp);
    }
}

test "call function greet" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "greetuser", "password": "pass"}
        );
        token = create_result["token"];

        result = _request(
            sv_base_url, "POST", "/function/greet", {"name": "Alice"}, token=token
        );

        assert "result" in result;
        assert result["result"] == "Hello, Alice!";
    } finally {
        teardown_serve_server(sp);
    }
}

test "call function with defaults" {
    sp = setup_serve_server();
    try {
        username = f"defuser_{uuid.uuid4().hex[:8]}";
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "pass"}
        );
        assert "token" in create_result , f"Registration failed: {create_result}";
        token = create_result["token"];

        result = _request(
            sv_base_url, "POST", "/function/greet", {"args": {}}, token=token
        );

        assert "result" in result;
        assert result["result"] == "Hello, World!";
    } finally {
        teardown_serve_server(sp);
    }
}

test "invalid function" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "invalidfunc", "password": "pass"}
        );
        token = create_result["token"];

        result = _request(
            sv_base_url, "POST", "/function/nonexistent", {"args": {}}, token=token
        );

        assert "Method Not Allowed" in result["detail"];
    } finally {
        teardown_serve_server(sp);
    }
}

test "invalid walker" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "invalidwalk", "password": "pass"}
        );
        token = create_result["token"];

        result = _request(
            sv_base_url,
            "POST",
            "/walker/NonExistentWalker",
            {"fields": {}},
            token=token
        );

        assert "Method Not Allowed" in result["detail"];
    } finally {
        teardown_serve_server(sp);
    }
}

test "multiply function" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "multuser", "password": "pass"}
        );
        token = create_result["token"];

        result = _request(
            sv_base_url, "POST", "/function/multiply", {"x": 7, "y": 8}, token=token
        );

        assert "result" in result;
        assert result["result"] == 56;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code user register 201 success" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": "status201", "password": "password123"},
            timeout=5
        );
        assert response.status_code == 201;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert "token" in data;
        assert "username" in data;
        assert data["username"] == "status201";
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code user register 400 already exists" {
    sp = setup_serve_server();
    try {
        username = "status400exists";
        requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5
        );

        response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5
        );
        assert response.status_code == 400;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert "error" in data;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code user login 200 success" {
    sp = setup_serve_server();
    try {
        username = "status200login";
        requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5
        );

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "password123"},
            timeout=5
        );
        assert response.status_code == 200;
        data = _extract_transport_response_data(response.json());
        assert "token" in data;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code user login 400 missing credentials" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/user/login", json={"username": "test"}, timeout=5
        );
        assert response.status_code in [400, 422];
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert "error" in data or "detail" in data;

        response = requests.post(
            f"{sv_base_url}/user/login", json={"password": "password123"}, timeout=5
        );
        assert response.status_code in [400, 422];

        response = requests.post(f"{sv_base_url}/user/login", json={}, timeout=5);
        assert response.status_code in [400, 422];

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": "", "password": "password123"},
            timeout=5
        );
        assert response.status_code == 400;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert data["error"] == "Username and password required";
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code user login 401 invalid credentials" {
    sp = setup_serve_server();
    try {
        username = "status401login";
        requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": "correctpass"},
            timeout=5
        );

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "wrongpass"},
            timeout=5
        );
        assert response.status_code == 401;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert data["error"] == "Invalid credentials";

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": "nonexistent", "password": "password"},
            timeout=5
        );
        assert response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code refresh token 200 success" {
    sp = setup_serve_server();
    try {
        create_response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": "status200refresh", "password": "password123"},
            timeout=5
        );
        create_data = cast(
            dict[str, Any], _extract_transport_response_data(create_response.json())
        );
        token = create_data["token"];

        response = requests.post(
            f"{sv_base_url}/user/refresh-token", json={"token": token}, timeout=5
        );
        assert response.status_code == 200;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert "token" in data;
        assert data["message"] == "Token refreshed successfully";
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code refresh token 400 missing token" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/user/refresh-token", json={"token": ""}, timeout=5
        );
        assert response.status_code == 400;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert data["error"] == "Token is required";

        response = requests.post(
            f"{sv_base_url}/user/refresh-token", json={"token": None}, timeout=5
        );
        assert response.status_code in [400, 422];
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code refresh token 401 invalid token" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/user/refresh-token",
            json={"token": "invalid_token_string"},
            timeout=5
        );
        assert response.status_code == 401;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert data["error"] == "Invalid or expired token";

        response = requests.post(
            f"{sv_base_url}/user/refresh-token", json={"token": "not.a.jwt"}, timeout=5
        );
        assert response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code walker 200 success" {
    sp = setup_serve_server();
    try {
        create_response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": "status200walker", "password": "password123"},
            timeout=5
        );
        create_data = cast(
            dict[str, Any], _extract_transport_response_data(create_response.json())
        );
        token = create_data["token"];

        response = requests.post(
            f"{sv_base_url}/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code function 200 success" {
    sp = setup_serve_server();
    try {
        create_response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": "status200func", "password": "password123"},
            timeout=5
        );
        create_data = cast(
            dict[str, Any], _extract_transport_response_data(create_response.json())
        );
        token = create_data["token"];

        response = requests.post(
            f"{sv_base_url}/function/add_numbers",
            json={"a": 10, "b": 20},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
        assert "result" in data;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code page 404 not found" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/cl/nonexistent_page_xyz", timeout=5);
        assert response.status_code == 404;
        assert "404" in response.text;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code static client js 200 or 503" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/static/client.js", timeout=60);
        assert response.status_code in [200, 503, 500];
        if response.status_code == 200 {
            assert "application/javascript" in response.headers.get("content-type", "");
        }
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code static file 404 not found" {
    sp = setup_serve_server();
    try {
        response = requests.get(
            f"{sv_base_url}/static/nonexistent_file.css", timeout=5
        );
        assert response.status_code == 404;
        assert "not found" in response.text.lower();
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code root asset 404 not found" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/nonexistent_image.png", timeout=5);
        assert response.status_code == 404;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code root asset 404 disallowed extension" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/malware.exe", timeout=5);
        assert response.status_code == 404;

        response = requests.get(f"{sv_base_url}/script.php", timeout=5);
        assert response.status_code == 404;
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code root asset 404 reserved paths" {
    sp = setup_serve_server();
    try {
        reserved_paths = [
            "page/something.png",
            "walker/something.png",
            "function/something.png",
            "user/something.png",
            "static/something.png"
        ];

        for path in reserved_paths {
            response = requests.get(f"{sv_base_url}/{path}", timeout=5);
            assert response.status_code == 404;
        }
    } finally {
        teardown_serve_server(sp);
    }
}

test "status code integration auth flow" {
    sp = setup_serve_server();
    try {
        username = "integration_status";

        register_response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": "secure123"},
            timeout=5
        );
        assert register_response.status_code == 201;
        data = cast(
            dict[str, Any], _extract_transport_response_data(register_response.json())
        );
        token1 = data["token"];

        login_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "secure123"},
            timeout=5
        );
        assert login_response.status_code == 200;
        data = cast(
            dict[str, Any], _extract_transport_response_data(login_response.json())
        );
        token2 = data["token"];

        refresh_response = requests.post(
            f"{sv_base_url}/user/refresh-token", json={"token": token1}, timeout=5
        );
        assert refresh_response.status_code == 200;
        data = cast(
            dict[str, Any], _extract_transport_response_data(refresh_response.json())
        );
        token3 = data["token"];

        fail_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "wrongpass"},
            timeout=5
        );
        assert fail_response.status_code == 401;

        assert token1 != token2;
        assert token2 != token3;
        assert token1 != token3;
    } finally {
        teardown_serve_server(sp);
    }
}

test "private walker 401 unauthorized" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=5
        );
        assert response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "public walker 200 no auth" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/walker/PublicInfo", json={}, timeout=5
        );
        assert response.status_code == 200;
        response_data = cast(
            dict[str, Any], _extract_transport_response_data(response.json())
        );
        data = response_data["reports"][0];
        assert "message" in data;
        assert data["message"] == "This is a public endpoint";
        assert "auth_required" in data;
        assert data["auth_required"] is False;
    } finally {
        teardown_serve_server(sp);
    }
}

test "public walker 200 with auth" {
    sp = setup_serve_server();
    try {
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": "publicuser", "password": "password123"}
        );
        token = create_result["token"];

        response = requests.post(
            f"{sv_base_url}/walker/PublicInfo",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 200;
        response_data = cast(
            dict[str, Any], _extract_transport_response_data(response.json())
        );
        data = response_data["reports"][0];
        assert "message" in data;
        assert data["message"] == "This is a public endpoint";
    } finally {
        teardown_serve_server(sp);
    }
}

test "private walker 401 with deleted user token" {
    sp = setup_serve_server();
    try {
        secret = "supersecretkey_for_testing_only!";
        now = datetime.now(UTC);
        payload = {
            "username": "deleted_user",
            "exp": now + timedelta(days=1),
            "iat": now
        };
        token = pyjwt.encode(payload, secret, algorithm="HS256");

        response = requests.post(
            f"{sv_base_url}/walker/PrivateCreateTask",
            json={"title": "Ghost Task", "priority": 1},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 401 , (
            f"Expected 401 for deleted/non-existent user, got {response.status_code}"
        );
    } finally {
        teardown_serve_server(sp);
    }
}

test "custom response headers from config" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/docs", timeout=5);

        assert "x-custom-test-header" in response.headers;
        assert response.headers["x-custom-test-header"] == "test-value";

        assert "cross-origin-opener-policy" in response.headers;
        assert response.headers["cross-origin-opener-policy"] == "same-origin";
        assert "cross-origin-embedder-policy" in response.headers;
        assert response.headers["cross-origin-embedder-policy"] == "require-corp";
    } finally {
        teardown_serve_server(sp);
    }
}

test "update username success" {
    sp = setup_serve_server();
    try {
        username = f"olduser_{uuid.uuid4().hex[:8]}";
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "password123"}
        );
        original_token = create_result["token"];
        original_root_id = create_result["root_id"];

        new_username = f"newuser_{uuid.uuid4().hex[:8]}";
        update_result = _request(
            sv_base_url,
            "PUT",
            "/user/username",
            {"current_username": username, "new_username": new_username},
            token=original_token
        );

        assert "username" in update_result;
        assert update_result["username"] == new_username;
        assert "token" in update_result;
        assert "root_id" in update_result;
        assert update_result["root_id"] == original_root_id;

        login_result = _request(
            sv_base_url,
            "POST",
            "/user/login",
            {"username": new_username, "password": "password123"}
        );
        assert login_result["username"] == new_username;
        assert "token" in login_result;

        login_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "password123"},
            timeout=5
        );
        assert login_response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update username requires auth" {
    sp = setup_serve_server();
    try {
        username = f"authtest_{uuid.uuid4().hex[:8]}";
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "password123"}
        );

        response = requests.put(
            f"{sv_base_url}/user/username",
            json={"current_username": username, "new_username": "newname"},
            timeout=5
        );
        assert response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update username cannot update other users" {
    sp = setup_serve_server();
    try {
        user1_name = f"user1_{uuid.uuid4().hex[:8]}";
        user1_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"}
        );
        user1_token = user1_result["token"];

        user2_name = f"user2_{uuid.uuid4().hex[:8]}";
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"}
        );

        response = requests.put(
            f"{sv_base_url}/user/username",
            json={"current_username": user2_name, "new_username": "hacked"},
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5
        );
        assert response.status_code == 403;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update username duplicate fails" {
    sp = setup_serve_server();
    try {
        user1_name = f"user1_{uuid.uuid4().hex[:8]}";
        user1_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"}
        );
        user1_token = user1_result["token"];

        user2_name = f"user2_{uuid.uuid4().hex[:8]}";
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"}
        );

        response = requests.put(
            f"{sv_base_url}/user/username",
            json={"current_username": user1_name, "new_username": user2_name},
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5
        );
        assert response.status_code == 400;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update username empty validation" {
    sp = setup_serve_server();
    try {
        username = f"testuser_{uuid.uuid4().hex[:8]}";
        user_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "password123"}
        );
        token = user_result["token"];

        response = requests.put(
            f"{sv_base_url}/user/username",
            json={"current_username": username, "new_username": ""},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 400;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update password success" {
    sp = setup_serve_server();
    try {
        username = f"passuser_{uuid.uuid4().hex[:8]}";
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass123"}
        );
        token = create_result["token"];

        update_result = _request(
            sv_base_url,
            "PUT",
            "/user/password",
            {
                "username": username,
                "current_password": "oldpass123",
                "new_password": "newpass456"
            },
            token=token
        );

        assert "username" in update_result;
        assert update_result["username"] == username;
        assert "message" in update_result or "success" in str(update_result).lower();

        login_result = _request(
            sv_base_url,
            "POST",
            "/user/login",
            {"username": username, "password": "newpass456"}
        );
        assert login_result["username"] == username;

        login_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "oldpass123"},
            timeout=5
        );
        assert login_response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update password requires auth" {
    sp = setup_serve_server();
    try {
        username = f"noauthuser_{uuid.uuid4().hex[:8]}";
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "password123"}
        );

        response = requests.put(
            f"{sv_base_url}/user/password",
            json={
                "username": username,
                "current_password": "password123",
                "new_password": "newpass"
            },
            timeout=5
        );
        assert response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update password wrong current password" {
    sp = setup_serve_server();
    try {
        username = f"wrongpass_{uuid.uuid4().hex[:8]}";
        user_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "correctpass"}
        );
        token = user_result["token"];

        response = requests.put(
            f"{sv_base_url}/user/password",
            json={
                "username": username,
                "current_password": "wrongpass",
                "new_password": "newpass"
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 400;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update password cannot update other users" {
    sp = setup_serve_server();
    try {
        user1_name = f"passuser1_{uuid.uuid4().hex[:8]}";
        user1_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"}
        );
        user1_token = user1_result["token"];

        user2_name = f"passuser2_{uuid.uuid4().hex[:8]}";
        _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"}
        );

        response = requests.put(
            f"{sv_base_url}/user/password",
            json={
                "username": user2_name,
                "current_password": "pass2",
                "new_password": "hacked"
            },
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5
        );
        assert response.status_code == 403;
    } finally {
        teardown_serve_server(sp);
    }
}

test "update password empty validation" {
    sp = setup_serve_server();
    try {
        username = f"emptypass_{uuid.uuid4().hex[:8]}";
        user_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass"}
        );
        token = user_result["token"];

        response = requests.put(
            f"{sv_base_url}/user/password",
            json={
                "username": username,
                "current_password": "oldpass",
                "new_password": ""
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        );
        assert response.status_code == 400;
    } finally {
        teardown_serve_server(sp);
    }
}

test "username and password update flow" {
    sp = setup_serve_server();
    try {
        username = f"original_{uuid.uuid4().hex[:8]}";
        create_result = _request(
            sv_base_url,
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass"}
        );
        token = create_result["token"];
        root_id = create_result["root_id"];

        new_username = f"updated_{uuid.uuid4().hex[:8]}";
        username_update = _request(
            sv_base_url,
            "PUT",
            "/user/username",
            {"current_username": username, "new_username": new_username},
            token=token
        );
        new_token = username_update["token"];
        assert username_update["root_id"] == root_id;

        password_update = _request(
            sv_base_url,
            "PUT",
            "/user/password",
            {
                "username": new_username,
                "current_password": "oldpass",
                "new_password": "newpass"
            },
            token=new_token
        );
        assert password_update["username"] == new_username;

        login_result = _request(
            sv_base_url,
            "POST",
            "/user/login",
            {"username": new_username, "password": "newpass"}
        );
        assert login_result["username"] == new_username;
        assert login_result["root_id"] == root_id;

        old_username_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": "newpass"},
            timeout=5
        );
        assert old_username_response.status_code == 401;

        old_password_response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": new_username, "password": "oldpass"},
            timeout=5
        );
        assert old_password_response.status_code == 401;
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket endpoint not in openapi" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/openapi.json", timeout=5);
        assert response.status_code == 200;
        schema = response.json();
        paths = schema.get("paths", {});

        assert "/walker/EchoMessage" not in paths , (
            "WebSocket walker EchoMessage should not be in /walker/ paths"
        );
        assert "/walker/MinimalWebSocket" not in paths , (
            "WebSocket walker MinimalWebSocket should not be in /walker/ paths"
        );
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket connect and echo" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/EchoMessage") as ws {
                await ws.send(json.dumps({"message": "hello", "client_id": "test-1"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is True , f"Expected ok=True, got {response}";
                data = response["data"];
                rpt = data;
                if "reports" in data {
                    rpt = data["reports"][0];
                }
                assert rpt["echo"] == "hello";
                assert rpt["client_id"] == "test-1";
                assert rpt["protocol"] == "websocket";
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket minimal walker" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/MinimalWebSocket") as ws {
                await ws.send(json.dumps({}));
                response = json.loads(await ws.recv());
                assert response["ok"] is True , f"Expected ok=True, got {response}";
                data = response["data"];
                rpt = data;
                if "reports" in data {
                    rpt = data["reports"][0];
                }
                assert rpt["status"] == "connected";
                assert rpt["protocol"] == "websocket";
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket multiple messages" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/EchoMessage") as ws {
                for i in range(3) {
                    await ws.send(
                        json.dumps({"message": f"msg-{i}", "client_id": f"client-{i}"})
                    );
                    response = json.loads(await ws.recv());
                    assert response["ok"] is True;
                    data = response["data"];
                    rpt = data;
                    if "reports" in data {
                        rpt = data["reports"][0];
                    }
                    assert rpt["echo"] == f"msg-{i}";
                    assert rpt["client_id"] == f"client-{i}";
                }
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket not accessible via walker endpoint" {
    sp = setup_serve_server();
    try {
        response = requests.post(
            f"{sv_base_url}/walker/EchoMessage",
            json={"message": "test", "client_id": "test"},
            timeout=10
        );
        assert response.status_code in (400, 404, 405) , (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        );
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket nonexistent walker" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            try {
                async with websockets.connect(f"{sv_ws_url}/ws/NonExistentWalker") as ws {
                    await ws.recv();
                    pytest.fail("Expected connection to be rejected");
                }
            } except (websockets.exceptions.ConnectionClosed, Exception) {
                0;
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "http walker not accessible via ws" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            try {
                async with websockets.connect(f"{sv_ws_url}/ws/CreateTask") as ws {
                    await ws.recv();
                    pytest.fail("Expected connection to be rejected for HTTP walker");
                }
            } except (websockets.exceptions.ConnectionClosed, Exception) {
                0;
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "private websocket requires auth" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send(json.dumps({"message": "hello"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is False , f"Expected ok=False, got {response}";
                assert response["error"]["code"] == "UNAUTHORIZED";
                assert "token" in response["error"]["message"].lower();
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "private websocket with valid token" {
    import websockets;
    sp = setup_serve_server();
    try {
        username = f"ws_test_user_{uuid.uuid4().hex[:8]}";
        password = "testpass123";

        response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": password},
            timeout=10
        );
        assert response.status_code in (200, 201) , f"Failed to create user: {response.text}";

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": password},
            timeout=10
        );
        assert response.status_code == 200 , f"Failed to login: {response.text}";
        token = response.json()["data"]["token"];

        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send(
                    json.dumps({"message": "authenticated hello", "token": token})
                );
                response = json.loads(await ws.recv());
                assert response["ok"] is True , f"Expected ok=True, got {response}";
                data = response["data"];
                rpt = data;
                if "reports" in data {
                    rpt = data["reports"][0];
                }
                assert rpt["authenticated"] is True;
                assert rpt["message"] == "authenticated hello";
                assert rpt["protocol"] == "websocket";
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "private websocket with query token" {
    import websockets;
    sp = setup_serve_server();
    try {
        username = f"ws_query_user_{uuid.uuid4().hex[:8]}";
        password = "testpass123";

        response = requests.post(
            f"{sv_base_url}/user/register",
            json={"username": username, "password": password},
            timeout=10
        );
        assert response.status_code in (200, 201);

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={"username": username, "password": password},
            timeout=10
        );
        assert response.status_code == 200;
        token = response.json()["data"]["token"];

        async def _test -> None {
            async with websockets.connect(
                f"{sv_ws_url}/ws/PrivateWebSocket?token={token}"
            ) as ws {
                await ws.send(json.dumps({"message": "query auth hello"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is True , f"Expected ok=True, got {response}";
                data = response["data"];
                rpt = data;
                if "reports" in data {
                    rpt = data["reports"][0];
                }
                assert rpt["authenticated"] is True;
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "broadcast websocket all clients receive" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/BroadcastChat") as ws1 {
                async with websockets.connect(f"{sv_ws_url}/ws/BroadcastChat") as ws2 {
                    await asyncio.sleep(0.1);
                    await ws1.send(
                        json.dumps({"message": "hello everyone", "sender": "client1"})
                    );
                    response1 = json.loads(
                        await asyncio.wait_for(ws1.recv(), timeout=5)
                    );
                    response2 = json.loads(
                        await asyncio.wait_for(ws2.recv(), timeout=5)
                    );
                    assert response1["ok"] is True , f"Client1 expected ok=True: {response1}";
                    assert response2["ok"] is True , f"Client2 expected ok=True: {response2}";
                    data1 = response1["data"];
                    data2 = response2["data"];
                    rpt1 = data1;
                    if "reports" in data1 {
                        rpt1 = data1["reports"][0];
                    }
                    rpt2 = data2;
                    if "reports" in data2 {
                        rpt2 = data2["reports"][0];
                    }
                    assert rpt1["content"] == "hello everyone";
                    assert rpt1["sender"] == "client1";
                    assert rpt1["broadcast"] is True;
                    assert rpt2["content"] == "hello everyone";
                    assert rpt2["sender"] == "client1";
                    assert rpt2["broadcast"] is True;
                }
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "private broadcast requires auth" {
    import websockets;
    sp = setup_serve_server();
    try {
        async def _test -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/PrivateBroadcastChat") as ws {
                await ws.send(json.dumps({"message": "hello", "room": "general"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is False;
                assert response["error"]["code"] == "UNAUTHORIZED";
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "private broadcast with auth" {
    import websockets;
    sp = setup_serve_server();
    try {
        users = [];
        for i in range(2) {
            username = f"broadcast_user_{i}_{uuid.uuid4().hex[:8]}";
            password = "testpass123";

            response = requests.post(
                f"{sv_base_url}/user/register",
                json={"username": username, "password": password},
                timeout=10
            );
            assert response.status_code in (200, 201);

            response = requests.post(
                f"{sv_base_url}/user/login",
                json={"username": username, "password": password},
                timeout=10
            );
            assert response.status_code == 200;
            users.append(
                {"username": username, "token": response.json()["data"]["token"]}
            );
        }

        async def _test -> None {
            async with websockets.connect(
                f"{sv_ws_url}/ws/PrivateBroadcastChat?token={users[0]['token']}"
            ) as ws1 {
                async with websockets.connect(
                    f"{sv_ws_url}/ws/PrivateBroadcastChat?token={users[1]['token']}"
                ) as ws2 {
                    await asyncio.sleep(0.1);
                    await ws1.send(
                        json.dumps({"message": "secret broadcast", "room": "team"})
                    );
                    response1 = json.loads(
                        await asyncio.wait_for(ws1.recv(), timeout=5)
                    );
                    response2 = json.loads(
                        await asyncio.wait_for(ws2.recv(), timeout=5)
                    );
                    assert response1["ok"] is True;
                    assert response2["ok"] is True;
                    data1 = response1["data"];
                    data2 = response2["data"];
                    rpt1 = data1;
                    if "reports" in data1 {
                        rpt1 = data1["reports"][0];
                    }
                    rpt2 = data2;
                    if "reports" in data2 {
                        rpt2 = data2["reports"][0];
                    }
                    assert rpt1["content"] == "secret broadcast";
                    assert rpt1["authenticated"] is True;
                    assert rpt1["broadcast"] is True;
                    assert rpt2["content"] == "secret broadcast";
                    assert rpt2["authenticated"] is True;
                }
            }
        }
        asyncio.run(_test());
    } finally {
        teardown_serve_server(sp);
    }
}

test "websocket walkers not in openapi" {
    sp = setup_serve_server();
    try {
        response = requests.get(f"{sv_base_url}/openapi.json", timeout=5);
        assert response.status_code == 200;
        schema = response.json();
        paths = schema.get("paths", {});

        ws_walkers = [
            "EchoMessage",
            "MinimalWebSocket",
            "PrivateWebSocket",
            "BroadcastChat",
            "PrivateBroadcastChat"
        ];
        for walker in ws_walkers {
            assert f"/walker/{walker}" not in paths , (
                f"WebSocket walker {walker} should not be in /walker/ paths"
            );
        }
    } finally {
        teardown_serve_server(sp);
    }
}

# TestJacScaleServeDevMode
glob dm_fixtures_dir: Path = Path(__file__).parent / "fixtures",
     dm_test_file: Path = dm_fixtures_dir / "test_api.jac",
     dm_vite_port: int = get_free_port(),
     dm_api_port: int = dm_vite_port + 1,
     dm_base_url: str = f"http://localhost:{dm_api_port}";

"""Extract data from TransportResponse envelope for dev mode."""
def _extract_data_dev(json_response: dict[str, Any]) -> dict[str, Any] {
    if isinstance(json_response, dict) and "ok" in json_response {
        if json_response.get("ok") and json_response.get("data") is not None {
            return json_response["data"];
        } elif not json_response.get("ok") and json_response.get("error") {
            error_info = json_response["error"];
            return {"error": error_info.get("message", "Unknown error")};
        }
    }
    return json_response;
}

"""Setup and start the dev mode server."""
def setup_dev_mode_server -> subprocess.Popen {
    if not dm_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {dm_test_file}") ;
    }
    _cleanup_db_files(dm_fixtures_dir);

    jac_executable = Path(sys.executable).parent / "jac";
    cmd = [
        str(jac_executable),
        "start",
        str(dm_test_file),
        "--port",
        str(dm_vite_port),
        "--dev"
    ];

    server_process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    );

    max_attempts = 50;
    server_ready = False;

    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(
                f"Server process terminated unexpectedly.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            ) ;
        }

        try {
            response = requests.get(f"{dm_base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                print(
                    f"Dev mode server started successfully on API port {dm_api_port}"
                );
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(2);
        }
    }

    if not (server_ready) {
        server_process.terminate();
        try {
            (stdout, stderr) = server_process.communicate(timeout=2);
        } except subprocess.TimeoutExpired {
            server_process.kill();
            (stdout, stderr) = server_process.communicate();
        }
        raise RuntimeError(
            f"Server failed to start in dev mode after {max_attempts} attempts.\n"
            f"STDOUT: {stdout}\nSTDERR: {stderr}"
        ) ;
    }

    return server_process;
}

"""Teardown the dev mode server."""
def teardown_dev_mode_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(dm_fixtures_dir);
}

test "dev mode walker body parsing" {
    sp = setup_dev_mode_server();
    try {
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json={"username": f"devtest_{uuid.uuid4().hex[:8]}", "password": "pass"},
            timeout=10
        );
        assert register_response.status_code == 201;
        token = _extract_data_dev(register_response.json())["token"];

        response = requests.post(
            f"{dm_base_url}/walker/CreateTask",
            json={"title": "Watch Mode Task", "priority": 5},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = _extract_data_dev(response.json());

        assert "result" in data or "reports" in data , f"Unexpected response: {data}";
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "dev mode function body parsing" {
    sp = setup_dev_mode_server();
    try {
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json={"username": f"devfunc_{uuid.uuid4().hex[:8]}", "password": "pass"},
            timeout=10
        );
        assert register_response.status_code == 201;
        token = _extract_data_dev(register_response.json())["token"];

        response = requests.post(
            f"{dm_base_url}/function/add_numbers",
            json={"a": 42, "b": 58},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = _extract_data_dev(response.json());

        assert "result" in data , f"Expected 'result' in response: {data}";
        assert data["result"] == 100 , f"Expected 100, got {data['result']}";
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "dev mode public walker no auth" {
    sp = setup_dev_mode_server();
    try {
        response = requests.post(
            f"{dm_base_url}/walker/PublicInfo", json={}, timeout=10
        );

        assert response.status_code == 200;
        data = _extract_data_dev(response.json());
        assert "reports" in data;
        assert data["reports"][0]["message"] == "This is a public endpoint";
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "dev mode private walker requires auth" {
    sp = setup_dev_mode_server();
    try {
        response = requests.post(
            f"{dm_base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=10
        );

        assert response.status_code == 401;
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "async walker basic execution" {
    sp = setup_dev_mode_server();
    try {
        username = f"asyncuser_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10
        );
        assert register_response.status_code == 201;
        token = _extract_data_dev(register_response.json())["token"];

        response = requests.post(
            f"{dm_base_url}/walker/AsyncCreateTask",
            json={"title": "Async Test Task", "delay_ms": 50},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = _extract_data_dev(response.json());

        assert "reports" in data , f"Expected 'reports' in response: {data}";
        reports = data["reports"];

        assert len(reports) >= 3 , f"Expected at least 3 reports, got {len(reports)}";

        assert reports[0]["status"] == "started";
        assert reports[0]["title"] == "Async Test Task";
        assert reports[1]["status"] == "after_async_wait";
        assert reports[2]["status"] == "completed";
        assert "task" in reports[2];
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "walker stream response" {
    sp = setup_dev_mode_server();
    try {
        response = requests.post(
            f"{dm_base_url}/walker/WalkerStream",
            json={"count": 3},
            timeout=30,
            stream=True
        );

        assert response.status_code == 200 , (
            f"Failed with status {response.status_code}: {response.text}"
        );
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8";
        assert response.headers.get("cache-control") == "no-cache";
        assert response.headers.get("connection") == "close";

        content = "";
        for chunk in response.iter_content(chunk_size=1024, decode_unicode=True) {
            if chunk {
                content += chunk;
            }
        }

        expected = "Report 0Report 1Report 2";
        assert content == expected , f"Expected '{expected}', got '{content}'";
    } finally {
        teardown_dev_mode_server(sp);
    }
}

test "function stream response" {
    sp = setup_dev_mode_server();
    try {
        response = requests.post(
            f"{dm_base_url}/function/FunctionStream",
            json={"count": 2},
            timeout=30,
            stream=True
        );

        assert response.status_code == 200 , (
            f"Failed with status {response.status_code}: {response.text}"
        );
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8";
        assert response.headers.get("cache-control") == "no-cache";
        assert response.headers.get("connection") == "close";

        content = "";
        for chunk in response.iter_content(chunk_size=1024, decode_unicode=True) {
            if chunk {
                content += chunk;
            }
        }

        expected = "Func 0Func 1";
        assert content == expected , f"Expected '{expected}', got '{content}'";
    } finally {
        teardown_dev_mode_server(sp);
    }
}
