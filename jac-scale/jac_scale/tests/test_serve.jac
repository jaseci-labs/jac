"""Test for jac-scale serve command and REST API server.

Optimized test structure: Tests are grouped by category to share server instances,
reducing CI time from ~13 minutes to ~2-3 minutes.
"""

import asyncio;
import contextlib;
import gc;
import glob;
import json;
import re;
import select;
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
import from typing { Any }
import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
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
            );
        }

        try {
            response = requests.get(f"{base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                print(f"Server started successfully on port {port}");
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(0.5);
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
        );
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
    time.sleep(0.2);
    gc.collect();
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

# =============================================================================
# SERVER CONFIGURATION (used by websocket, dev mode, and port fallback tests)
# =============================================================================
glob sv_fixtures_dir: Path = Path(__file__).parent / "fixtures",
     sv_test_file: Path = sv_fixtures_dir / "test_api.jac",
     sv_port: int = get_free_port(),
     sv_base_url: str = f"http://localhost:{sv_port}",
     sv_ws_url: str = f"ws://localhost:{sv_port}";

"""Setup and start the serve server."""
def setup_serve_server -> subprocess.Popen {
    if not sv_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {sv_test_file}");
    }
    _cleanup_db_files(sv_fixtures_dir);
    return _start_server(sv_fixtures_dir, sv_test_file, sv_port, sv_base_url);
}

"""Teardown the serve server."""
def teardown_serve_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(sv_fixtures_dir);
}

# =============================================================================
# GROUP 1: STATIC & SCHEMA TESTS (Read-only, no state changes)
# =============================================================================
test "static and schema endpoints" {
    client = make_client();
    try {
        # Test: server root endpoint returns docs
        response = client.get("/docs");
        assert response.status_code == 200 , "Docs endpoint should return 200";

        # Test: custom response headers from config
        assert "x-custom-test-header" in response.headers;
        assert response.headers["x-custom-test-header"] == "test-value";
        assert "cross-origin-opener-policy" in response.headers;
        assert response.headers["cross-origin-opener-policy"] == "same-origin";
        assert "cross-origin-embedder-policy" in response.headers;
        assert response.headers["cross-origin-embedder-policy"] == "require-corp";

        # Test: OpenAPI schema is accessible and correct
        openapi_response = client.get("/openapi.json");
        assert openapi_response.status_code == 200;
        openapi_spec = openapi_response.json();
        paths = openapi_spec.get("paths", {});

        # Test: refresh endpoint in openapi docs
        assert "/user/refresh-token" in paths;
        refresh_endpoint = paths["/user/refresh-token"];
        assert "post" in refresh_endpoint;
        post_spec = refresh_endpoint["post"];
        assert post_spec["summary"] == "Refresh JWT token";
        assert "User APIs" in post_spec["tags"];

        # Test: websocket endpoints NOT in openapi (they use /ws/ prefix)
        assert "/walker/EchoMessage" not in paths , "WebSocket walker should not be in /walker/ paths";
        assert "/walker/MinimalWebSocket" not in paths;
        ws_walkers = [
            "EchoMessage",
            "MinimalWebSocket",
            "PrivateWebSocket",
            "BroadcastChat",
            "PrivateBroadcastChat"
        ];
        for walker in ws_walkers {
            assert f"/walker/{walker}" not in paths , f"WebSocket walker {walker} should not be in /walker/ paths";
        }

        # Test: 404 responses for non-existent paths
        response = client.get("/cl/nonexistent_page_xyz");
        assert response.status_code == 404;
        assert "404" in response.text;

        response = client.get("/static/nonexistent_file.css");
        assert response.status_code == 404;
        assert "not found" in response.text.lower();

        response = client.get("/nonexistent_image.png");
        assert response.status_code == 404;

        # Test: disallowed extensions return 404
        response = client.get("/malware.exe");
        assert response.status_code == 404;
        response = client.get("/script.php");
        assert response.status_code == 404;

        # Test: reserved paths return 404 for asset requests
        reserved_paths = [
            "page/something.png",
            "walker/something.png",
            "function/something.png",
            "user/something.png",
            "static/something.png"
        ];
        for path in reserved_paths {
            response = client.get(f"/{path}");
            assert response.status_code == 404;
        }

        # Test: static client.js (may be 200, 503, or 500 depending on build state)
        response = client.get("/static/client.js");
        assert response.status_code in [200, 503, 500];
        if response.status_code == 200 {
            assert "application/javascript" in response.headers.get("content-type", "");
        }

        # Test: graph endpoint returns html page
        response = client.get("/graph");
        assert response.status_code == 200;
        assert "text/html" in response.headers["content-type"];
    } finally {
        client.close();
    }
}

