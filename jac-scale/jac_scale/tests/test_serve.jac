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

"""Build identity-based register payload."""
def register_payload(username: str, password: str) -> dict[str, Any] {
    return {
        "identities": [{"type": "username", "value": username}],
        "credential": {"type": "password", "password": password}
    };
}

"""Build identity-based login payload."""
def login_payload(username: str, password: str) -> dict[str, Any] {
    return {
        "identity": {"type": "username", "value": username},
        "credential": {"type": "password", "password": password}
    };
}

"""Register a user via the test client, return the response data."""
def do_register(client: Any, username: str, password: str) -> dict[str, Any] {
    response = client.post("/user/register", json=register_payload(username, password));
    return extract_data(response.json());
}

"""Login a user via the test client, return the response data (includes token)."""
def do_login(client: Any, username: str, password: str) -> dict[str, Any] {
    response = client.post("/user/login", json=login_payload(username, password));
    return extract_data(response.json());
}

"""Register + login, return token."""
def register_and_get_token(client: Any, username: str, password: str) -> str {
    do_register(client, username, password);
    result = do_login(client, username, password);
    return result["token"];
}

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
def _cleanup_db_files(fixtures_dir: Path) {
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
            response = requests.get(f"{base_url}/healthz", timeout=2);
            if response.status_code == 200 {
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
def _stop_server(server_process: subprocess.Popen | None) {
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
def teardown_serve_server(sp: subprocess.Popen | None) {
    _stop_server(sp);
    _cleanup_db_files(sv_fixtures_dir);
}

# =============================================================================
# GROUP 1: STATIC & SCHEMA TESTS (Read-only, no state changes)
# =============================================================================
test "static and schema endpoints" {
    client = make_client();
    try {
        # Test: health check endpoint
        response = client.get("/healthz");
        assert response.status_code == 200 , "Health check should return 200";
        assert response.json() == {"status": "ok"};

        # Test: docs are enabled by default (docs_enabled config defaults to true)
        response = client.get("/docs");
        assert response.status_code == 200 , "Docs should be enabled by default";

        # Test: custom response headers from config (use /graph which is always available)
        response = client.get("/graph");
        assert response.status_code == 200;
        assert "x-custom-test-header" in response.headers;
        assert response.headers["x-custom-test-header"] == "test-value";
        assert "cross-origin-opener-policy" in response.headers;
        assert response.headers["cross-origin-opener-policy"] == "same-origin";
        assert "cross-origin-embedder-policy" in response.headers;
        assert response.headers["cross-origin-embedder-policy"] == "require-corp";

        # Test: OpenAPI schema via app.openapi()
        openapi_spec = client._server.server.app.openapi();
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
# GROUP 2: USER AUTH & PROFILE (Register, Login, Token Refresh, /user/me)
# =============================================================================
test "user registration and login" {
    client = make_client();
    try {
        # Test: user creation (identity-based)
        test_username = f"testuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": test_username}],
                "credential": {"type": "password", "password": "testpass123"}
            }
        );
        result = extract_data(response.json());
        assert "user_id" in result;
        assert "message" in result;

        # Test: status code 201 for successful registration
        status_user = f"status_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": status_user}],
                "credential": {"type": "password", "password": "password123"}
            }
        );
        assert response.status_code == 201;
        data = extract_data(response.json());
        assert "user_id" in data;

        # Test: status code 400 for duplicate registration
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": status_user}],
                "credential": {"type": "password", "password": "password123"}
            }
        );
        assert response.status_code == 400;

        # Test: user login (identity-based)
        login_username = f"login_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": login_username}],
                "credential": {"type": "password", "password": "loginpass"}
            }
        );
        create_result = extract_data(response.json());
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": login_username},
                "credential": {"type": "password", "password": "loginpass"}
            }
        );
        login_result = extract_data(response.json());
        assert "token" in login_result;
        assert "user_id" in login_result;
        assert "root_id" in login_result;

        # Test: status code 200 for successful login
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": login_username},
                "credential": {"type": "password", "password": "loginpass"}
            }
        );
        assert response.status_code == 200;

        # Test: user login wrong password
        fail_username = f"fail_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": fail_username}],
                "credential": {"type": "password", "password": "correctpass"}
            }
        );
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": fail_username},
                "credential": {"type": "password", "password": "wrongpass"}
            }
        );
        login_result = extract_data(response.json());
        assert "error" in login_result;

        # Test: status code 401 for invalid credentials
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": fail_username},
                "credential": {"type": "password", "password": "wrongpass"}
            }
        );
        assert response.status_code == 401;
        data = extract_data(response.json());
        assert data["error"] == "Invalid credentials";

        # Test: validation error for missing/invalid structure (422 from FastAPI Pydantic validation)
        response = client.post("/user/login", json={});
        assert response.status_code in (400, 422);

        response = client.post(
            "/user/login",
            json={"identity": {}, "credential": {"type": "password", "password": "x"}}
        );
        assert response.status_code in (400, 422);

        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": ""},
                "credential": {"type": "password", "password": "x"}
            }
        );
        assert response.status_code in (400, 422);

        # Test: nonexistent user returns 401
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "nonexistent"},
                "credential": {"type": "password", "password": "password"}
            }
        );
        assert response.status_code == 401;
    } finally {
        client.close();
    }
}

