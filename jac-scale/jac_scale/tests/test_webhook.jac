"""Tests for webhook walkers - runs both without and with MongoDB."""

import contextlib;
import gc;
import glob;
import hashlib;
import hmac;
import json;
import os;
import socket;
import subprocess;
import sys;
import time;
import uuid;
import shutil;
import requests;
import from pathlib { Path }
import from typing { Any, cast }

import from testcontainers.mongodb { MongoDbContainer }

import from jac_scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
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

"""Generate HMAC-SHA256 signature for webhook payload."""
def _generate_webhook_signature(payload: bytes, secret: str) -> str {
    return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest();
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
    env: dict | None = None
) -> subprocess.Popen {
    jac_executable = Path(sys.executable).parent / "jac";

    cmd = [str(jac_executable), "start", test_file.name, "--port", str(port)];

    proc_env = os.environ.copy();
    if env {
        proc_env.update(env);
    }

    server_process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(fixtures_dir),
        env=proc_env
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
        );
    }

    return server_process;
}

"""Stop the server process."""
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
    time.sleep(0.5);
    gc.collect();
}

# Shared webhook test functions
"""Register a user and login via HTTP, return the JWT token."""
def _register_and_login(base_url: str, username: str, password: str) -> str {
    requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        },
        timeout=10
    );
    login_resp = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        },
        timeout=10
    );
    login_data = cast(
        dict[str, Any], _extract_transport_response_data(login_resp.json())
    );
    return login_data["token"];
}

"""Verify webhook endpoints are registered for walkers with webhook protocol."""
def run_webhook_endpoint_exists_test(base_url: str) {
    # Hit endpoints directly — non-404 means the route is registered
    resp = requests.post(f"{base_url}/webhook/PaymentReceived", json={}, timeout=5);
    assert resp.status_code != 404 , (
        "Expected /webhook/PaymentReceived to be registered"
    );
    resp = requests.post(f"{base_url}/webhook/MinimalWebhook", json={}, timeout=5);
    assert resp.status_code != 404 , (
        "Expected /webhook/MinimalWebhook to be registered"
    );
}

"""Verify normal walkers are NOT in /webhook/."""
def run_normal_walker_not_in_webhook_test(base_url: str) {
    # NormalPayment should be rejected by webhook endpoint
    # Static mode: 404, Dynamic mode: 400 or 405 depending on routing
    resp = requests.post(f"{base_url}/webhook/NormalPayment", json={}, timeout=5);
    assert resp.status_code != 200 , (
        "NormalPayment should NOT be a valid webhook endpoint"
    );
    # But it should be accessible via /walker/
    resp = requests.post(f"{base_url}/walker/NormalPayment", json={}, timeout=5);
    assert resp.status_code != 404 , (
        "NormalPayment should be accessible via /walker/ endpoint"
    );
}

"""Verify NormalPayment works via /walker/ endpoint."""
def run_normal_walker_accessible_via_walker_test(base_url: str) {
    username = f"normal_walker_user_{uuid.uuid4().hex[:8]}";
    register_response = requests.post(
        f"{base_url}/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": "password123"}
        },
        timeout=10
    );
    assert register_response.status_code == 201;
    login_response = requests.post(
        f"{base_url}/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": "password123"}
        },
        timeout=10
    );
    login_data = cast(
        dict[str, Any], _extract_transport_response_data(login_response.json())
    );
    token = login_data["token"];

    response = requests.post(
        f"{base_url}/walker/NormalPayment",
        json={
            "payment_id": "PAY-NORMAL-001",
            "order_id": "ORD-NORMAL-001",
            "amount": 50.00,
            "currency": "EUR"
        },
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );

    assert response.status_code == 200 , (
        f"Expected 200, got {response.status_code}: {response.text}"
    );
    data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
    assert "reports" in data;
    rpt = data["reports"][0];
    assert rpt["status"] == "success";
    assert rpt["payment_id"] == "PAY-NORMAL-001";
    assert rpt["transport"] == "http";
}