# =============================================================================
# GROUP 2: USER AUTHENTICATION TESTS (Register, Login, Token Refresh)
# =============================================================================
test "user registration and login" {
    client = make_client();
    try {
        # Test: user creation
        test_username = f"testuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={"username": test_username, "password": "testpass123"}
        );
        result = extract_data(response.json());
        assert "username" in result;
        assert "token" in result;
        assert "root_id" in result;
        assert result["username"] == test_username;

        # Test: status code 201 for successful registration
        status_user = f"status_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": status_user, "password": "password123"}
        );
        assert response.status_code == 201;
        data = extract_data(response.json());
        assert "token" in data;
        assert data["username"] == status_user;

        # Test: status code 400 for duplicate registration
        response = client.post(
            "/user/register", json={"username": status_user, "password": "password123"}
        );
        assert response.status_code == 400;

        # Test: user login
        login_username = f"login_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={"username": login_username, "password": "loginpass"}
        );
        create_result = extract_data(response.json());
        response = client.post(
            "/user/login", json={"username": login_username, "password": "loginpass"}
        );
        login_result = extract_data(response.json());
        assert "token" in login_result;
        assert login_result["username"] == login_username;
        assert login_result["root_id"] == create_result["root_id"];

        # Test: status code 200 for successful login
        response = client.post(
            "/user/login", json={"username": login_username, "password": "loginpass"}
        );
        assert response.status_code == 200;

        # Test: user login wrong password
        fail_username = f"fail_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={"username": fail_username, "password": "correctpass"}
        );
        response = client.post(
            "/user/login", json={"username": fail_username, "password": "wrongpass"}
        );
        login_result = extract_data(response.json());
        assert "error" in login_result;

        # Test: status code 401 for invalid credentials
        response = client.post(
            "/user/login", json={"username": fail_username, "password": "wrongpass"}
        );
        assert response.status_code == 401;
        data = extract_data(response.json());
        assert data["error"] == "Invalid credentials";

        # Test: status code 400/422 for missing credentials
        response = client.post("/user/login", json={"username": "test"});
        assert response.status_code in [400, 422];

        response = client.post("/user/login", json={"password": "password123"});
        assert response.status_code in [400, 422];

        response = client.post("/user/login", json={});
        assert response.status_code in [400, 422];

        response = client.post(
            "/user/login", json={"username": "", "password": "password123"}
        );
        assert response.status_code == 400;
        data = extract_data(response.json());
        assert data["error"] == "Username and password required";

        # Test: nonexistent user returns 401
        response = client.post(
            "/user/login", json={"username": "nonexistent", "password": "password"}
        );
        assert response.status_code == 401;
    } finally {
        client.close();
    }
}