test "email identity register and login" {
    client = make_client();
    try {
        suffix = uuid.uuid4().hex[:8];
        cred = {"type": "password", "password": "pw"};

        # Username-only identity
        uname = f"u_{suffix}";
        r = client.post("/user/register", json={
            "identities": [{"type": "username", "value": uname}],
            "credential": cred
        });
        assert r.status_code == 201;
        r = client.post("/user/login", json={
            "identity": {"type": "username", "value": uname},
            "credential": cred
        });
        assert r.status_code == 200;
        assert "token" in extract_data(r.json());

        # Email-only identity
        email = f"e_{suffix}@example.com";
        r = client.post("/user/register", json={
            "identities": [{"type": "email", "value": email}],
            "credential": cred
        });
        assert r.status_code == 201;
        r = client.post("/user/login", json={
            "identity": {"type": "email", "value": email},
            "credential": cred
        });
        assert r.status_code == 200;
        assert "token" in extract_data(r.json());

        # Both username + email: login works via either identity
        both_u = f"both_{suffix}";
        both_e = f"both_{suffix}@example.com";
        r = client.post("/user/register", json={
            "identities": [
                {"type": "username", "value": both_u},
                {"type": "email", "value": both_e}
            ],
            "credential": cred
        });
        assert r.status_code == 201;
        r = client.post("/user/login", json={
            "identity": {"type": "username", "value": both_u},
            "credential": cred
        });
        assert r.status_code == 200;
        r = client.post("/user/login", json={
            "identity": {"type": "email", "value": both_e},
            "credential": cred
        });
        assert r.status_code == 200;

        # Invalid email strings are rejected by validation
        for bad in ["notanemail", "bad@", "@bad.com", "a b@x.com", ""] {
            r = client.post("/user/register", json={
                "identities": [{"type": "email", "value": bad}],
                "credential": cred
            });
            assert r.status_code in (400, 422) , f"bad email '{bad}' accepted on register";
            r = client.post("/user/login", json={
                "identity": {"type": "email", "value": bad},
                "credential": cred
            });
            assert r.status_code in (400, 422) , f"bad email '{bad}' accepted on login";
        }
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
        refresh_bearer_user = f"refresh_bearer_{uuid.uuid4().hex[:8]}";
        original_token = register_and_get_token(client, refresh_bearer_user, "password123");

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
        do_register(client, old_user, "password123");
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
        refresh_multi_user = f"refresh_multi_{uuid.uuid4().hex[:8]}";
        token1 = register_and_get_token(client, refresh_multi_user, "password123");

        response = client.post("/user/refresh-token", json={"token": token1});
        refresh_result1 = extract_data(response.json());
        token2 = refresh_result1["token"];
        assert token2 != token1;

        response = client.post("/user/refresh-token", json={"token": token2});
        refresh_result2 = extract_data(response.json());
        token3 = refresh_result2["token"];
        assert token3 != token2;
        assert token3 != token1;

        # Test: refresh token preserves user_id
        username = f"refresh_preserve_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "password123");

        response = client.post("/user/refresh-token", json={"token": token});
        refresh_result = extract_data(response.json());
        new_token = refresh_result["token"];

        secret = "supersecretkey_for_testing_only!";
        algorithm = "HS256";

        original_payload = pyjwt.decode(token, secret, algorithms=[algorithm]);
        new_payload = pyjwt.decode(new_token, secret, algorithms=[algorithm]);

        assert original_payload["user_id"] == new_payload["user_id"];
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
            "/user/register",
            json={
                "identities": [{"type": "username", "value": username}],
                "credential": {"type": "password", "password": "secure123"}
            }
        );
        assert register_response.status_code == 201;
        data = extract_data(register_response.json());
        assert "user_id" in data;

        # Login (first time)
        login_response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": "secure123"}
            }
        );
        assert login_response.status_code == 200;
        data = extract_data(login_response.json());
        token1 = data["token"];

        # Login (second time)
        login_response2 = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": "secure123"}
            }
        );
        assert login_response2.status_code == 200;
        data = extract_data(login_response2.json());
        token2 = data["token"];

        # Refresh
        refresh_response = client.post("/user/refresh-token", json={"token": token1});
        assert refresh_response.status_code == 200;
        data = extract_data(refresh_response.json());
        token3 = data["token"];

        # Failed login
        fail_response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": "wrongpass"}
            }
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

