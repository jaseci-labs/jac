import asyncio;
import contextlib;
import glob;
import json;
import socket;
import subprocess;
import from jaclang.scale.runtime.context.util { jac_executable }
import time;
import uuid;
import shutil;
import requests;
import from jaclang.server.serving.authcrypt {
    jwt_decode as _jwt_decode,
    jwt_encode as _jwt_encode
}
import from jaclang.server.identity.config { signing_secret as jwt_secret }
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }
import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}
import from jaclang.scale.tests.support {
    cleanup_db_files,
    get_free_port,
    start_server,
    stop_server
}

def _as_any(v: any) -> any {
    return v;
}

def register_payload(username: str, password: str) -> dict[str, any] {
    return {
        "identities": [{"type": "username", "value": username}],
        "credential": {"type": "password", "password": password}
    };
}

def login_payload(username: str, password: str) -> dict[str, any] {
    return {
        "identity": {"type": "username", "value": username},
        "credential": {"type": "password", "password": password}
    };
}

def do_register(client: any, username: str, password: str) -> dict[str, any] {
    response = client.post("/user/register", json=register_payload(username, password));
    return extract_data(response.json());
}

def do_login(client: any, username: str, password: str) -> dict[str, any] {
    response = client.post("/user/login", json=login_payload(username, password));
    return extract_data(response.json());
}

def register_and_get_token(client: any, username: str, password: str) -> str {
    do_register(client, username, password);
    result = do_login(client, username, password);
    return result["token"];
}

def _create_expired_token(username: str, days_ago: int = 1) -> str {
    secret = jwt_secret();
    algorithm = "HS256";

    past_time = datetime.now(UTC) - timedelta(days=days_ago);
    payload = {
        "username": username,
        "exp": past_time + timedelta(hours=1),
        "iat": past_time
    };
    return _jwt_encode(payload, secret, algorithm=algorithm);
}

def _create_very_old_token(username: str, days_ago: int = 15) -> str {
    secret = jwt_secret();
    algorithm = "HS256";

    past_time = datetime.now(UTC) - timedelta(days=days_ago);
    payload = {
        "username": username,
        "exp": past_time + timedelta(hours=1),
        "iat": past_time
    };
    return _jwt_encode(payload, secret, algorithm=algorithm);
}

glob sv_fixtures_dir: Path = Path(__file__).parent.parent / "fixtures",
     sv_test_file: Path = sv_fixtures_dir / "test_api.jac",
     sv_port: int = get_free_port(),
     sv_base_url: str = f"http://localhost:{sv_port}",
     sv_ws_url: str = f"ws://localhost:{sv_port}";

def setup_serve_server -> subprocess.Popen {
    if not sv_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {sv_test_file}");
    }
    cleanup_db_files(sv_fixtures_dir);
    return start_server(sv_fixtures_dir, sv_test_file, sv_port);
}

def teardown_serve_server(sp: subprocess.Popen | None) {
    stop_server(sp);
    cleanup_db_files(sv_fixtures_dir);
}

test "static and schema endpoints" {
    client = make_client();
    try {
        response = client.get("/healthz");
        assert response.status_code == 200 , "Health check should return 200";
        assert response.json() == {"status": "ok"};

        response = client.get("/docs");
        assert response.status_code == 200 , "Docs should be enabled by default";

        response = client.get("/graph");
        assert response.status_code == 200;
        assert "x-custom-test-header" in response.headers;
        assert response.headers["x-custom-test-header"] == "test-value";
        assert "cross-origin-opener-policy" in response.headers;
        assert response.headers["cross-origin-opener-policy"] == "same-origin";
        assert "cross-origin-embedder-policy" in response.headers;
        assert response.headers["cross-origin-embedder-policy"] == "require-corp";

        srv = client._server;
        assert srv is not None , "server must be running";
        openapi_spec = srv.app.openapi();
        paths = openapi_spec.get("paths", {});

        assert "/user/refresh-token" in paths;
        refresh_endpoint = paths["/user/refresh-token"];
        assert "post" in refresh_endpoint;
        post_spec = refresh_endpoint["post"];
        assert post_spec["summary"] == "Refresh JWT token";
        assert "User APIs" in post_spec["tags"];

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

        response = client.get("/cl/nonexistent_page_xyz");
        assert response.status_code == 404;
        assert "404" in response.text;

        response = client.get("/static/nonexistent_file.css");
        assert response.status_code == 404;
        assert "not found" in response.text.lower();

        response = client.get("/nonexistent_image.png");
        assert response.status_code == 404;

        response = client.get("/malware.exe");
        assert response.status_code == 404;
        response = client.get("/script.php");
        assert response.status_code == 404;

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

        response = client.get("/static/client.js");
        assert response.status_code in [200, 503, 500];
        if response.status_code == 200 {
            assert "application/javascript" in response.headers.get("content-type", "");
        }

        response = client.get("/graph");
        assert response.status_code == 200;
        assert "text/html" in response.headers["content-type"];
    } finally {
        client.close();
    }
}