test "token refresh functionality" {
    client = make_client();
    try {
        # Test: refresh token with missing token
        response = client.post("/user/refresh-token", json={});
        refresh_result = extract_data(response.json());
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

        # Test: refresh token with empty token
        response = client.post("/user/refresh-token", json={"token": ""});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Token is required";

        # Test: status code 400 for empty token
        response = client.post("/user/refresh-token", json={"token": ""});
        assert response.status_code == 400;

        # Test: refresh token with invalid/malformed tokens (all return same error)
        invalid_tokens = ["invalid.token.here", "not.a.jwt", "invalid_token_string"];
        for invalid_token in invalid_tokens {
            response = client.post("/user/refresh-token", json={"token": invalid_token});
            refresh_result = extract_data(response.json());
            assert "error" in refresh_result;
            assert refresh_result["error"] == "Invalid or expired token";
        }

        # Test: status code 401 for invalid token
        response = client.post(
            "/user/refresh-token", json={"token": "invalid_token_string"}
        );
        assert response.status_code == 401;

        # Test: refresh token with bearer prefix
        response = client.post(
            "/user/register",
            json={
                "username": f"refresh_bearer_{uuid.uuid4().hex[:8]}",
                "password": "password123"
            }
        );
        create_result = extract_data(response.json());
        original_token = create_result["token"];

        response = client.post(
            "/user/refresh-token", json={"token": f"Bearer {original_token}"}
        );
        refresh_result = extract_data(response.json());
        assert "token" in refresh_result;
        assert "message" in refresh_result;
        assert refresh_result["message"] == "Token refreshed successfully";

        # Test: status code 200 for successful refresh
        response = client.post("/user/refresh-token", json={"token": original_token});
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "token" in data;
        assert data["message"] == "Token refreshed successfully";

        # Test: refresh token too old
        old_user = f"refresh_old_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": old_user, "password": "password123"}
        );
        very_old_token = _create_very_old_token(old_user, days_ago=15);
        response = client.post("/user/refresh-token", json={"token": very_old_token});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";

        # Test: refresh token with nonexistent user
        fake_token = _create_expired_token("nonexistent", days_ago=1);
        response = client.post("/user/refresh-token", json={"token": fake_token});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";

        # Test: refresh token multiple times
        response = client.post(
            "/user/register",
            json={
                "username": f"refresh_multi_{uuid.uuid4().hex[:8]}",
                "password": "password123"
            }
        );
        create_result = extract_data(response.json());
        token1 = create_result["token"];

        response = client.post("/user/refresh-token", json={"token": token1});
        refresh_result1 = extract_data(response.json());
        token2 = refresh_result1["token"];
        assert token2 != token1;

        response = client.post("/user/refresh-token", json={"token": token2});
        refresh_result2 = extract_data(response.json());
        token3 = refresh_result2["token"];
        assert token3 != token2;
        assert token3 != token1;

        # Test: refresh token preserves username
        username = f"refresh_preserve_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "password123"}
        );
        create_result = extract_data(response.json());
        original_token = create_result["token"];

        response = client.post("/user/refresh-token", json={"token": original_token});
        refresh_result = extract_data(response.json());
        new_token = refresh_result["token"];

        secret = "supersecretkey_for_testing_only!";
        algorithm = "HS256";

        original_payload = pyjwt.decode(original_token, secret, algorithms=[algorithm]);
        new_payload = pyjwt.decode(new_token, secret, algorithms=[algorithm]);

        assert original_payload["username"] == username;
        assert new_payload["username"] == username;
        assert original_payload["username"] == new_payload["username"];
    } finally {
        client.close();
    }
}

test "integration auth flow" {
    client = make_client();
    try {
        username = f"integration_{uuid.uuid4().hex[:8]}";

        # Register
        register_response = client.post(
            "/user/register", json={"username": username, "password": "secure123"}
        );
        assert register_response.status_code == 201;
        data = extract_data(register_response.json());
        token1 = data["token"];

        # Login
        login_response = client.post(
            "/user/login", json={"username": username, "password": "secure123"}
        );
        assert login_response.status_code == 200;
        data = extract_data(login_response.json());
        token2 = data["token"];

        # Refresh
        refresh_response = client.post("/user/refresh-token", json={"token": token1});
        assert refresh_response.status_code == 200;
        data = extract_data(refresh_response.json());
        token3 = data["token"];

        # Failed login
        fail_response = client.post(
            "/user/login", json={"username": username, "password": "wrongpass"}
        );
        assert fail_response.status_code == 401;

        # All tokens should be different
        assert token1 != token2;
        assert token2 != token3;
        assert token1 != token3;
    } finally {
        client.close();
    }
}