"""Test that webhook endpoints require API key authentication."""
def run_webhook_requires_api_key_test(base_url: str) {
    payload = json.dumps({});

    response = requests.post(
        f"{base_url}/webhook/MinimalWebhook",
        data=payload,
        headers={"Content-Type": "application/json"},
        timeout=5
    );

    assert response.status_code in (401, 422) , (
        f"Expected 401 or 422, got {response.status_code}: {response.text}"
    );
}

"""Test that webhook endpoints reject invalid API keys."""
def run_webhook_invalid_api_key_test(base_url: str) {
    payload = json.dumps({});

    response = requests.post(
        f"{base_url}/webhook/MinimalWebhook",
        data=payload,
        headers={"Content-Type": "application/json", "X-API-Key": "invalid_key_12345"},
        timeout=5
    );

    assert response.status_code == 401 , (
        f"Expected 401, got {response.status_code}: {response.text}"
    );
}

"""MinimalWebhook works with valid API key."""
def run_minimal_webhook_with_valid_api_key_test(base_url: str) {
    username = f"minimal_webhook_user_{uuid.uuid4().hex[:8]}";
    token = _register_and_login(base_url, username, "password123");

    api_key_response = requests.post(
        f"{base_url}/api-key/create",
        json={"name": "minimal_webhook_key", "expiry_days": 30},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );
    assert api_key_response.status_code == 201 , (
        f"Failed to create API key: {api_key_response.text}"
    );
    api_key_data = cast(
        dict[str, Any], _extract_transport_response_data(api_key_response.json())
    );
    api_key = api_key_data["api_key"];

    payload = json.dumps({});
    payload_bytes = payload.encode("utf-8");
    signature = _generate_webhook_signature(payload_bytes, api_key);
    response = requests.post(
        f"{base_url}/webhook/MinimalWebhook",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": api_key,
            "X-Webhook-Signature": signature
        },
        timeout=10
    );

    assert response.status_code == 200 , (
        f"Expected 200, got {response.status_code}: {response.text}"
    );
    data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
    assert "reports" in data;
    assert data["reports"][0]["status"] == "received";
    assert data["reports"][0]["transport"] == "webhook";
}

"""PaymentReceived webhook walker with multiple fields."""
def run_webhook_payment_received_test(base_url: str) {
    username = f"payment_user_{uuid.uuid4().hex[:8]}";
    token = _register_and_login(base_url, username, "password123");

    api_key_response = requests.post(
        f"{base_url}/api-key/create",
        json={"name": "payment_webhook_key", "expiry_days": 30},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );
    assert api_key_response.status_code == 201;
    api_key_data = cast(
        dict[str, Any], _extract_transport_response_data(api_key_response.json())
    );
    api_key = api_key_data["api_key"];

    payload = json.dumps(
        {
            "payment_id": "PAY-12345",
            "order_id": "ORD-67890",
            "amount": 99.99,
            "currency": "USD"
        }
    );
    payload_bytes = payload.encode("utf-8");
    signature = _generate_webhook_signature(payload_bytes, api_key);

    response = requests.post(
        f"{base_url}/webhook/PaymentReceived",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": api_key,
            "X-Webhook-Signature": signature
        },
        timeout=10
    );

    assert response.status_code == 200 , (
        f"Expected 200, got {response.status_code}: {response.text}"
    );
    data = cast(dict[str, Any], _extract_transport_response_data(response.json()));
    assert "reports" in data;
    rpt = data["reports"][0];
    assert rpt["status"] == "success";
    assert rpt["payment_id"] == "PAY-12345";
    assert rpt["order_id"] == "ORD-67890";
    assert rpt["amount"] == 99.99;
    assert rpt["currency"] == "USD";
}

"""Webhook walkers are NOT accessible via /walker/."""
def run_webhook_not_accessible_via_walker_test(base_url: str) {
    username = f"webhook_path_user_{uuid.uuid4().hex[:8]}";
    token = _register_and_login(base_url, username, "password123");

    response = requests.post(
        f"{base_url}/walker/PaymentReceived",
        json={"payment_id": "PAY-TEST", "order_id": "ORD-TEST", "amount": 10.00},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );

    assert response.status_code in (400, 404, 405) , (
        f"Expected 400/404/405, got {response.status_code}: {response.text}"
    );
}