"""Register a user (optionally with a profile) and return (user_id, token).
Used by the /user/me tests below."""
def _me_register_and_login(
    client: ScaleTestClient,
    username: str,
    password: str = "pw12345",
    profile: dict[str, Any] | None = None
) -> tuple[str, str] {
    body: dict[str, Any] = {
        "identities": [{"type": "username", "value": username}],
        "credential": {"type": "password", "password": password}
    };
    if profile is not None {
        body["profile"] = profile;
    }
    register = client.post("/user/register", json=body);
    assert register.status_code == 201, f"register failed: {register.json()}";
    user_id = extract_data(register.json())["user_id"];

    login = client.post(
        "/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        }
    );
    assert login.status_code == 200, f"login failed: {login.json()}";
    return (user_id, extract_data(login.json())["token"]);
}

test "GET /user/me returns MeResponse shape without credentials" {
    client = make_client();
    try {
        profile = {"firstname": "Alice", "city": "NYC", "age": 30};
        username = f"me_get_{uuid.uuid4().hex[:8]}";
        (user_id, token) = _me_register_and_login(
            client, username, profile=profile
        );

        response = client.get(
            "/user/me", headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());

        assert data["user_id"] == user_id, f"user_id: {data}";
        assert data["role"] == "user", f"role: {data}";
        assert data["status"] == "active", f"status: {data}";
        assert data["profile"] == profile, f"profile: {data}";

        assert len(data["identities"]) == 1, f"identities: {data['identities']}";
        ident = data["identities"][0];
        assert ident["type"] == "username", f"identity: {ident}";
        assert ident["value"] == username, f"identity value: {ident}";
        assert isinstance(ident["verified"], bool), f"verified: {ident}";
        assert ident["is_recovery"] is False, f"is_recovery: {ident}";
        # Internal storage fields must not leak.
        assert "value_normalized" not in ident, f"leaked: {ident}";
        assert "external_id" not in ident, f"leaked: {ident}";

        for forbidden in ["credentials", "password", "password_hash"] {
            assert forbidden not in data, f"leaked {forbidden}: {data}";
        }
    } finally {
        client.close();
    }
}