# =============================================================================
# GROUP 3: API OPERATIONS (Functions and Walkers)
# =============================================================================
test "function calls" {
    client = make_client();
    try {
        # Create a user for authenticated calls
        response = client.post(
            "/user/register",
            json={"username": f"funcuser_{uuid.uuid4().hex[:8]}", "password": "pass"}
        );
        create_result = extract_data(response.json());
        token = create_result["token"];

        # Test: call function add_numbers
        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 25},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == 35;

        # Test: call function greet
        response = client.post(
            "/function/greet",
            json={"name": "Alice"},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == "Hello, Alice!";

        # Test: call function with defaults
        response = client.post(
            "/function/greet",
            json={"args": {}},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == "Hello, World!";

        # Test: multiply function
        response = client.post(
            "/function/multiply",
            json={"x": 7, "y": 8},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == 56;

        # Test: status code 200 for function success
        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 20},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "result" in data;

        # Test: invalid function returns 404/405
        response = client.post(
            "/function/nonexistent",
            json={"args": {}},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in [404, 405];
    } finally {
        client.close();
    }
}

test "walker calls" {
    client = make_client();
    try {
        # Create a user for authenticated calls
        response = client.post(
            "/user/register",
            json={"username": f"walkeruser_{uuid.uuid4().hex[:8]}", "password": "pass"}
        );
        create_result = extract_data(response.json());
        token = create_result["token"];

        # Test: status code 200 for walker success
        response = client.post(
            "/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        # Test: invalid walker returns 404/405
        response = client.post(
            "/walker/NonExistentWalker",
            json={"fields": {}},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in [404, 405];

        # Test: private walker 401 unauthorized (no token)
        response = client.post(
            "/walker/PrivateCreateTask", json={"title": "Private Task", "priority": 1}
        );
        assert response.status_code == 401;

        # Test: public walker 200 no auth
        response = client.post("/walker/PublicInfo", json={});
        assert response.status_code == 200;
        response_data = extract_data(response.json());
        data = response_data["reports"][0];
        assert "message" in data;
        assert data["message"] == "This is a public endpoint";
        assert "auth_required" in data;
        assert data["auth_required"] is False;

        # Test: public walker 200 with auth
        response = client.post(
            "/walker/PublicInfo", json={}, headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        response_data = extract_data(response.json());
        data = response_data["reports"][0];
        assert data["message"] == "This is a public endpoint";

        # Test: private walker 401 with deleted user token
        secret = "supersecretkey_for_testing_only!";
        now = datetime.now(UTC);
        payload = {
            "username": "deleted_user",
            "exp": now + timedelta(days=1),
            "iat": now
        };
        fake_token = pyjwt.encode(payload, secret, algorithm="HS256");

        response = client.post(
            "/walker/PrivateCreateTask",
            json={"title": "Ghost Task", "priority": 1},
            headers={"Authorization": f"Bearer {fake_token}"}
        );
        assert response.status_code == 401 , (
            f"Expected 401 for deleted/non-existent user, got {response.status_code}"
        );

        # Test: graph data returns nodes and edges
        response = client.get("/graph/data");
        assert response.status_code == 200;
        data = response.json();
        assert "nodes" in data and "edges" in data;

        # Create a node and verify it appears for authenticated user
        response = client.post(
            "/user/register",
            json={"username": f"guser_{uuid.uuid4().hex[:8]}", "password": "gpass"}
        );
        reg = extract_data(response.json());
        response = client.post(
            "/walker/CreateTask",
            json={"title": "T1", "priority": 1},
            headers={"Authorization": f"Bearer {reg['token']}"}
        );
        auth_resp = client.get(
            "/graph/data", headers={"Authorization": f"Bearer {reg['token']}"}
        );
        auth_data = auth_resp.json();
        assert len(auth_data["nodes"]) == 2;
        assert len(auth_data["edges"]) == 1;
    } finally {
        client.close();
    }
}

# =============================================================================
# GROUP 4: USER MANAGEMENT (Username and Password Updates)
# =============================================================================
test "user management operations" {
    client = make_client();
    try {
        # Test: update username success
        username = f"olduser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "password123"}
        );
        create_result = extract_data(response.json());
        original_token = create_result["token"];
        original_root_id = create_result["root_id"];

        new_username = f"newuser_{uuid.uuid4().hex[:8]}";
        response = client.put(
            "/user/username",
            json={"current_username": username, "new_username": new_username},
            headers={"Authorization": f"Bearer {original_token}"}
        );
        update_result = extract_data(response.json());

        assert "username" in update_result;
        assert update_result["username"] == new_username;
        assert "token" in update_result;
        assert "root_id" in update_result;
        assert update_result["root_id"] == original_root_id;

        # Verify login with new username works
        response = client.post(
            "/user/login", json={"username": new_username, "password": "password123"}
        );
        login_result = extract_data(response.json());
        assert login_result["username"] == new_username;
        assert "token" in login_result;

        # Verify login with old username fails
        login_response = client.post(
            "/user/login", json={"username": username, "password": "password123"}
        );
        assert login_response.status_code == 401;

        # Test: update username requires auth
        username = f"authtest_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "password123"}
        );
        response = client.put(
            "/user/username",
            json={"current_username": username, "new_username": "newname"}
        );
        assert response.status_code == 401;

        # Test: update username cannot update other users
        user1_name = f"user1_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user1_name, "password": "pass1"}
        );
        user1_result = extract_data(response.json());
        user1_token = user1_result["token"];

        user2_name = f"user2_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user2_name, "password": "pass2"}
        );

        response = client.put(
            "/user/username",
            json={"current_username": user2_name, "new_username": "hacked"},
            headers={"Authorization": f"Bearer {user1_token}"}
        );
        assert response.status_code == 403;

        # Test: update username duplicate fails
        user1_name = f"dup1_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user1_name, "password": "pass1"}
        );
        user1_result = extract_data(response.json());
        user1_token = user1_result["token"];

        user2_name = f"dup2_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user2_name, "password": "pass2"}
        );

        response = client.put(
            "/user/username",
            json={"current_username": user1_name, "new_username": user2_name},
            headers={"Authorization": f"Bearer {user1_token}"}
        );
        assert response.status_code == 400;

        # Test: update username empty validation
        username = f"testuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "password123"}
        );
        user_result = extract_data(response.json());
        token = user_result["token"];

        response = client.put(
            "/user/username",
            json={"current_username": username, "new_username": ""},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;

        # Test: update password success
        username = f"passuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "oldpass123"}
        );
        create_result = extract_data(response.json());
        token = create_result["token"];

        response = client.put(
            "/user/password",
            json={
                "username": username,
                "current_password": "oldpass123",
                "new_password": "newpass456"
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        update_result = extract_data(response.json());

        assert "username" in update_result;
        assert update_result["username"] == username;
        assert "message" in update_result or "success" in str(update_result).lower();

        # Verify login with new password works
        response = client.post(
            "/user/login", json={"username": username, "password": "newpass456"}
        );
        login_result = extract_data(response.json());
        assert login_result["username"] == username;

        # Verify login with old password fails
        login_response = client.post(
            "/user/login", json={"username": username, "password": "oldpass123"}
        );
        assert login_response.status_code == 401;

        # Test: update password requires auth
        username = f"noauthuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "password123"}
        );

        response = client.put(
            "/user/password",
            json={
                "username": username,
                "current_password": "password123",
                "new_password": "newpass"
            }
        );
        assert response.status_code == 401;

        # Test: update password wrong current password
        username = f"wrongpass_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "correctpass"}
        );
        user_result = extract_data(response.json());
        token = user_result["token"];

        response = client.put(
            "/user/password",
            json={
                "username": username,
                "current_password": "wrongpass",
                "new_password": "newpass"
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;

        # Test: update password cannot update other users
        user1_name = f"passuser1_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user1_name, "password": "pass1"}
        );
        user1_result = extract_data(response.json());
        user1_token = user1_result["token"];

        user2_name = f"passuser2_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": user2_name, "password": "pass2"}
        );

        response = client.put(
            "/user/password",
            json={
                "username": user2_name,
                "current_password": "pass2",
                "new_password": "hacked"
            },
            headers={"Authorization": f"Bearer {user1_token}"}
        );
        assert response.status_code == 403;

        # Test: update password empty validation
        username = f"emptypass_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "oldpass"}
        );
        user_result = extract_data(response.json());
        token = user_result["token"];

        response = client.put(
            "/user/password",
            json={
                "username": username,
                "current_password": "oldpass",
                "new_password": ""
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;

        # Test: username and password update flow (combined)
        username = f"original_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json={"username": username, "password": "oldpass"}
        );
        create_result = extract_data(response.json());
        token = create_result["token"];
        root_id = create_result["root_id"];

        new_username = f"updated_{uuid.uuid4().hex[:8]}";
        response = client.put(
            "/user/username",
            json={"current_username": username, "new_username": new_username},
            headers={"Authorization": f"Bearer {token}"}
        );
        username_update = extract_data(response.json());
        new_token = username_update["token"];
        assert username_update["root_id"] == root_id;

        response = client.put(
            "/user/password",
            json={
                "username": new_username,
                "current_password": "oldpass",
                "new_password": "newpass"
            },
            headers={"Authorization": f"Bearer {new_token}"}
        );
        password_update = extract_data(response.json());
        assert password_update["username"] == new_username;

        response = client.post(
            "/user/login", json={"username": new_username, "password": "newpass"}
        );
        login_result = extract_data(response.json());
        assert login_result["username"] == new_username;
        assert login_result["root_id"] == root_id;

        # Old username should fail
        old_username_response = client.post(
            "/user/login", json={"username": username, "password": "newpass"}
        );
        assert old_username_response.status_code == 401;

        # Old password should fail
        old_password_response = client.post(
            "/user/login", json={"username": new_username, "password": "oldpass"}
        );
        assert old_password_response.status_code == 401;
    } finally {
        client.close();
    }
}