"""Test that revoked API keys are rejected."""
def run_webhook_revoked_api_key_test(base_url: str) {
    username = f"webhook_revoke_user_{uuid.uuid4().hex[:8]}";
    token = _register_and_login(base_url, username, "password123");

    api_key_response = requests.post(
        f"{base_url}/api-key/create",
        json={"name": "key_to_revoke", "expiry_days": 30},
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );
    assert api_key_response.status_code == 201;
    api_key_data = cast(
        dict[str, Any], _extract_transport_response_data(api_key_response.json())
    );
    api_key = api_key_data["api_key"];
    api_key_id = api_key_data["api_key_id"];

    # Verify API key works with MinimalWebhook
    payload = json.dumps({});
    payload_bytes = payload.encode("utf-8");
    signature = _generate_webhook_signature(payload_bytes, api_key);
    response = requests.post(
        f"{base_url}/webhook/MinimalWebhook",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": api_key,
            "X-Webhook-Signature": signature
        },
        timeout=10
    );
    assert response.status_code == 200;

    # Revoke the API key
    revoke_response = requests.delete(
        f"{base_url}/api-key/{api_key_id}",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    );
    assert revoke_response.status_code == 200 , (
        f"Failed to revoke key: {revoke_response.text}"
    );

    # Try to use revoked key
    response = requests.post(
        f"{base_url}/webhook/MinimalWebhook",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": api_key,
            "X-Webhook-Signature": signature
        },
        timeout=10
    );

    assert response.status_code == 401 , (
        f"Expected 401 for revoked key, got {response.status_code}: {response.text}"
    );
}

# =========================================================================
# Test class 1: Webhook tests WITHOUT MongoDB (file-based storage)
# Uses ScaleTestClient (in-process, no subprocess)
# =========================================================================
glob wh_fixtures_dir: Path = Path(__file__).parent / "fixtures",
     wh_test_file: Path = wh_fixtures_dir / "test_api.jac";