test "/user/me rejects missing or invalid token with 401" {
    client = make_client();
    try {
        assert client.get("/user/me").status_code == 401;
        assert client.get(
            "/user/me", headers={"Authorization": "Bearer not-a-real-token"}
        ).status_code == 401;
        assert client.raw_client.patch(
            "/user/me", json={"profile": {"firstname": "Alice"}}
        ).status_code == 401;
    } finally {
        client.close();
    }
}

test "PATCH /user/me merges new keys with existing profile" {
    client = make_client();
    try {
        username = f"me_merge_{uuid.uuid4().hex[:8]}";
        (_, token) = _me_register_and_login(
            client, username, profile={"firstname": "Alice", "city": "NYC"}
        );

        response = client.raw_client.patch(
            "/user/me",
            headers={"Authorization": f"Bearer {token}"},
            json={"profile": {"city": "Boston", "phone": "555-1234"}}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert data["message"] == "Profile updated";
        merged = {"firstname": "Alice", "city": "Boston", "phone": "555-1234"};
        assert data["profile"] == merged, f"merged: {data}";

        # Verify the merge persisted via GET /user/me.
        me = client.get("/user/me", headers={"Authorization": f"Bearer {token}"});
        assert extract_data(me.json())["profile"] == merged;
    } finally {
        client.close();
    }
}

test "PATCH /user/me preserves server-managed profile.sso" {
    client = make_client();
    try {
        username = f"me_sso_{uuid.uuid4().hex[:8]}";
        (user_id, token) = _me_register_and_login(
            client, username, profile={"firstname": "Alice"}
        );
        # Seed profile.sso via the internal helper (bypasses validator,
        # mimicking what the SSO callback does).
        sso_seed = {
            "sso": {
                "google": {
                    "display_name": "Alice G",
                    "first_name": "Alice",
                    "last_name": "G",
                    "picture": "https://example.invalid/p.png"
                }
            }
        };
        client.server.user_manager.update_profile(user_id, sso_seed);

        response = client.raw_client.patch(
            "/user/me",
            headers={"Authorization": f"Bearer {token}"},
            json={"profile": {"firstname": "Bob"}}
        );
        assert response.status_code == 200;
        merged = extract_data(response.json())["profile"];
        assert merged["firstname"] == "Bob";
        assert merged["sso"] == sso_seed["sso"], f"sso lost: {merged}";
    } finally {
        client.close();
    }
}

test "PATCH /user/me rejects reserved sso key and bad value type with 422" {
    client = make_client();
    try {
        username = f"me_422_{uuid.uuid4().hex[:8]}";
        (_, token) = _me_register_and_login(client, username);

        reserved = client.raw_client.patch(
            "/user/me",
            headers={"Authorization": f"Bearer {token}"},
            json={"profile": {"sso": {"google": {"display_name": "x"}}}}
        );
        assert reserved.status_code == 422;

        bad_value = client.raw_client.patch(
            "/user/me",
            headers={"Authorization": f"Bearer {token}"},
            json={"profile": {"tags": ["a", "b"]}}
        );
        assert bad_value.status_code == 422;
    } finally {
        client.close();
    }
}

test "POST /user/register applies AfterValidator to reject reserved sso key" {
    client = make_client();
    try {
        response = client.post(
            "/user/register",
            json={
                "identities": [
                    {"type": "username", "value": f"reg_{uuid.uuid4().hex[:8]}"}
                ],
                "credential": {"type": "password", "password": "pw12345"},
                "profile": {"sso": {"google": {"display_name": "x"}}}
            }
        );
        assert response.status_code == 422;
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
        func_user = f"funcuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": func_user}],
                "credential": {"type": "password", "password": "pass"}
            }
        );
        create_result = extract_data(response.json());
        assert "user_id" in create_result;
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": func_user},
                "credential": {"type": "password", "password": "pass"}
            }
        );
        login_result = extract_data(response.json());
        token = login_result["token"];

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
        walker_user = f"walkeruser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": walker_user}],
                "credential": {"type": "password", "password": "pass"}
            }
        );
        create_result = extract_data(response.json());
        assert "user_id" in create_result;
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": walker_user},
                "credential": {"type": "password", "password": "pass"}
            }
        );
        login_result = extract_data(response.json());
        token = login_result["token"];

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
        g_user = f"guser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": g_user}],
                "credential": {"type": "password", "password": "gpass"}
            }
        );
        reg = extract_data(response.json());
        assert "user_id" in reg;
        response = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": g_user},
                "credential": {"type": "password", "password": "gpass"}
            }
        );
        reg_login = extract_data(response.json());
        response = client.post(
            "/walker/CreateTask",
            json={"title": "T1", "priority": 1},
            headers={"Authorization": f"Bearer {reg_login['token']}"}
        );
        auth_resp = client.get(
            "/graph/data", headers={"Authorization": f"Bearer {reg_login['token']}"}
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
        # Test: update password success
        username = f"passuser_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "oldpass123");

        response = client.put(
            "/user/password",
            json={"current_password": "oldpass123", "new_password": "newpass456"},
            headers={"Authorization": f"Bearer {token}"}
        );
        update_result = extract_data(response.json());
        assert "message" in update_result;

        # Verify login with new password works
        login_result = do_login(client, username, "newpass456");
        assert "user_id" in login_result;

        # Verify login with old password fails
        response = client.post("/user/login", json=login_payload(username, "oldpass123"));
        assert response.status_code == 401;

        # Test: update password requires auth
        username = f"noauthuser_{uuid.uuid4().hex[:8]}";
        do_register(client, username, "password123");
        response = client.put(
            "/user/password",
            json={"current_password": "password123", "new_password": "newpass"}
        );
        assert response.status_code == 401;

        # Test: update password wrong current password
        username = f"wrongpass_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "correctpass");
        response = client.put(
            "/user/password",
            json={"current_password": "wrongpass", "new_password": "newpass"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;

        # Test: update password with other user's token (wrong current password returns 400)
        user1_name = f"passuser1_{uuid.uuid4().hex[:8]}";
        user1_token = register_and_get_token(client, user1_name, "pass1");
        user2_name = f"passuser2_{uuid.uuid4().hex[:8]}";
        do_register(client, user2_name, "pass2");
        response = client.put(
            "/user/password",
            json={"current_password": "pass2", "new_password": "hacked"},
            headers={"Authorization": f"Bearer {user1_token}"}
        );
        assert response.status_code == 400;

        # Test: update password empty validation (Pydantic rejects empty strings)
        username = f"emptypass_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "oldpass");
        response = client.put(
            "/user/password",
            json={"current_password": "oldpass", "new_password": ""},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in (400, 422);

        # Test: password update then login with new password
        username = f"combined_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "oldpass");
        login_result = do_login(client, username, "oldpass");
        root_id = login_result["root_id"];

        response = client.put(
            "/user/password",
            json={"current_password": "oldpass", "new_password": "newpass"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert "message" in extract_data(response.json());

        # New password works, old fails
        login_result = do_login(client, username, "newpass");
        assert login_result["root_id"] == root_id;

        response = client.post("/user/login", json=login_payload(username, "oldpass"));
        assert response.status_code == 401;
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
        async def test_echo {
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
        async def test_minimal {
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
        async def test_multiple {
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
        async def test_nonexistent {
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
        async def test_http_via_ws {
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
        async def test_private_no_auth {
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
            json={
                "identities": [{"type": "username", "value": username}],
                "credential": {"type": "password", "password": password}
            },
            timeout=10
        );
        assert response.status_code in (200, 201) , f"Failed to create user: {response.text}";

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": password}
            },
            timeout=10
        );
        assert response.status_code == 200 , f"Failed to login: {response.text}";
        token = response.json()["data"]["token"];

        async def test_private_with_token(t: str) {
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
            json={
                "identities": [{"type": "username", "value": username}],
                "credential": {"type": "password", "password": password}
            },
            timeout=10
        );
        assert response.status_code in (200, 201);

        response = requests.post(
            f"{sv_base_url}/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": password}
            },
            timeout=10
        );
        assert response.status_code == 200;
        query_token = response.json()["data"]["token"];

        async def test_query_token(t: str) {
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
        async def test_broadcast {
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
        async def test_private_broadcast_no_auth {
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
                json={
                    "identities": [{"type": "username", "value": username}],
                    "credential": {"type": "password", "password": password}
                },
                timeout=10
            );
            assert response.status_code in (200, 201);

            response = requests.post(
                f"{sv_base_url}/user/login",
                json={
                    "identity": {"type": "username", "value": username},
                    "credential": {"type": "password", "password": password}
                },
                timeout=10
            );
            assert response.status_code == 200;
            users.append(
                {"username": username, "token": response.json()["data"]["token"]}
            );
        }

        async def test_private_broadcast_with_auth(u: list) {
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
     dm_api_port: int = get_free_port(),
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
        "--api_port",
        str(dm_api_port),
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
            response = requests.get(f"{dm_base_url}/healthz", timeout=2);
            if response.status_code == 200 {
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
def teardown_dev_mode_server(sp: subprocess.Popen | None) {
    _stop_server(sp);
    _cleanup_db_files(dm_fixtures_dir);
}

test "dev mode operations" {
    sp = setup_dev_mode_server();
    try {
        # Test: dev mode walker body parsing
        devtest_user = f"devtest_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json={
                "identities": [{"type": "username", "value": devtest_user}],
                "credential": {"type": "password", "password": "pass"}
            },
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json={
                "identity": {"type": "username", "value": devtest_user},
                "credential": {"type": "password", "password": "pass"}
            },
            timeout=10
        );
        token = _extract_data_dev(login_response.json())["token"];

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
        devfunc_user = f"devfunc_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json={
                "identities": [{"type": "username", "value": devfunc_user}],
                "credential": {"type": "password", "password": "pass"}
            },
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json={
                "identity": {"type": "username", "value": devfunc_user},
                "credential": {"type": "password", "password": "pass"}
            },
            timeout=10
        );
        token = _extract_data_dev(login_response.json())["token"];

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
            json={
                "identities": [{"type": "username", "value": username}],
                "credential": {"type": "password", "password": "password123"}
            },
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json={
                "identity": {"type": "username", "value": username},
                "credential": {"type": "password", "password": "password123"}
            },
            timeout=10
        );
        token = _extract_data_dev(login_response.json())["token"];

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

        for payload in ["Report 0", "Report 1", "Report 2"] {
            assert f'data: "{payload}"' in content , (
                f"Missing SSE-framed payload {payload!r} in: {content!r}"
            );
        }
        assert "event: end" in content , f"Missing SSE terminator in: {content!r}";

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

        for payload in ["Func 0", "Func 1"] {
            assert f'data: "{payload}"' in content , (
                f"Missing SSE-framed payload {payload!r} in: {content!r}"
            );
        }
        assert "event: end" in content , f"Missing SSE terminator in: {content!r}";
    } finally {
        teardown_dev_mode_server(sp);
    }
}

"""Test that dev mode shows named endpoints in OpenAPI spec and HMR adds new ones."""
test "dev mode named endpoints and HMR refresh" {
    sp = setup_dev_mode_server();
    try {
        # Test: OpenAPI spec shows named walker endpoints (not generic {walker_name})
        response = requests.get(f"{dm_base_url}/openapi.json", timeout=10);
        assert response.status_code == 200;
        paths = response.json().get("paths", {});

        # Named endpoints should exist (from test_api.jac fixture)
        assert "/walker/CreateTask" in paths , f"Expected /walker/CreateTask in OpenAPI paths, got: {list(
            paths.keys()
        )}";
        assert "/walker/ListTasks" in paths , f"Expected /walker/ListTasks in OpenAPI paths";
        assert "/walker/PublicInfo" in paths , f"Expected /walker/PublicInfo in OpenAPI paths";
        assert "/function/add_numbers" in paths , f"Expected /function/add_numbers in OpenAPI paths";

        # Generic catch-all should NOT exist
        assert "/walker/{walker_name}" not in paths , "Generic /walker/{walker_name} should not exist";
        assert "/function/{function_name}" not in paths , "Generic /function/{function_name} should not exist";

        # Test: HMR adds new walker to OpenAPI spec
        # Append a new walker to the fixture file
        greet_walker = '\nwalker:pub Greet {\n    has name: str = "World";\n\n    can greet with Root entry {\n        report {"message": "Hello, " + self.name + "!"};\n    }\n}\n';
        with open(str(dm_test_file), 'a') as f {
            f.write(greet_walker);
        }

        # Wait for HMR to detect the change, then trigger a request to flush it
        time.sleep(3);
        # Make a request to trigger the HMR middleware refresh
        requests.get(f"{dm_base_url}/healthz", timeout=10);
        time.sleep(1);

        # Fetch updated OpenAPI spec
        response = requests.get(f"{dm_base_url}/openapi.json", timeout=10);
        assert response.status_code == 200;
        paths = response.json().get("paths", {});

        assert "/walker/Greet" in paths , f"Expected /walker/Greet after HMR, got: {list(
            paths.keys()
        )}";

        # New walker should also be callable
        response = requests.post(
            f"{dm_base_url}/walker/Greet", json={"name": "Jaseci"}, timeout=10
        );
        assert response.status_code == 200;
        data = _extract_data_dev(response.json());
        assert data["reports"][0]["message"] == "Hello, Jaseci!";
    } finally {
        # Remove the appended walker from fixture file to not pollute other tests
        with open(str(dm_test_file), 'r') as f {
            original = f.read();
        }
        if greet_walker in original {
            with open(str(dm_test_file), 'w') as f {
                f.write(original.replace(greet_walker, ''));
            }
        }
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
        response = requests.get(f"http://localhost:{port1}/healthz", timeout=5);
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
                    resp = requests.get(
                        f"http://localhost:{test_port}/healthz", timeout=1
                    );
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

"""Test that jac start --client pwa uses jac-scale server (422 from /user/login = FastAPI validation)."""
test "pwa target uses jac-scale server" {
    import tempfile;

    port = get_free_port();
    jac_executable = Path(sys.executable).parent / "jac";

    with tempfile.TemporaryDirectory() as temp_dir {
        temp_path = Path(temp_dir);
        # Create minimal jac app
        main_jac = temp_path / "main.jac";
        main_jac.write_text(
            'cl { def:pub app -> JsxElement { return <div>Test</div>; } }'
        );
        jac_toml = temp_path / "jac.toml";
        jac_toml.write_text(
            '''[project]
name = "test-pwa"
version = "1.0.0"

[plugins.client.pwa]
theme_color = "#000000"
'''
        );
        # Start server with --client pwa
        server = subprocess.Popen(
            [
                str(jac_executable),
                "start",
                "--client",
                "pwa",
                "main.jac",
                "-p",
                str(port)
            ],
            cwd=temp_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );
        try {
            # Wait for server to start and verify jac-scale's FastAPI is running
            # POST /user/login with empty body returns 422 (FastAPI validation) — base HTTP server would 404
            for _ in range(30) {
                try {
                    resp = requests.post(
                        f"http://127.0.0.1:{port}/user/login", json={}, timeout=2
                    );
                    if resp.status_code in [400, 422] {
                        return;  # Test passed — jac-scale's FastAPI is running

                    }
                } except (requests.ConnectionError, requests.Timeout) {
                    time.sleep(1);
                }
            }
            # Capture output for debugging
            server.terminate();
            (stdout, stderr) = server.communicate(timeout=5);
            raise AssertionError(
                f"Server did not start or jac-scale not detected.\nSTDOUT: {stdout}\nSTDERR: {stderr}"
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

# =============================================================================
# GROUP 8: JWT MIDDLEWARE
# =============================================================================
test "jwt middleware: per-user isolation and token rejection" {
    client = make_client();
    try {
        def reg(name: str) -> str {
            r = client.post(
                "/user/register",
                json={
                    "identities": [{"type": "username", "value": name}],
                    "credential": {"type": "password", "password": "Pass!99"}
                }
            );
            assert r.status_code == 201;
            login = client.post(
                "/user/login",
                json={
                    "identity": {"type": "username", "value": name},
                    "credential": {"type": "password", "password": "Pass!99"}
                }
            );
            assert login.status_code == 200;
            return extract_data(login.json())["token"];
        }
        def task_titles(tok: str) -> set[str] {
            r = client.post(
                "/walker/ListTasks",
                json={},
                headers={"Authorization": f"Bearer {tok}"}
            );
            assert r.status_code == 200;
            raw = extract_data(r.json())["reports"][0];
            items = raw if isinstance(raw, list) else [raw];
            return {
                t.get("title") or t.get("context", {}).get("title")
                for t in items
                if isinstance(t, dict)
            };
        }

        tok_a = reg(f"alice_{uuid.uuid4().hex[:6]}");
        tok_b = reg(f"bob_{uuid.uuid4().hex[:6]}");

        for (tok, title) in [(tok_a, "task_alice"), (tok_b, "task_bob")] {
            r = client.post(
                "/walker/CreateTask",
                json={"title": title, "priority": 1},
                headers={"Authorization": f"Bearer {tok}"}
            );
            assert r.status_code == 200 , f"CreateTask failed for {title}: {r.text}";
        }

        assert task_titles(tok_a) == {"task_alice"} , f"Isolation failure: {task_titles(
            tok_a
        )}";
        assert task_titles(tok_b) == {"task_bob"} , f"Isolation failure: {task_titles(
            tok_b
        )}";

        forged = pyjwt.encode(
            {"username": "x", "exp": datetime.now(UTC) + timedelta(hours=1)},
            "wrong_key",
            algorithm="HS256"
        );
        bad_token_cases = [
            ({"Authorization": f"Bearer {forged}"}, "forged secret"),
            ({"Authorization": f"Bearer {_create_expired_token('x')}"}, "expired"),
            ({"Authorization": "Bearer not.a.jwt"}, "malformed"),

        ];

        # Bad tokens must be rejected on auth-required endpoints.
        for (hdrs, label) in bad_token_cases {
            r = client.post("/walker/CreateTask", json={"title": "x"}, headers=hdrs);
            assert r.status_code == 401 , f"{label} on auth endpoint: expected 401, got {r.status_code}";
        }

        # No token on auth-required endpoint must also be rejected.
        r = client.post("/walker/CreateTask", json={"title": "x"});
        assert r.status_code == 401 , f"no token on auth endpoint: expected 401, got {r.status_code}";

        # Bad tokens on public (pub) endpoints must be ignored — the request
        # should succeed as guest rather than returning 401.
        for (hdrs, label) in bad_token_cases {
            r = client.post("/walker/PublicInfo", json={}, headers=hdrs);
            assert r.status_code == 200 , f"{label} on pub walker: expected 200 (guest), got {r.status_code}";
        }
        # No token on a public endpoint must still work (anonymous access).
        assert client.post("/walker/PublicInfo", json={}).status_code == 200 , "pub walker broken for anonymous requests";

        # Same check for pub functions — bad tokens must be ignored.
        for (hdrs, label) in bad_token_cases {
            r = client.post("/function/public_status", json={}, headers=hdrs);
            assert r.status_code == 200 , f"{label} on pub function: expected 200 (guest), got {r.status_code}";
        }
        assert client.post("/function/public_status", json={}).status_code == 200 , "pub function broken for anonymous requests";
    } finally {
        client.close();
    }
}