# =============================================================================
# GROUP 5: WEBSOCKET TESTS
# =============================================================================
test "websocket functionality" {
    import websockets;
    sp = setup_serve_server();
    try {
        # Test: websocket connect and echo
        async def test_echo -> None {
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
        asyncio.run(test_echo());

        # Test: websocket minimal walker
        async def test_minimal -> None {
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
        asyncio.run(test_minimal());

        # Test: websocket multiple messages
        async def test_multiple -> None {
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
        asyncio.run(test_multiple());

        # Test: websocket not accessible via walker endpoint
        response = requests.post(
            f"{sv_base_url}/walker/EchoMessage",
            json={"message": "test", "client_id": "test"},
            timeout=10
        );
        assert response.status_code in (400, 404, 405) , (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        );

        # Test: websocket nonexistent walker
        async def test_nonexistent -> None {
            try {
                async with websockets.connect(
                    f"{sv_ws_url}/ws/NonExistentWalker"
                ) as ws {
                    await ws.recv();
                    pytest.fail("Expected connection to be rejected");
                }
            } except (websockets.exceptions.ConnectionClosed, Exception) {
                0;  # Expected
            }
        }
        asyncio.run(test_nonexistent());

        # Test: http walker not accessible via ws
        async def test_http_via_ws -> None {
            try {
                async with websockets.connect(f"{sv_ws_url}/ws/CreateTask") as ws {
                    await ws.recv();
                    pytest.fail("Expected connection to be rejected for HTTP walker");
                }
            } except (websockets.exceptions.ConnectionClosed, Exception) {
                0;  # Expected
            }
        }
        asyncio.run(test_http_via_ws());

        # Test: private websocket requires auth
        async def test_private_no_auth -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send(json.dumps({"message": "hello"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is False , f"Expected ok=False, got {response}";
                assert response["error"]["code"] == "UNAUTHORIZED";
                assert "token" in response["error"]["message"].lower();
            }
        }
        asyncio.run(test_private_no_auth());

        # Test: private websocket with valid token
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

        async def test_private_with_token(t: str) -> None {
            async with websockets.connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send(
                    json.dumps({"message": "authenticated hello", "token": t})
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
        asyncio.run(test_private_with_token(token));

        # Test: private websocket with query token
        username = f"ws_query_user_{uuid.uuid4().hex[:8]}";
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
        query_token = response.json()["data"]["token"];

        async def test_query_token(t: str) -> None {
            async with websockets.connect(
                f"{sv_ws_url}/ws/PrivateWebSocket?token={t}"
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
        asyncio.run(test_query_token(query_token));

        # Test: broadcast websocket all clients receive
        async def test_broadcast -> None {
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
        asyncio.run(test_broadcast());

        # Test: private broadcast requires auth
        async def test_private_broadcast_no_auth -> None {
            async with websockets.connect(
                f"{sv_ws_url}/ws/PrivateBroadcastChat"
            ) as ws {
                await ws.send(json.dumps({"message": "hello", "room": "general"}));
                response = json.loads(await ws.recv());
                assert response["ok"] is False;
                assert response["error"]["code"] == "UNAUTHORIZED";
            }
        }
        asyncio.run(test_private_broadcast_no_auth());

        # Test: private broadcast with auth
        users: list = [];
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

        async def test_private_broadcast_with_auth(u: list) -> None {
            async with websockets.connect(
                f"{sv_ws_url}/ws/PrivateBroadcastChat?token={u[0]['token']}"
            ) as ws1 {
                async with websockets.connect(
                    f"{sv_ws_url}/ws/PrivateBroadcastChat?token={u[1]['token']}"
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
        asyncio.run(test_private_broadcast_with_auth(users));
    } finally {
        teardown_serve_server(sp);
    }
}

# =============================================================================
# GROUP 6: DEV MODE TESTS
# =============================================================================
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
        raise FileNotFoundError(f"Test fixture not found: {dm_test_file}");
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

    # Dev mode needs more time due to Jac compilation, bun setup, and vite initialization
    max_attempts = 60;
    server_ready = False;

    for _ in range(max_attempts) {
        if server_process.poll() is not None {
            (stdout, stderr) = server_process.communicate();
            raise RuntimeError(
                f"Server process terminated unexpectedly.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            );
        }

        try {
            response = requests.get(f"{dm_base_url}/docs", timeout=2);
            if response.status_code in (200, 404) {
                print(f"Dev mode server started successfully on API port {dm_api_port}");
                server_ready = True;
                break;
            }
        } except (requests.ConnectionError, requests.Timeout) {
            time.sleep(2);  # Dev mode needs longer polling interval for CI
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
        );
    }

    return server_process;
}

"""Teardown the dev mode server."""
def teardown_dev_mode_server(sp: subprocess.Popen | None) -> None {
    _stop_server(sp);
    _cleanup_db_files(dm_fixtures_dir);
}

test "dev mode operations" {
    sp = setup_dev_mode_server();
    try {
        # Test: dev mode walker body parsing
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

        # Test: dev mode function body parsing
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

        # Test: dev mode public walker no auth
        response = requests.post(
            f"{dm_base_url}/walker/PublicInfo", json={}, timeout=10
        );
        assert response.status_code == 200;
        data = _extract_data_dev(response.json());
        assert "reports" in data;
        assert data["reports"][0]["message"] == "This is a public endpoint";

        # Test: dev mode private walker requires auth
        response = requests.post(
            f"{dm_base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=10
        );
        assert response.status_code == 401;

        # Test: async walker basic execution
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

        # Test: walker stream response
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

        # Test: function stream response
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

# =============================================================================
# GROUP 7: PORT FALLBACK TESTS
# =============================================================================
import from jac_scale.serve {
    _find_available_port,
    _get_network_ips,
    PORT_RETRY_LIMIT,
    ERRNO_ADDR_IN_USE_LINUX,
    ERRNO_ADDR_IN_USE_WINDOWS
}

"""Test _find_available_port returns the same port when it's available."""
test "port fallback - available port returns same port" {
    # Get a free port and verify _find_available_port returns it
    free_port = get_free_port();
    result = _find_available_port(free_port);
    assert result == free_port , f"Expected {free_port}, got {result}";
}

"""Test _find_available_port finds next port when requested port is in use."""
test "port fallback - finds next available port when port in use" {
    # Bind to a port to block it
    blocked_port = get_free_port();
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(('0.0.0.0', blocked_port));
        s.listen(1);
        # Request the blocked port - should get next available
        result = _find_available_port(blocked_port);
        assert result > blocked_port , f"Expected port > {blocked_port}, got {result}";
        assert result <= blocked_port + PORT_RETRY_LIMIT , (
            f"Result {result} exceeds retry limit from {blocked_port}"
        );
    }
}

"""Test _find_available_port skips multiple blocked ports."""
test "port fallback - skips multiple blocked ports" {
    # Block consecutive ports
    start_port = get_free_port();
    sockets: list[socket.socket] = [];
    ports_to_block = 3;

    try {
        for i in range(ports_to_block) {
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
            try {
                s.bind(('0.0.0.0', start_port + i));
                s.listen(1);
                sockets.append(s);
            } except OSError {
                # Port already in use, skip
                s.close();
            }
        }

        # Request the first blocked port - should skip all blocked ones
        result = _find_available_port(start_port);
        assert result >= start_port + len(sockets) , (
            f"Expected port >= {start_port + len(sockets)}, got {result}"
        );
    } finally {
        for s in sockets {
            s.close();
        }
    }
}

"""Test _find_available_port raises OSError when all ports exhausted."""
test "port fallback - raises error when no ports available" {
    # Block all ports within retry limit
    start_port = get_free_port();
    sockets: list[socket.socket] = [];

    try {
        for i in range(PORT_RETRY_LIMIT) {
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
            try {
                s.bind(('0.0.0.0', start_port + i));
                s.listen(1);
                sockets.append(s);
            } except OSError {
                s.close();
            }
        }

        # Only test if we successfully blocked all ports
        if len(sockets) == PORT_RETRY_LIMIT {
            error_raised = False;
            try {
                _find_available_port(start_port);
            } except OSError as e {
                error_raised = True;
                assert "Could not find an available port" in str(e);
            }
            assert error_raised , "Expected OSError when all ports exhausted";
        }
    } finally {
        for s in sockets {
            s.close();
        }
    }
}

"""Test _get_network_ips returns list of valid IPs."""
test "network IPs - returns valid IP list" {
    ips = _get_network_ips();
    assert isinstance(ips, list) , "Expected list of IPs";

    # All IPs should be non-localhost and non-IPv6
    for ip in ips {
        assert not ip.startswith('127.') , f"Localhost IP {ip} should be filtered";
        assert ':' not in ip , f"IPv6 address {ip} should be filtered";
    }

    # No duplicates
    assert len(ips) == len(set(ips)) , "IP list should not contain duplicates";
}

"""Test constants are defined correctly."""
test "port constants - values are correct" {
    assert PORT_RETRY_LIMIT == 10 , "PORT_RETRY_LIMIT should be 10";
    assert ERRNO_ADDR_IN_USE_LINUX == 98 , "ERRNO_ADDR_IN_USE_LINUX should be 98";
    assert ERRNO_ADDR_IN_USE_WINDOWS == 10048 , "ERRNO_ADDR_IN_USE_WINDOWS should be 10048";
}

"""Test server startup with port fallback via subprocess."""
test "server startup - port fallback integration" {
    # Start a server on a specific port
    port1 = get_free_port();
    sp1: subprocess.Popen | None = None;
    sp2: subprocess.Popen | None = None;

    try {
        # Start first server
        sp1 = _start_server(
            sv_fixtures_dir, sv_test_file, port1, f"http://localhost:{port1}"
        );

        # Verify first server is running
        response = requests.get(f"http://localhost:{port1}/docs", timeout=5);
        assert response.status_code == 200 , "First server should be running";

        # Try to start second server on same port - should fallback to next port
        jac_executable = Path(sys.executable).parent / "jac";
        cmd = [str(jac_executable), "start", sv_test_file.name, "--port", str(port1)];

        sp2 = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=str(sv_fixtures_dir)
        );

        # Wait for server to start and detect port fallback
        actual_port = port1;
        max_wait = 60;
        start_time = time.time();

        while time.time() - start_time < max_wait {
            # Check stdout for port fallback message
            if sp2.stdout and select.select([sp2.stdout], [], [], 0.5)[0] {
                line = sp2.stdout.readline();
                if line and "using port" in line {
                    port_match = re.search(r'using port (\d+)', line);
                    if port_match {
                        actual_port = int(port_match.group(1));
                    }
                }
            }

            # Check if server is responding on fallback ports
            for test_port in range(port1 + 1, port1 + 5) {
                try {
                    resp = requests.get(f"http://localhost:{test_port}/docs", timeout=1);
                    if resp.status_code == 200 {
                        actual_port = test_port;
                        break;
                    }
                } except Exception {
                # Connection not ready yet
                }
            }
            if actual_port > port1 {
                break;
            }
        }

        # Verify the fallback happened
        assert actual_port > port1 , f"Second server should use port > {port1}, got {actual_port}";
    } finally {
        if sp2 {
            sp2.terminate();
            try {
                sp2.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                sp2.kill();
            }
        }
        if sp1 {
            _stop_server(sp1);
        }
        _cleanup_db_files(sv_fixtures_dir);
    }
}

"""Test that jac start --client pwa uses jac-scale server (has /docs endpoint)."""
test "pwa target uses jac-scale server" {
    import tempfile;

    port = get_free_port();
    jac_executable = Path(sys.executable).parent / "jac";

    with tempfile.TemporaryDirectory() as temp_dir {
        temp_path = Path(temp_dir);

        # Create minimal jac app
        main_jac = temp_path / "main.jac";
        main_jac.write_text('cl { def:pub app -> JsxElement { return <div>Test</div>; } }');

        jac_toml = temp_path / "jac.toml";
        jac_toml.write_text('''[project]
name = "test-pwa"
version = "1.0.0"

[plugins.client.pwa]
theme_color = "#000000"
''');

        # Start server with --client pwa
        server = subprocess.Popen(
            [str(jac_executable), "start", "--client", "pwa", "main.jac", "-p", str(port)],
            cwd=temp_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );

        try {
            # Wait for server to start and verify /docs endpoint (jac-scale's FastAPI)
            for _ in range(30) {
                try {
                    resp = requests.get(f"http://127.0.0.1:{port}/docs", timeout=2);
                    if resp.status_code == 200 {
                        # /docs exists = jac-scale's FastAPI server is running
                        assert "swagger" in resp.text.lower() or "openapi" in resp.text.lower(), (
                            "/docs should be FastAPI Swagger UI"
                        );
                        return;  # Test passed
                    }
                } except (requests.ConnectionError, requests.Timeout) {
                    time.sleep(1);
                }
            }
            # Capture output for debugging
            server.terminate();
            (stdout, stderr) = server.communicate(timeout=5);
            raise AssertionError(
                f"Server did not start or /docs not available.\nSTDOUT: {stdout}\nSTDERR: {stderr}"
            );
        } finally {
            server.terminate();
            try {
                server.wait(timeout=5);
            } except subprocess.TimeoutExpired {
                server.kill();
            }
        }
    }
}
