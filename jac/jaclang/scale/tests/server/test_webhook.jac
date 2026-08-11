"""Tests for webhook walkers (in-process, Postgres-native key storage)."""

import hashlib;
import hmac;
import json;
import logging;
import os;
import time;
import uuid;
import from logging.handlers { MemoryHandler }
import from pathlib { Path }
import from typing { Any, cast }

import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}
import from jaclang.scale.tests.server_support { _extract_transport_response_data }

"""Generate HMAC-SHA256 signature for webhook payload."""
def _generate_webhook_signature(payload: bytes, secret: str) -> str {
    return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest();
}

# Shared webhook test functions
# =========================================================================
# Webhook tests over the in-process client (Postgres-native key storage)
# =========================================================================
glob wh_fixtures_dir: Path = Path(__file__).parent.parent / "fixtures",
     wh_test_file: Path = wh_fixtures_dir / "test_api.jac";

"""Boot a fixture app while capturing log records, return durability warnings seen."""
def _boot_and_capture_webhook_warnings(fixture_file: str) -> list[str] {
    capture = MemoryHandler(10000);
    root_logger = logging.getLogger();
    root_logger.addHandler(capture);
    client = None;
    try {
        client = make_client(fixture_file);
        return [
            r.getMessage()
            for r in capture.buffer
            if "Webhook API keys are stored in memory" in r.getMessage()
        ];
    } finally {
        root_logger.removeHandler(capture);
        if client is not None {
            client.close();
        }
    }
}

test "webhook warning absent at boot without webhook walkers" {
    try {
        warnings = _boot_and_capture_webhook_warnings("todo_app.jac");
        assert not warnings , (
            "Webhook durability warning fired at boot for an app with no "
            f"webhook walkers: {warnings}"
        );
    } finally { }
}

test "webhook durability warning absent when the shared database is available" {
    # Keys persist in the shared Postgres database by default now, so a
    # normal boot with webhook walkers must NOT warn about in-memory keys.
    warnings = _boot_and_capture_webhook_warnings("test_api.jac");
    assert not warnings , (
        f"Webhook durability warning fired despite a database: {warnings}"
    );
}

test "webhook - endpoint exists" {
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
    }
}

test "webhook - normal walker not in webhook" {
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
    }
}

test "webhook - normal walker accessible via walker endpoint" {
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
    }
}

test "webhook - requires api key" {
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
    }
}

test "webhook - invalid api key" {
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
    }
}

test "webhook - minimal webhook with valid api key" {
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
        ts = str(int(time.time()));
        signature = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload_bytes, api_key_data["signing_secret"]
        );
        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
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
    }
}

test "webhook - payment received with fields" {
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
        ts = str(int(time.time()));
        signature = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload_bytes, api_key_data["signing_secret"]
        );

        response = client.post(
            "/webhook/PaymentReceived",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
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
    }
}

test "webhook - not accessible via walker endpoint" {
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
    }
}

test "webhook - revoked api key" {
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
        ts = str(int(time.time()));
        signature = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload_bytes, api_key_data["signing_secret"]
        );
        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
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
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
            }
        );

        assert response.status_code == 401 , (
            f"Expected 401 for revoked key, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
    }
}