test "webhook without mongo - endpoint exists" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        schema = client._server.server.app.openapi();
        paths = schema.get("paths", {});

        assert "/webhook/PaymentReceived" in paths , (
            f"Expected /webhook/PaymentReceived in paths: {list(paths.keys())}"
        );
        assert "/webhook/MinimalWebhook" in paths , (
            f"Expected /webhook/MinimalWebhook in paths: {list(paths.keys())}"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - normal walker not in webhook" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        schema = client._server.server.app.openapi();
        paths = schema.get("paths", {});

        assert "/webhook/NormalPayment" not in paths , (
            "NormalPayment should NOT have webhook endpoint but found in paths"
        );
        assert "/walker/NormalPayment" in paths or "/walker/{walker_name}" in paths , (
            "NormalPayment should be accessible via /walker/ endpoint"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - normal walker accessible via walker endpoint" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        walker_username = f"normal_walker_user_{uuid.uuid4().hex[:8]}";
        client.register_user(walker_username, "password123");
        token = client.login_user(walker_username, "password123");

        response = client.post(
            "/walker/NormalPayment",
            json={
                "payment_id": "PAY-NORMAL-001",
                "order_id": "ORD-NORMAL-001",
                "amount": 50.00,
                "currency": "EUR"
            },
            headers={"Authorization": f"Bearer {token}"}
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json());
        assert "reports" in data;
        rpt = data["reports"][0];
        assert rpt["status"] == "success";
        assert rpt["payment_id"] == "PAY-NORMAL-001";
        assert rpt["transport"] == "http";
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - requires api key" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        payload = json.dumps({});

        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={"Content-Type": "application/json"}
        );

        assert response.status_code in (401, 422) , (
            f"Expected 401 or 422, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - invalid api key" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        payload = json.dumps({});

        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": "invalid_key_12345"
            }
        );

        assert response.status_code == 401 , (
            f"Expected 401, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - minimal webhook with valid api key" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        _wh_user1 = f"minimal_webhook_user_{uuid.uuid4().hex[:8]}";
        client.register_user(_wh_user1, "password123");
        token = client.login_user(_wh_user1, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "minimal_webhook_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201 , (
            f"Failed to create API key: {api_key_response.text}"
        );
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];

        payload = json.dumps({});
        payload_bytes = payload.encode("utf-8");
        signature = _generate_webhook_signature(payload_bytes, api_key);
        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature
            }
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json());
        assert "reports" in data;
        assert data["reports"][0]["status"] == "received";
        assert data["reports"][0]["transport"] == "webhook";
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - payment received with fields" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        _wh_user2 = f"payment_user_{uuid.uuid4().hex[:8]}";
        client.register_user(_wh_user2, "password123");
        token = client.login_user(_wh_user2, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "payment_webhook_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];

        payload = json.dumps(
            {
                "payment_id": "PAY-12345",
                "order_id": "ORD-67890",
                "amount": 99.99,
                "currency": "USD"
            }
        );
        payload_bytes = payload.encode("utf-8");
        signature = _generate_webhook_signature(payload_bytes, api_key);

        response = client.post(
            "/webhook/PaymentReceived",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature
            }
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json());
        assert "reports" in data;
        rpt = data["reports"][0];
        assert rpt["status"] == "success";
        assert rpt["payment_id"] == "PAY-12345";
        assert rpt["order_id"] == "ORD-67890";
        assert rpt["amount"] == 99.99;
        assert rpt["currency"] == "USD";
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - not accessible via walker endpoint" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        _wh_user3 = f"webhook_path_user_{uuid.uuid4().hex[:8]}";
        client.register_user(_wh_user3, "password123");
        token = client.login_user(_wh_user3, "password123");

        response = client.post(
            "/walker/PaymentReceived",
            json={"payment_id": "PAY-TEST", "order_id": "ORD-TEST", "amount": 10.00},
            headers={"Authorization": f"Bearer {token}"}
        );

        assert response.status_code in (400, 404, 405) , (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

test "webhook without mongo - revoked api key" {
    original_mongodb_uri = os.environ.pop("MONGODB_URI", None);
    client = make_client();
    try {
        _wh_user4 = f"webhook_revoke_user_{uuid.uuid4().hex[:8]}";
        client.register_user(_wh_user4, "password123");
        token = client.login_user(_wh_user4, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "key_to_revoke", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];
        api_key_id = api_key_data["api_key_id"];

        # Verify API key works with MinimalWebhook
        payload = json.dumps({});
        payload_bytes = payload.encode("utf-8");
        signature = _generate_webhook_signature(payload_bytes, api_key);
        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature
            }
        );
        assert response.status_code == 200;

        # Revoke the API key
        revoke_response = client.delete(
            f"/api-key/{api_key_id}", headers={"Authorization": f"Bearer {token}"}
        );
        assert revoke_response.status_code == 200 , (
            f"Failed to revoke key: {revoke_response.text}"
        );

        # Try to use revoked key
        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature
            }
        );

        assert response.status_code == 401 , (
            f"Expected 401 for revoked key, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
        if original_mongodb_uri is not None {
            os.environ["MONGODB_URI"] = original_mongodb_uri;
        }
    }
}

# =========================================================================
# Test class 2: Webhook tests WITH MongoDB (via testcontainers)
# =========================================================================
test "webhook with mongo - endpoint exists" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_endpoint_exists_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - normal walker not in webhook" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_normal_walker_not_in_webhook_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - normal walker accessible via walker endpoint" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_normal_walker_accessible_via_walker_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - requires api key" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_requires_api_key_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - invalid api key" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_invalid_api_key_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - minimal webhook with valid api key" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_minimal_webhook_with_valid_api_key_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - payment received with fields" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_payment_received_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - not accessible via walker endpoint" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_not_accessible_via_walker_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}

test "webhook with mongo - revoked api key" {
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    mongo_uri = mongo_container.get_connection_url();
    os.environ["MONGODB_URI"] = mongo_uri;
    _cleanup_db_files(wh_fixtures_dir);
    sp = _start_server(wh_fixtures_dir, wh_test_file, port, base_url);
    try {
        run_webhook_revoked_api_key_test(base_url);
    } finally {
        _stop_server(sp);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        _cleanup_db_files(wh_fixtures_dir);
    }
}