test "user registration and login" {
    client = make_client();
    try {
        test_username = f"testuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(test_username, "testpass123")
        );
        result = extract_data(response.json());
        assert "user_id" in result;
        assert "message" in result;

        status_user = f"status_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(status_user, "password123")
        );
        assert response.status_code == 201;
        data = extract_data(response.json());
        assert "user_id" in data;

        response = client.post(
            "/user/register", json=register_payload(status_user, "password123")
        );
        assert response.status_code == 400;

        login_username = f"login_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(login_username, "loginpass")
        );
        create_result = extract_data(response.json());
        response = client.post(
            "/user/login", json=login_payload(login_username, "loginpass")
        );
        login_result = extract_data(response.json());
        assert "token" in login_result;
        assert "user_id" in login_result;
        assert "root_id" in login_result;

        response = client.post(
            "/user/login", json=login_payload(login_username, "loginpass")
        );
        assert response.status_code == 200;

        fail_username = f"fail_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(fail_username, "correctpass")
        );
        response = client.post(
            "/user/login", json=login_payload(fail_username, "wrongpass")
        );
        login_result = extract_data(response.json());
        assert "error" in login_result;

        response = client.post(
            "/user/login", json=login_payload(fail_username, "wrongpass")
        );
        assert response.status_code == 401;
        data = extract_data(response.json());
        assert data["error"] == "Invalid credentials";

        response = client.post("/user/login", json={});
        assert response.status_code in (400, 422);

        response = client.post(
            "/user/login",
            json={"identity": {}, "credential": {"type": "password", "password": "x"}}
        );
        assert response.status_code in (400, 422);

        response = client.post("/user/login", json=login_payload("", "x"));
        assert response.status_code in (400, 422);

        response = client.post(
            "/user/login", json=login_payload("nonexistent", "password")
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

        uname = f"u_{suffix}";
        r = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": uname}],
                "credential": cred
            }
        );
        assert r.status_code == 201;
        r = client.post(
            "/user/login",
            json={"identity": {"type": "username", "value": uname}, "credential": cred}
        );
        assert r.status_code == 200;
        assert "token" in extract_data(r.json());

        email = f"e_{suffix}@example.com";
        r = client.post(
            "/user/register",
            json={"identities": [{"type": "email", "value": email}], "credential": cred}
        );
        assert r.status_code == 201;
        r = client.post(
            "/user/login",
            json={"identity": {"type": "email", "value": email}, "credential": cred}
        );
        assert r.status_code == 200;
        assert "token" in extract_data(r.json());

        both_u = f"both_{suffix}";
        both_e = f"both_{suffix}@example.com";
        r = client.post(
            "/user/register",
            json={
                "identities": [
                    {"type": "username", "value": both_u},
                    {"type": "email", "value": both_e}
                ],
                "credential": cred
            }
        );
        assert r.status_code == 201;
        r = client.post(
            "/user/login",
            json={"identity": {"type": "username", "value": both_u}, "credential": cred}
        );
        assert r.status_code == 200;
        r = client.post(
            "/user/login",
            json={"identity": {"type": "email", "value": both_e}, "credential": cred}
        );
        assert r.status_code == 200;

        for bad in ["notanemail", "bad@", "@bad.com", "a b@x.com", ""] {
            r = client.post(
                "/user/register",
                json={
                    "identities": [{"type": "email", "value": bad}],
                    "credential": cred
                }
            );
            assert r.status_code in (400, 422) , f"bad email '{bad}' accepted on register";
            r = client.post(
                "/user/login",
                json={"identity": {"type": "email", "value": bad}, "credential": cred}
            );
            assert r.status_code in (400, 422) , f"bad email '{bad}' accepted on login";
        }
    } finally {
        client.close();
    }
}

test "token refresh functionality" {
    client = make_client();
    try {
        response = client.post("/user/refresh-token", json={});
        refresh_result = extract_data(response.json());
        if "detail" in refresh_result {
            assert isinstance(refresh_result["detail"], list);
            error_entry = refresh_result["detail"][0];
            assert error_entry["loc"] == ["body", "token"];
            assert error_entry["type"] == "missing";
        } else {
            assert "error" in refresh_result;
            assert refresh_result["error"]
                in ["Token is required", "Invalid or expired token"];
        }

        response = client.post("/user/refresh-token", json={"token": ""});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Token is required";

        response = client.post("/user/refresh-token", json={"token": ""});
        assert response.status_code == 400;

        invalid_tokens = ["invalid.token.here", "not.a.jwt", "invalid_token_string"];
        for invalid_token in invalid_tokens {
            response = client.post(
                "/user/refresh-token", json={"token": invalid_token}
            );
            refresh_result = extract_data(response.json());
            assert "error" in refresh_result;
            assert refresh_result["error"] == "Invalid or expired token";
        }

        response = client.post(
            "/user/refresh-token", json={"token": "invalid_token_string"}
        );
        assert response.status_code == 401;

        refresh_bearer_user = f"refresh_bearer_{uuid.uuid4().hex[:8]}";
        original_token = register_and_get_token(
            client, refresh_bearer_user, "password123"
        );

        response = client.post(
            "/user/refresh-token", json={"token": f"Bearer {original_token}"}
        );
        refresh_result = extract_data(response.json());
        assert "token" in refresh_result;
        assert "message" in refresh_result;
        assert refresh_result["message"] == "Token refreshed successfully";

        response = client.post("/user/refresh-token", json={"token": original_token});
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "token" in data;
        assert data["message"] == "Token refreshed successfully";

        old_user = f"refresh_old_{uuid.uuid4().hex[:8]}";
        do_register(client, old_user, "password123");
        very_old_token = _create_very_old_token(old_user, days_ago=15);
        response = client.post("/user/refresh-token", json={"token": very_old_token});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";

        fake_token = _create_expired_token("nonexistent", days_ago=1);
        response = client.post("/user/refresh-token", json={"token": fake_token});
        refresh_result = extract_data(response.json());
        assert "error" in refresh_result;
        assert refresh_result["error"] == "Invalid or expired token";

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

        username = f"refresh_preserve_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "password123");

        response = client.post("/user/refresh-token", json={"token": token});
        refresh_result = extract_data(response.json());
        new_token = refresh_result["token"];

        secret = jwt_secret();
        algorithm = "HS256";

        original_payload = _jwt_decode(token, secret, algorithms=[algorithm]);
        new_payload = _jwt_decode(new_token, secret, algorithms=[algorithm]);

        assert original_payload["user_id"] == new_payload["user_id"];
        assert new_payload["sub"] == new_payload["user_id"];
        assert original_payload["sub"] == original_payload["user_id"];
        assert new_payload["preferred_username"] == username;

        user_id = original_payload["user_id"];
        legacy_payload = {
            "user_id": user_id,
            "exp": datetime.now(UTC) + timedelta(days=1),
            "iat": datetime.now(UTC)
        };
        legacy_token = _jwt_encode(legacy_payload, secret, algorithm=algorithm);
        response = client.post("/user/refresh-token", json={"token": legacy_token});
        assert response.status_code == 200;
        refreshed = extract_data(response.json())["token"];
        refreshed_payload = _jwt_decode(refreshed, secret, algorithms=[algorithm]);
        assert refreshed_payload["sub"] == user_id;

        api_key_payload = {
            "type": "api_key",
            "sub": user_id,
            "exp": datetime.now(UTC) + timedelta(days=1),
            "iat": datetime.now(UTC)
        };
        api_key_token = _jwt_encode(api_key_payload, secret, algorithm=algorithm);
        response = client.post("/user/refresh-token", json={"token": api_key_token});
        assert response.status_code == 401;
    } finally {
        client.close();
    }
}