test "webhook - scoped api key" {
    client = make_client();
    try {
        _wh_user5 = f"webhook_scoped_user_{uuid.uuid4().hex[:8]}";
        client.register_user(_wh_user5, "password123");
        token = client.login_user(_wh_user5, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={
                "name": "scoped_key",
                "expiry_days": 30,
                "allowed_walkers": "PaymentReceived"
            },
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];

        payload = json.dumps(
            {
                "payment_id": "PAY-1",
                "order_id": "ORD-1",
                "amount": 1.0,
                "currency": "USD"
            }
        );
        payload_bytes = payload.encode("utf-8");
        ts = str(int(time.time()));
        signature = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload_bytes, api_key_data["signing_secret"]
        );
        allowed_resp = client.post(
            "/webhook/PaymentReceived",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
            }
        );
        assert allowed_resp.status_code == 200 , (
            f"Expected 200 for allowed walker, got {allowed_resp.status_code}: {allowed_resp.text}"
        );

        other_payload = json.dumps({});
        other_bytes = other_payload.encode("utf-8");
        ts2 = str(int(time.time()));
        other_sig = _generate_webhook_signature(
            f"{ts2}.".encode("utf-8") + other_bytes, api_key_data["signing_secret"]
        );
        denied_resp = client.post(
            "/webhook/MinimalWebhook",
            content=other_payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": other_sig,
                "X-Webhook-Timestamp": ts2
            }
        );
        assert denied_resp.status_code == 403 , (
            f"Expected 403 for walker outside scope, got {denied_resp.status_code}: {denied_resp.text}"
        );
    } finally {
        client.close();
    }
}

test "webhook - stale timestamp rejected" {
    client = make_client();
    try {
        username = f"webhook_replay_user_{uuid.uuid4().hex[:8]}";
        client.register_user(username, "password123");
        token = client.login_user(username, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "replay_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];
        signing_secret = api_key_data["signing_secret"];

        payload = json.dumps({});
        payload_bytes = payload.encode("utf-8");
        # 1 hour in the past, well outside the default 300s tolerance.
        stale_ts = str(int(time.time()) - 3600);
        signature = _generate_webhook_signature(
            f"{stale_ts}.".encode("utf-8") + payload_bytes, signing_secret
        );

        response = client.post(
            "/webhook/MinimalWebhook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": stale_ts
            }
        );

        assert response.status_code == 401 , (
            f"Expected 401 for stale timestamp, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
    }
}

test "webhook - unknown body fields dropped" {
    client = make_client();
    try {
        username = f"webhook_massassign_user_{uuid.uuid4().hex[:8]}";
        client.register_user(username, "password123");
        token = client.login_user(username, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "mass_assign_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];
        signing_secret = api_key_data["signing_secret"];

        # Body carries declared walker fields plus an undeclared evil_field.
        # The walker has no such attribute; without filtering, spawn_walker
        # would either error or silently set it. With filtering, the field
        # is dropped before reaching the walker.
        payload = json.dumps(
            {
                "payment_id": "PAY-MA-1",
                "order_id": "ORD-MA-1",
                "amount": 5.0,
                "currency": "USD",
                "evil_field": "should-be-dropped"
            }
        );
        payload_bytes = payload.encode("utf-8");
        ts = str(int(time.time()));
        signature = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload_bytes, signing_secret
        );

        response = client.post(
            "/webhook/PaymentReceived",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
            }
        );

        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        data = extract_data(response.json());
        rpt = data["reports"][0];
        assert rpt["payment_id"] == "PAY-MA-1";
        assert "evil_field" not in rpt , (
            f"evil_field leaked into walker report: {rpt}"
        );
    } finally {
        client.close();
    }
}

test "webhook - api key rejected as user session token" {
    client = make_client();
    try {
        username = f"webhook_l2_user_{uuid.uuid4().hex[:8]}";
        client.register_user(username, "password123");
        token = client.login_user(username, "password123");

        api_key_response = client.post(
            "/api-key/create",
            json={"name": "session_test_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        api_key = api_key_data["api_key"];

        # The api_key is a JWT signed with the same secret as session tokens.
        # validate_jwt_token must refuse it because its 'type' claim is
        # 'api_key', not a user session.
        response = client.post(
            "/walker/NormalPayment",
            json={
                "payment_id": "PAY-L2-1",
                "order_id": "ORD-L2-1",
                "amount": 1.0,
                "currency": "USD"
            },
            headers={"Authorization": f"Bearer {api_key}"}
        );

        assert response.status_code == 401 , (
            f"Expected 401 for api_key used as session token, got {response.status_code}: {response.text}"
        );
    } finally {
        client.close();
    }
}