test "integration auth flow" {
    client = make_client();
    try {
        username = f"integration_{uuid.uuid4().hex[:8]}";

        register_response = client.post(
            "/user/register", json=register_payload(username, "secure123")
        );
        assert register_response.status_code == 201;
        data = extract_data(register_response.json());
        assert "user_id" in data;

        login_response = client.post(
            "/user/login", json=login_payload(username, "secure123")
        );
        assert login_response.status_code == 200;
        data = extract_data(login_response.json());
        token1 = data["token"];

        login_response2 = client.post(
            "/user/login", json=login_payload(username, "secure123")
        );
        assert login_response2.status_code == 200;
        data = extract_data(login_response2.json());
        token2 = data["token"];

        refresh_response = client.post("/user/refresh-token", json={"token": token1});
        assert refresh_response.status_code == 200;
        data = extract_data(refresh_response.json());
        token3 = data["token"];

        fail_response = client.post(
            "/user/login", json=login_payload(username, "wrongpass")
        );
        assert fail_response.status_code == 401;

        assert token1 != token2;
        assert token2 != token3;
        assert token1 != token3;
    } finally {
        client.close();
    }
}

def _me_register_and_login(
    client: ScaleTestClient,
    username: str,
    password: str = "pw12345",
    profile: dict[str, any] | None = None
) -> tuple[str, str] {
    body: dict[str, any] = register_payload(username, password);
    if profile is not None {
        body["profile"] = profile;
    }
    register = client.post("/user/register", json=body);
    assert register.status_code == 201 , f"register failed: {register.json()}";
    user_id = extract_data(register.json())["user_id"];

    login = client.post("/user/login", json=login_payload(username, password));
    assert login.status_code == 200 , f"login failed: {login.json()}";
    return (user_id, extract_data(login.json())["token"]);
}

test "GET /user/me returns MeResponse shape without credentials" {
    client = make_client();
    try {
        profile = {"firstname": "Alice", "city": "NYC", "age": 30};
        username = f"me_get_{uuid.uuid4().hex[:8]}";
        (user_id, token) = _me_register_and_login(client, username, profile=profile);

        response = client.get("/user/me", headers={"Authorization": f"Bearer {token}"});
        assert response.status_code == 200;
        data = extract_data(response.json());

        assert data["user_id"] == user_id , f"user_id: {data}";
        assert data["role"] == "user" , f"role: {data}";
        assert data["status"] == "active" , f"status: {data}";
        assert data["profile"] == profile , f"profile: {data}";

        assert len(data["identities"]) == 1 , f"identities: {data['identities']}";
        ident = data["identities"][0];
        assert ident["type"] == "username" , f"identity: {ident}";
        assert ident["value"] == username , f"identity value: {ident}";
        assert isinstance(ident["verified"], bool) , f"verified: {ident}";
        assert ident["is_recovery"] is False , f"is_recovery: {ident}";

        assert "value_normalized" not in ident , f"leaked: {ident}";
        assert "external_id" not in ident , f"leaked: {ident}";

        for forbidden in ["credentials", "password", "password_hash"] {
            assert forbidden not in data , f"leaked {forbidden}: {data}";
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
        ).status_code
            == 401;
        assert client.raw_client.patch(
            "/user/me", json={"profile": {"firstname": "Alice"}}
        ).status_code
            == 401;
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
        assert data["profile"] == merged , f"merged: {data}";

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
        assert merged["sso"] == sso_seed["sso"] , f"sso lost: {merged}";
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

test "function calls" {
    client = make_client();
    try {
        func_user = f"funcuser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(func_user, "pass")
        );
        create_result = extract_data(response.json());
        assert "user_id" in create_result;
        response = client.post("/user/login", json=login_payload(func_user, "pass"));
        login_result = extract_data(response.json());
        token = login_result["token"];

        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 25},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == 35;

        response = client.post(
            "/function/greet",
            json={"name": "Alice"},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == "Hello, Alice!";

        response = client.post(
            "/function/greet",
            json={"args": {}},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == "Hello, World!";

        response = client.post(
            "/function/multiply",
            json={"x": 7, "y": 8},
            headers={"Authorization": f"Bearer {token}"}
        );
        result = extract_data(response.json());
        assert "result" in result;
        assert result["result"] == 56;

        response = client.post(
            "/function/add_numbers",
            json={"a": 10, "b": 20},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        data = extract_data(response.json());
        assert "result" in data;

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

test "function report streams (in-process)" {
    client = make_client();
    try {
        func_user = f"fnrep_{uuid.uuid4().hex[:8]}";
        client.register_user(func_user, "pass");
        token = client.login_user(func_user, "pass");

        response = client.post(
            "/function/FunctionStream",
            json={"count": 2},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        ct = response.headers.get("content-type");
        assert ct == "text/event-stream; charset=utf-8" , (
            f"function report was dropped: expected SSE, got {ct!r} / {response.text!r}"
        );
        content = response.text;
        for payload in ["Func 0", "Func 1"] {
            assert f'data: "{payload}"' in content , (
                f"Missing SSE-framed payload {payload!r} in: {content!r}"
            );
        }
        assert "event: end" in content , f"Missing SSE terminator in: {content!r}";
    } finally {
        client.close();
    }
}

test "walker calls" {
    client = make_client();
    try {
        walker_user = f"walkeruser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(walker_user, "pass")
        );
        create_result = extract_data(response.json());
        assert "user_id" in create_result;
        response = client.post("/user/login", json=login_payload(walker_user, "pass"));
        login_result = extract_data(response.json());
        token = login_result["token"];

        response = client.post(
            "/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;

        response = client.post(
            "/walker/NonExistentWalker",
            json={"fields": {}},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in [404, 405];

        response = client.post(
            "/walker/PrivateCreateTask", json={"title": "Private Task", "priority": 1}
        );
        assert response.status_code == 401;

        response = client.post("/walker/PublicInfo", json={});
        assert response.status_code == 200;
        response_data = extract_data(response.json());
        data = response_data["reports"][0];
        assert "message" in data;
        assert data["message"] == "This is a public endpoint";
        assert "auth_required" in data;
        assert data["auth_required"] is False;

        response = client.post(
            "/walker/PublicInfo", json={}, headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 200;
        response_data = extract_data(response.json());
        data = response_data["reports"][0];
        assert data["message"] == "This is a public endpoint";

        secret = jwt_secret();
        now = datetime.now(UTC);
        payload = {
            "username": "deleted_user",
            "exp": now + timedelta(days=1),
            "iat": now
        };
        fake_token = _jwt_encode(payload, secret, algorithm="HS256");

        response = client.post(
            "/walker/PrivateCreateTask",
            json={"title": "Ghost Task", "priority": 1},
            headers={"Authorization": f"Bearer {fake_token}"}
        );
        assert response.status_code == 401 , (
            f"Expected 401 for deleted/non-existent user, got {response.status_code}"
        );

        response = client.get("/graph/data");
        assert response.status_code == 200;
        data = response.json();
        assert "nodes" in data and "edges" in data;

        g_user = f"guser_{uuid.uuid4().hex[:8]}";
        response = client.post(
            "/user/register", json=register_payload(g_user, "gpass")
        );
        reg = extract_data(response.json());
        assert "user_id" in reg;
        response = client.post("/user/login", json=login_payload(g_user, "gpass"));
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

test "walker default-factory list field accepts empty body" {
    client = make_client();
    try {
        response = client.post("/walker/CollectWithDefault", json={});
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json())["reports"][0];
        assert data["tags"] == [];
        assert data["seen"] == {};

        response = client.post(
            "/walker/CollectWithDefault", json={"tags": ["a", "b", "a"]}
        );
        assert response.status_code == 200;
        data = extract_data(response.json())["reports"][0];
        assert data["tags"] == ["a", "b", "a"];
        assert data["seen"] == {"a": 2, "b": 1};

        spec = client.get("/openapi.json").json();
        body_schema = spec["paths"]["/walker/CollectWithDefault"]["post"]["requestBody"][
            "content"
        ]["application/json"]["schema"];

        if "$ref" in body_schema {
            ref = body_schema["$ref"].split("/")[-1];
            body_schema = spec["components"]["schemas"][ref];
        }
        tags_default = body_schema["properties"]["tags"].get("default");
        seen_default = body_schema["properties"]["seen"].get("default");
        assert tags_default == [] , f"Expected [] default, got {tags_default}";
        assert seen_default == {} , f"Expected {{}} default, got {seen_default}";
    } finally {
        client.close();
    }
}

test "user management operations" {
    client = make_client();
    try {
        username = f"passuser_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "oldpass123");

        response = client.put(
            "/user/password",
            json={"current_password": "oldpass123", "new_password": "newpass456"},
            headers={"Authorization": f"Bearer {token}"}
        );
        update_result = extract_data(response.json());
        assert "message" in update_result;

        login_result = do_login(client, username, "newpass456");
        assert "user_id" in login_result;

        response = client.post(
            "/user/login", json=login_payload(username, "oldpass123")
        );
        assert response.status_code == 401;

        username = f"noauthuser_{uuid.uuid4().hex[:8]}";
        do_register(client, username, "password123");
        response = client.put(
            "/user/password",
            json={"current_password": "password123", "new_password": "newpass"}
        );
        assert response.status_code == 401;

        username = f"wrongpass_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "correctpass");
        response = client.put(
            "/user/password",
            json={"current_password": "wrongpass", "new_password": "newpass"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code == 400;

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

        username = f"emptypass_{uuid.uuid4().hex[:8]}";
        token = register_and_get_token(client, username, "oldpass");
        response = client.put(
            "/user/password",
            json={"current_password": "oldpass", "new_password": ""},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in (400, 422);

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

        login_result = do_login(client, username, "newpass");
        assert login_result["root_id"] == root_id;

        response = client.post("/user/login", json=login_payload(username, "oldpass"));
        assert response.status_code == 401;
    } finally {
        client.close();
    }
}

test "websocket functionality" {
    import from jaclang.server.serving.client { aws_connect }
    sp = setup_serve_server();
    try {
        async def test_echo {
            async with await aws_connect(f"{sv_ws_url}/ws/EchoMessage") as ws {
                await ws.send_text(
                    json.dumps({"message": "hello", "client_id": "test-1"})
                );
                response = json.loads(await ws.receive_text());
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

        async def test_minimal {
            async with await aws_connect(f"{sv_ws_url}/ws/MinimalWebSocket") as ws {
                await ws.send_text(json.dumps({}));
                response = json.loads(await ws.receive_text());
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

        async def test_multiple {
            async with await aws_connect(f"{sv_ws_url}/ws/EchoMessage") as ws {
                for i in range(3) {
                    await ws.send_text(
                        json.dumps({"message": f"msg-{i}", "client_id": f"client-{i}"})
                    );
                    response = json.loads(await ws.receive_text());
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

        response = requests.post(
            f"{sv_base_url}/walker/EchoMessage",
            json={"message": "test", "client_id": "test"},
            timeout=10
        );
        assert response.status_code in (400, 404, 405) , (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        );

        async def _assert_ws_rejected(url: str, what: str) {
            connected = False;
            err: any = None;
            try {
                async with await aws_connect(url) as ws {
                    await ws.receive_text();
                    connected = True;
                }
            } except Exception as e {
                err = e;
            }
            assert not connected , (
                f"WS upgrade to {what} should have been rejected but connected "
                f"and received a frame"
            );
            resp = err?.response;
            status = resp?.status_code if resp is not None else err?.status_code;
            assert status is not None and status >= 400 , (
                f"WS upgrade to {what} must be rejected at the handshake with a 4xx; "
                f"got {type(err).__name__} (status={status}). An accepted-then-closed "
                f"connection or a timeout must not count as a rejection."
            );
        }
        asyncio.run(
            _assert_ws_rejected(
                f"{sv_ws_url}/ws/NonExistentWalker", "NonExistentWalker"
            )
        );
        asyncio.run(
            _assert_ws_rejected(
                f"{sv_ws_url}/ws/CreateTask", "the HTTP-only walker CreateTask"
            )
        );

        async def test_private_no_auth {
            async with await aws_connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send_text(json.dumps({"message": "hello"}));
                response = json.loads(await ws.receive_text());
                assert response["ok"] is False , f"Expected ok=False, got {response}";
                assert response["error"]["code"] == "UNAUTHORIZED";
                assert "token" in response["error"]["message"].lower();
            }
        }
        asyncio.run(test_private_no_auth());

        username = f"ws_test_user_{uuid.uuid4().hex[:8]}";
        password = "testpass123";

        response = requests.post(
            f"{sv_base_url}/user/register",
            json=register_payload(username, password),
            timeout=10
        );
        assert response.status_code in (200, 201) , f"Failed to create user: {response.text}";

        response = requests.post(
            f"{sv_base_url}/user/login",
            json=login_payload(username, password),
            timeout=10
        );
        assert response.status_code == 200 , f"Failed to login: {response.text}";
        token = response.json()["data"]["token"];

        async def test_private_with_token(t: str) {
            async with await aws_connect(f"{sv_ws_url}/ws/PrivateWebSocket") as ws {
                await ws.send_text(
                    json.dumps({"message": "authenticated hello", "token": t})
                );
                response = json.loads(await ws.receive_text());
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

        username = f"ws_query_user_{uuid.uuid4().hex[:8]}";
        response = requests.post(
            f"{sv_base_url}/user/register",
            json=register_payload(username, password),
            timeout=10
        );
        assert response.status_code in (200, 201);

        response = requests.post(
            f"{sv_base_url}/user/login",
            json=login_payload(username, password),
            timeout=10
        );
        assert response.status_code == 200;
        query_token = response.json()["data"]["token"];

        async def test_query_token(t: str) {
            async with await aws_connect(
                f"{sv_ws_url}/ws/PrivateWebSocket?token={t}"
            ) as ws {
                await ws.send_text(json.dumps({"message": "query auth hello"}));
                response = json.loads(await ws.receive_text());
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

        async def test_broadcast {
            async with await aws_connect(f"{sv_ws_url}/ws/BroadcastChat") as ws1 {
                async with await aws_connect(f"{sv_ws_url}/ws/BroadcastChat") as ws2 {
                    await asyncio.sleep(0.1);
                    await ws1.send_text(
                        json.dumps({"message": "hello everyone", "sender": "client1"})
                    );
                    response1 = json.loads(
                        await asyncio.wait_for(ws1.receive_text(), timeout=5)
                    );
                    response2 = json.loads(
                        await asyncio.wait_for(ws2.receive_text(), timeout=5)
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

        async def test_private_broadcast_no_auth {
            async with await aws_connect(
                f"{sv_ws_url}/ws/PrivateBroadcastChat"
            ) as ws {
                await ws.send_text(json.dumps({"message": "hello", "room": "general"}));
                response = json.loads(await ws.receive_text());
                assert response["ok"] is False;
                assert response["error"]["code"] == "UNAUTHORIZED";
            }
        }
        asyncio.run(test_private_broadcast_no_auth());

        users: list = [];
        for i in range(2) {
            username = f"broadcast_user_{i}_{uuid.uuid4().hex[:8]}";
            password = "testpass123";

            response = requests.post(
                f"{sv_base_url}/user/register",
                json=register_payload(username, password),
                timeout=10
            );
            assert response.status_code in (200, 201);

            response = requests.post(
                f"{sv_base_url}/user/login",
                json=login_payload(username, password),
                timeout=10
            );
            assert response.status_code == 200;
            users.append(
                {"username": username, "token": response.json()["data"]["token"]}
            );
        }

        async def test_private_broadcast_with_auth(u: list) {
            async with await aws_connect(
                f"{sv_ws_url}/ws/PrivateBroadcastChat?token={u[0]['token']}"
            ) as ws1 {
                async with await aws_connect(
                    f"{sv_ws_url}/ws/PrivateBroadcastChat?token={u[1]['token']}"
                ) as ws2 {
                    await asyncio.sleep(0.1);
                    await ws1.send_text(
                        json.dumps({"message": "secret broadcast", "room": "team"})
                    );
                    response1 = json.loads(
                        await asyncio.wait_for(ws1.receive_text(), timeout=5)
                    );
                    response2 = json.loads(
                        await asyncio.wait_for(ws2.receive_text(), timeout=5)
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

glob dm_fixtures_dir: Path = Path(__file__).parent.parent / "fixtures",
     dm_test_file: Path = dm_fixtures_dir / "test_api.jac",
     dm_api_port: int = get_free_port(),
     dm_base_url: str = f"http://localhost:{dm_api_port}";

def _extract_data_dev(json_response: dict[str, any]) -> dict[str, any] {
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

def setup_dev_mode_server -> subprocess.Popen {
    if not dm_test_file.exists() {
        raise FileNotFoundError(f"Test fixture not found: {dm_test_file}");
    }
    cleanup_db_files(dm_fixtures_dir);

    # Only --api_port is pinned: that is the one this suite talks to, and a
    # pinned port is now a contract that fails rather than relocating. The app
    # port is left unset so it may still relocate, which is what this harness
    # always relied on after reserving ports at import time.
    cmd = [
        jac_executable(),
        "run",
        "--serve",
        "--api-port",
        str(dm_api_port),
        "--dev",
        str(dm_test_file)
    ];

    server_process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    );

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
        );
    }

    return server_process;
}

def teardown_dev_mode_server(sp: subprocess.Popen | None) {
    stop_server(sp);
    cleanup_db_files(dm_fixtures_dir);
}

test "dev mode operations" {
    sp = setup_dev_mode_server();
    try {
        devtest_user = f"devtest_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json=register_payload(devtest_user, "pass"),
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json=login_payload(devtest_user, "pass"),
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

        devfunc_user = f"devfunc_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json=register_payload(devfunc_user, "pass"),
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json=login_payload(devfunc_user, "pass"),
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

        response = requests.post(
            f"{dm_base_url}/walker/PublicInfo", json={}, timeout=10
        );
        assert response.status_code == 200;
        data = _extract_data_dev(response.json());
        assert "reports" in data;
        assert data["reports"][0]["message"] == "This is a public endpoint";

        response = requests.post(
            f"{dm_base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=10
        );
        assert response.status_code == 401;

        username = f"asyncuser_{uuid.uuid4().hex[:8]}";
        register_response = requests.post(
            f"{dm_base_url}/user/register",
            json=register_payload(username, "password123"),
            timeout=10
        );
        assert register_response.status_code == 201;
        login_response = requests.post(
            f"{dm_base_url}/user/login",
            json=login_payload(username, "password123"),
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
                content += _as_any(chunk);
            }
        }

        for payload in ["Report 0", "Report 1", "Report 2"] {
            assert f'data: "{payload}"' in content , (
                f"Missing SSE-framed payload {payload!r} in: {content!r}"
            );
        }
        assert "event: end" in content , f"Missing SSE terminator in: {content!r}";

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
                content += _as_any(chunk);
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

test "dev mode named endpoints and HMR refresh" {
    greet_walker = '\nwalker:pub Greet {\n    has name: str = "World";\n\n    can greet with Root entry {\n        report {"message": "Hello, " + self.name + "!"};\n    }\n}\n';
    sp = setup_dev_mode_server();
    try {
        response = requests.get(f"{dm_base_url}/openapi.json", timeout=10);
        assert response.status_code == 200 , f"dev mode /openapi.json returned {response.status_code} before any HMR edit: {response.text[:300]!r}";
        paths = response.json().get("paths", {});

        assert "/walker/CreateTask" in paths , f"Expected /walker/CreateTask in OpenAPI paths, got: {list(
            paths.keys()
        )}";
        assert "/walker/ListTasks" in paths , f"Expected /walker/ListTasks in OpenAPI paths";
        assert "/walker/PublicInfo" in paths , f"Expected /walker/PublicInfo in OpenAPI paths";
        assert "/function/add_numbers" in paths , f"Expected /function/add_numbers in OpenAPI paths";

        assert "/walker/{walker_name}" not in paths , "Generic /walker/{walker_name} should not exist";
        assert "/function/{function_name}" not in paths , "Generic /function/{function_name} should not exist";

        with open(str(dm_test_file), 'a') as f {
            f.write(greet_walker);
        }

        time.sleep(3);

        requests.get(f"{dm_base_url}/healthz", timeout=10);
        time.sleep(1);

        response = requests.get(f"{dm_base_url}/openapi.json", timeout=10);
        assert response.status_code == 200 , f"dev mode /openapi.json returned {response.status_code} after the HMR edit: {response.text[:300]!r}";
        paths = response.json().get("paths", {});

        assert "/walker/Greet" in paths , f"Expected /walker/Greet after HMR, got: {list(
            paths.keys()
        )}";

        response = requests.post(
            f"{dm_base_url}/walker/Greet", json={"name": "Jaseci"}, timeout=10
        );
        assert response.status_code == 200 , f"POST /walker/Greet returned {response.status_code} after HMR picked the walker up: {response.text[:300]!r}";
        data = _extract_data_dev(response.json());
        assert data["reports"][0]["message"] == "Hello, Jaseci!";
    } finally {
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

import from jaclang.server.net {
    find_available_port as _find_available_port,
    PortInUseError,
    PORT_RETRY_LIMIT,
    ERRNO_ADDR_IN_USE
}
import from jaclang.cli.commands.execution { _find_free_port }

test "port fallback - available port returns same port" {
    free_port = get_free_port();
    result = _find_available_port(free_port);
    assert result == free_port , f"Expected {free_port}, got {result}";
}

test "port fallback - finds next available port when port in use" {
    blocked_port = get_free_port();
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(('0.0.0.0', blocked_port));
        s.listen(1);
        result = _find_available_port(blocked_port);
        assert result > blocked_port , f"Expected port > {blocked_port}, got {result}";
        assert result <= blocked_port + PORT_RETRY_LIMIT , (
            f"Result {result} exceeds retry limit from {blocked_port}"
        );
    }
}

test "port fallback - skips multiple blocked ports" {
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
                s.close();
            }
        }

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

def _assert_refuses(label: str, port: int, err: OSError | None) {
    assert err is not None , (
        f"{label}: a pinned port was relocated instead of failing, which is what "
        "silently strands a proxy pointed at it"
    );
    assert str(port) in str(err) , (
        f"{label}: the error must name the port that was asked for, got: {err}"
    );
}


test "an explicitly requested port is never relocated" {
    # Both selections a user's -p reaches: the API port, and in dev mode the
    # app port Vite serves. The second is the one the incident in #8387 moved.
    blocked = get_free_port();
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(('0.0.0.0', blocked));
        s.listen(1);
        api_err: OSError | None = None;
        try {
            _find_available_port(blocked, strict=True);
        } except OSError as e {
            api_err = e;
        }
        _assert_refuses("api port", blocked, api_err);
        app_err: OSError | None = None;
        try {
            _find_free_port(blocked, 0, True);
        } except OSError as e {
            app_err = e;
        }
        _assert_refuses("app port", blocked, app_err);
        collide_err: OSError | None = None;
        try {
            _find_free_port(blocked, blocked, True);
        } except OSError as e {
            collide_err = e;
        }
        _assert_refuses("app port equal to the api port", blocked, collide_err);
    }
}


test "a refused port reaches the CLI as a mapped error, not a traceback" {
    # The refusal crosses two paths that report failures differently: the plain
    # one catches it itself, the gateway one lets it reach the CLI executor.
    # Carrying a type rather than a message is what lets errmap render both the
    # same way, so an unmapped error's raw Python traceback stops being the
    # gateway's answer to a busy port.
    import from jaclang.cli.errmap { humanize_error }

    blocked = get_free_port();
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
        s.bind(('0.0.0.0', blocked));
        s.listen(1);
        err: OSError | None = None;
        try {
            _find_available_port(blocked, strict=True);
        } except OSError as e {
            err = e;
        }
        assert isinstance(err, PortInUseError) , (
            f"a strict refusal must raise PortInUseError, got {type(err).__name__}"
        );
        assert err.port == blocked , (
            f"the error must carry the port asked for, got {err.port}"
        );
        assert isinstance(err, OSError) , (
            "PortInUseError must stay an OSError so existing handlers still catch it"
        );
        mapped = humanize_error(err);
        assert mapped is not None , (
            "an unmapped error is what makes the CLI print a raw traceback"
        );
        assert str(blocked) in mapped[0] , (
            f"the mapped message must name the port: {mapped[0]!r}"
        );
        assert mapped[1] , "the mapped error should carry a hint";
    }
}


test "port fallback - raises error when no ports available" {
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

test "port constants - values are correct" {
    assert PORT_RETRY_LIMIT == 10 , "PORT_RETRY_LIMIT should be 10";
    assert 98 in ERRNO_ADDR_IN_USE , "Linux EADDRINUSE should be recognised";
    assert 48 in ERRNO_ADDR_IN_USE , "macOS EADDRINUSE should be recognised";
    assert 10048 in ERRNO_ADDR_IN_USE , "Windows WSAEADDRINUSE should be recognised";
}

test "server startup - a second server refuses an already-taken explicit port" {
    port1 = get_free_port();
    sp1: subprocess.Popen | None = None;
    sp2: subprocess.Popen | None = None;

    try {
        sp1 = start_server(sv_fixtures_dir, sv_test_file, port1);

        response = requests.get(f"http://localhost:{port1}/healthz", timeout=5);
        assert response.status_code == 200 , "First server should be running";

        cmd = [
            jac_executable(),
            "run",
            "--serve",
            "--port",
            str(port1),
            "--no-client",
            sv_test_file.name
        ];

        sp2 = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=str(sv_fixtures_dir)
        );

        (output, _unused) = sp2.communicate(timeout=120);

        assert sp2.returncode != 0 , (
            "a second server asked for a port the first one holds must exit "
            f"non-zero rather than relocating, got {sp2.returncode}"
        );
        assert str(port1) in output , (
            f"the failure must name the port that was asked for, got: {output[-300:]!r}"
        );
        survivor = requests.get(f"http://localhost:{port1}/healthz", timeout=5);
        assert survivor.status_code == 200 , "the first server must be undisturbed";
    } finally {
        if sp2 {
            sp2.terminate();
            try {
                sp2.`wait(timeout=5);
            } except subprocess.TimeoutExpired {
                sp2.kill();
            }
        }
        if sp1 {
            stop_server(sp1);
        }
        cleanup_db_files(sv_fixtures_dir);
    }
}

test "health check filter is off unless [serve.access_log] asks for it" {
    import logging;
    import from jaclang.server.serving.accesslog {
        HealthCheckFilter,
        access_logger,
        configure_access_logging
    }
    import from jaclang.server.settings { ServeSettings }

    settings = ServeSettings();
    assert not settings.access_log.suppress_health_checks , "suppress_health_checks should default to False";

    configure_access_logging(enabled=True, format='text', suppress_health_checks=False);
    handler = access_logger.handlers[0];
    assert not any(isinstance(f, HealthCheckFilter) for f in handler.filters) , "HealthCheckFilter should not be attached when suppress_health_checks is false";

    configure_access_logging(enabled=True, format='text', suppress_health_checks=True);
    handler = access_logger.handlers[0];
    assert any(isinstance(f, HealthCheckFilter) for f in handler.filters) , "HealthCheckFilter should be attached when suppress_health_checks is true";
    configure_access_logging(enabled=True, format='text', suppress_health_checks=False);
}

test "health check filter suppresses probe records and keeps the rest" {
    import logging;
    import from jaclang.server.serving.accesslog {
        ACCESS_LOGGER_NAME,
        AccessRecord,
        HealthCheckFilter
    }

    def make_record(path: str) -> logging.LogRecord {
        rec = logging.LogRecord(
            name=ACCESS_LOGGER_NAME,
            level=logging.INFO,
            pathname="",
            lineno=0,
            msg=path,
            args=(),
            exc_info=None
        );
        setattr(
            rec,
            'access',
            AccessRecord(client='127.0.0.1', method='GET', path=path, status=200)
        );
        return rec;
    }

    f = HealthCheckFilter();
    for path in ['/healthz', '/healthz/ready', '/healthz/live'] {
        assert not f.filter(make_record(path)) , f"Expected suppressed: {path}";
    }
    for path in [
        '/walker/MyWalker',
        '/user/login',
        '/graph',
        '/function/add_numbers',
        '/health/extra',
        '/docs',
        '/'
    ] {
        assert f.filter(make_record(path)) , f"Expected allowed: {path}";
    }
    plain = logging.LogRecord(
        name=ACCESS_LOGGER_NAME,
        level=logging.INFO,
        pathname="",
        lineno=0,
        msg="x",
        args=(),
        exc_info=None
    );
    assert f.filter(plain) , "records without an access payload pass through";
}

test "json access log formatter emits one object per request" {
    import json;
    import logging;
    import from jaclang.server.serving.accesslog {
        ACCESS_LOGGER_NAME,
        AccessJsonFormatter,
        AccessRecord
    }
    rec = logging.LogRecord(
        name=ACCESS_LOGGER_NAME,
        level=logging.INFO,
        pathname="",
        lineno=0,
        msg="m",
        args=(),
        exc_info=None
    );
    setattr(
        rec,
        'access',
        AccessRecord(
            client='10.0.0.9',
            method='POST',
            path='/walker/Foo',
            status=201,
            bytes_sent=42,
            duration_ms=3.5,
            request_id='abc',
            ts=1700000000.25
        )
    );
    payload = json.loads(AccessJsonFormatter().format(rec));
    assert payload['method'] == 'POST';
    assert payload['path'] == '/walker/Foo';
    assert payload['status'] == 201;
    assert payload['bytes'] == 42;
    assert payload['request_id'] == 'abc';
    assert payload['ts'].endswith('Z');
}

test "pwa project uses jac-scale server" {
    import tempfile;

    port = get_free_port();

    with tempfile.TemporaryDirectory() as temp_dir {
        temp_path = Path(temp_dir);
        main_jac = temp_path / "main.jac";
        main_jac.write_text('def:pub app -> JsxElement { return <div>Test</div>; }');
        jac_toml = temp_path / "jac.toml";
        jac_toml.write_text(
            '''[project]
name = "test-pwa"
version = "1.0.0"

[client.pwa]
theme_color = "#000000"
'''
        );
        # A [client.pwa] table is what makes this a PWA; there is no
        # separate PWA client target or --client flag.
        server = subprocess.Popen(
            [jac_executable(), "run", "--serve", "-p", str(port), "main.jac"],
            cwd=temp_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        );
        try {
            for _ in range(30) {
                try {
                    resp = requests.post(
                        f"http://127.0.0.1:{port}/user/login", json={}, timeout=2
                    );
                    if resp.status_code in [400, 422] {
                        return;
                    }
                } except (requests.ConnectionError, requests.Timeout) {
                    time.sleep(1);
                }
            }

            server.terminate();
            (stdout, stderr) = server.communicate(timeout=5);
            raise AssertionError(
                f"Server did not start or jac-scale not detected.\nSTDOUT: {stdout}\nSTDERR: {stderr}"
            );
        } finally {
            server.terminate();
            try {
                server.`wait(timeout=5);
            } except subprocess.TimeoutExpired {
                server.kill();
            }
        }
    }
}

test "jwt middleware: per-user isolation and token rejection" {
    client = make_client();
    try {
        def reg(name: str) -> str {
            r = client.post("/user/register", json=register_payload(name, "Pass!99"));
            assert r.status_code == 201;
            login = client.post("/user/login", json=login_payload(name, "Pass!99"));
            assert login.status_code == 200;
            return extract_data(login.json())["token"];
        }
        def task_titles(tok: str) -> set[str] {
            r = client.post(
                "/walker/ListTasks", json={}, headers={"Authorization": f"Bearer {tok}"}
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

        forged = _jwt_encode(
            {"username": "x", "exp": datetime.now(UTC) + timedelta(hours=1)},
            "wrong_key",
            algorithm="HS256"
        );
        bad_token_cases = [
            ({"Authorization": f"Bearer {forged}"}, "forged secret"),
            ({"Authorization": f"Bearer {_create_expired_token('x')}"}, "expired"),
            ({"Authorization": "Bearer not.a.jwt"}, "malformed"),

        ];

        for (hdrs, label) in bad_token_cases {
            r = client.post("/walker/CreateTask", json={"title": "x"}, headers=hdrs);
            assert r.status_code == 401 , f"{label} on auth endpoint: expected 401, got {r.status_code}";
        }

        r = client.post("/walker/CreateTask", json={"title": "x"});
        assert r.status_code == 401 , f"no token on auth endpoint: expected 401, got {r.status_code}";

        for (hdrs, label) in bad_token_cases {
            r = client.post("/walker/PublicInfo", json={}, headers=hdrs);
            assert r.status_code == 200 , f"{label} on pub walker: expected 200 (guest), got {r.status_code}";
        }

        assert client.post("/walker/PublicInfo", json={}).status_code == 200 , "pub walker broken for anonymous requests";

        for (hdrs, label) in bad_token_cases {
            r = client.post("/function/public_status", json={}, headers=hdrs);
            assert r.status_code == 200 , f"{label} on pub function: expected 200 (guest), got {r.status_code}";
        }
        assert client.post("/function/public_status", json={}).status_code == 200 , "pub function broken for anonymous requests";
    } finally {
        client.close();
    }
}
