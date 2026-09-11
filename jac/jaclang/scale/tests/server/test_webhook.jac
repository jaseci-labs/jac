"""Tests for webhook walkers (in-process, Postgres-native key storage)."""

import hashlib;
import hmac;
import json;
import logging;
import os;
import time;
import uuid;
import from logging.handlers { MemoryHandler }
import glob;
import from pathlib { Path }
import from typing { cast }
import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

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
    } finally {}
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
        srv = client._server;
        assert srv is not None , "server must be running";
        schema = srv.app.openapi();
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
        srv = client._server;
        assert srv is not None , "server must be running";
        schema = srv.app.openapi();
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


# =========================================================================
# GitHub scheme: no api key, X-Hub-Signature-256 over the raw body
# =========================================================================
import shutil;
import tempfile;
import urllib.parse;
import from jaclang.runtime.builtin { restspec, APIProtocol }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }

glob gh_secret: str = "test-github-webhook-secret";

"""Headers GitHub would send for `payload`, signed with `secret`."""
def _github_headers(
    payload: bytes,
    secret: str = gh_secret,
    event: str = "issues",
    delivery: str = "delivery-1",
    prefixed: bool = True,
    header: str = "X-Hub-Signature-256"
) -> dict[str, str] {
    sig = _generate_webhook_signature(payload, secret);
    return {
        "Content-Type": "application/json",
        header: ("sha256=" + sig) if prefixed else sig,
        "X-GitHub-Event": event,
        "X-GitHub-Delivery": delivery
    };
}

walker SchemeProbe {
    can go with Root entry {
        report 1;
    }
}

"""Boot the github fixture app from a scratch copy of the fixture directory.
The scale config singleton is bound to the copy first, because `register`
reads the secret through it and the harness never points it at a fixture on
its own. The copy also caps bodies at 64 KiB so the oversize test stays cheap
without that cap reaching the servers other tests boot from the shared dir;
the [scale.webhook] block is the last table in the file, so appended keys land
inside it."""
def _github_client(
    with_secret: bool = True, signature_header: str = "", rate_limit_per_minute: int = 0
) -> ScaleTestClient {
    tmp = tempfile.mkdtemp();
    for f in `glob.`glob(str(wh_fixtures_dir / "*")) {
        if Path(f).is_file() {
            shutil.copy2(f, Path(tmp) / Path(f).name);
        }
    }
    toml_path = Path(tmp) / "jac.toml";
    toml = toml_path.read_text();
    assert "[scale.webhook]" in toml , "fixture jac.toml lost its webhook block";
    if with_secret {
        extra = ["max_body_bytes = 65536"];
        if signature_header {
            extra.append(f'github_signature_header = "{signature_header}"');
        }
        if rate_limit_per_minute > 0 {
            extra.append(f"rate_limit_per_minute = {rate_limit_per_minute}");
        }
        toml = toml.rstrip("\n") + "\n" + "\n".join(extra) + "\n";
    } else {
        toml = toml.split("[scale.webhook]")[0];
    }
    toml_path.write_text(toml);
    reset_scale_config();
    get_scale_config(project_dir=Path(tmp));
    client = ScaleTestClient.from_file(
        str(wh_fixtures_dir / "github_webhook.jac"), base_path=tmp
    );
    client._tmp_dir = tmp;
    return client;
}

def _close_github(client: ScaleTestClient) {
    client.close();
    reset_scale_config();
}

test "github scheme - signed delivery accepted without an api key" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "closed", "installation": {"id": 151191459}});
        body = payload.encode("utf-8");
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(body, event="issues", delivery="uuid-1")
        );
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        rpt = extract_data(response.json())["reports"][0];
        assert rpt["status"] == "received";
        assert rpt["transport"] == "webhook-github";
        assert rpt["action"] == "closed";
        assert rpt["installation"]["id"] == 151191459;
        assert rpt["event"] == "issues" , f"event header not mapped: {rpt}";
        assert rpt["delivery"] == "uuid-1" , f"delivery header not mapped: {rpt}";
    } finally {
        _close_github(client);
    }
}

test "github scheme - bare hex signature accepted" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "opened"});
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(payload.encode("utf-8"), prefixed=False)
        );
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - wrong secret rejected" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "opened"});
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(payload.encode("utf-8"), secret="not-the-secret")
        );
        assert response.status_code == 401 , (
            f"Expected 401, got {response.status_code}: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - missing signature header rejected" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "opened"});
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers={"Content-Type": "application/json", "X-GitHub-Event": "issues"}
        );
        # The header is declared required, so the framework may answer 422
        # before the callback runs; either way nothing is spawned.
        assert response.status_code in (401, 422) , (
            f"Expected 401 or 422, got {response.status_code}: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - api-key headers do not substitute for the signature" {
    client = _github_client();
    try {
        username = f"github_scheme_user_{uuid.uuid4().hex[:8]}";
        client.register_user(username, "password123");
        token = client.login_user(username, "password123");
        api_key_response = client.post(
            "/api-key/create",
            json={"name": "not_for_github", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert api_key_response.status_code == 201;
        api_key_data = extract_data(api_key_response.json());
        payload = json.dumps({"action": "opened"});
        ts = str(int(time.time()));
        jac_sig = _generate_webhook_signature(
            f"{ts}.".encode("utf-8") + payload.encode("utf-8"),
            api_key_data["signing_secret"]
        );
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key_data["api_key"],
                "X-Webhook-Signature": jac_sig,
                "X-Webhook-Timestamp": ts
            }
        );
        assert response.status_code in (401, 422) , (
            f"Expected 401 or 422, got {response.status_code}: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - oversize body rejected before any signature work" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "opened", "pad": "x" * 70000});
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(payload.encode("utf-8"), secret="wrong")
        );
        assert response.status_code == 413 , (
            f"Expected 413, got {response.status_code}: {response.text[:200]}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - provider headers win over same-named body keys" {
    client = _github_client();
    try {
        payload = json.dumps(
            {"action": "opened", "event": "spoofed", "delivery": "spoofed"}
        );
        response = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(
                payload.encode("utf-8"), event="pull_request", delivery="uuid-2"
            )
        );
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        rpt = extract_data(response.json())["reports"][0];
        assert rpt["event"] == "pull_request" , f"body key overrode the header: {rpt}";
        assert rpt["delivery"] == "uuid-2" , f"body key overrode the header: {rpt}";
    } finally {
        _close_github(client);
    }
}

test "github scheme - a missing provider header clears a same-named body key" {
    client = _github_client();
    try {
        payload = json.dumps(
            {"action": "opened", "event": "spoofed", "delivery": "spoofed"}
        );
        headers = _github_headers(payload.encode("utf-8"));
        headers.pop("X-GitHub-Event");
        headers.pop("X-GitHub-Delivery");
        response = client.post(
            "/webhook/GithubEvent", content=payload, headers=headers
        );
        assert response.status_code == 200 , (
            f"Expected 200, got {response.status_code}: {response.text}"
        );
        rpt = extract_data(response.json())["reports"][0];
        assert rpt["event"] == "" , f"body key survived a missing header: {rpt}";
        assert rpt["delivery"] == "" , f"body key survived a missing header: {rpt}";
    } finally {
        _close_github(client);
    }
}

test "github scheme - form-encoded delivery is refused instead of running empty" {
    client = _github_client();
    try {
        body = "payload=" + urllib.parse.quote(json.dumps({"action": "opened"}));
        headers = _github_headers(body.encode("utf-8"));
        headers["Content-Type"] = "application/x-www-form-urlencoded";
        response = client.post("/webhook/GithubEvent", content=body, headers=headers);
        assert response.status_code == 415 , (
            f"Expected 415, got {response.status_code}: {response.text}"
        );
        assert "application/json" in response.text , (
            f"refusal should name the required content type: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - the media type itself must be application/json" {
    client = _github_client();
    try {
        payload = json.dumps({"action": "opened"});
        body = payload.encode("utf-8");
        with_charset = _github_headers(body);
        with_charset["Content-Type"] = "application/json; charset=utf-8";
        accepted = client.post(
            "/webhook/GithubEvent", content=payload, headers=with_charset
        );
        assert accepted.status_code == 200 , (
            f"a charset parameter should be allowed, got {accepted.status_code}: {accepted.text}"
        );
        lookalike = _github_headers(body);
        lookalike["Content-Type"] = "application/json-patch+json";
        refused = client.post(
            "/webhook/GithubEvent", content=payload, headers=lookalike
        );
        assert refused.status_code == 415 , (
            f"a json lookalike media type should be refused, got {refused.status_code}: {refused.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - per-walker rate limit answers 429 once the window is spent" {
    client = _github_client(rate_limit_per_minute=1);
    try {
        payload = json.dumps({"action": "opened"});
        statuses = [
            client.post(
                "/webhook/GithubEvent",
                content=payload,
                headers=_github_headers(payload.encode("utf-8"), delivery=f"d-{i}")
            ).status_code for i in range(3)
        ];
        assert statuses[0] == 200 , f"first delivery should pass: {statuses}";
        assert 429 in statuses[1:] , f"a window of 1 never produced a 429: {statuses}";
    } finally {
        _close_github(client);
    }
}

test "github scheme - not reachable via the walker endpoint" {
    client = _github_client();
    try {
        username = f"github_path_user_{uuid.uuid4().hex[:8]}";
        client.register_user(username, "password123");
        token = client.login_user(username, "password123");
        response = client.post(
            "/walker/GithubEvent",
            json={"action": "opened"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert response.status_code in (400, 404, 405) , (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        );
    } finally {
        _close_github(client);
    }
}

test "github scheme - openapi documents the GitHub headers, not the api key" {
    client = _github_client();
    try {
        srv = client._server;
        assert srv is not None , "server must be running";
        paths = srv.app.openapi().get("paths", {});
        gh_params = [
            p.get("name")
            for p in paths["/webhook/GithubEvent"]["post"].get("parameters", [])
        ];
        assert "x_hub_signature_256" in gh_params , f"missing signature header: {gh_params}";
        assert "x_github_event" in gh_params , f"missing event header: {gh_params}";
        assert "x_api_key" not in gh_params , f"api key documented on a github walker: {gh_params}";
        key_params = [
            p.get("name")
            for p in paths["/webhook/KeyedEvent"]["post"].get("parameters", [])
        ];
        assert "x_api_key" in key_params , f"api-key walker lost its header: {key_params}";
        assert "x_hub_signature_256" not in key_params;
    } finally {
        _close_github(client);
    }
}

test "restspec - unknown scheme rejected at decoration" {
    try {
        restspec(protocol=APIProtocol.WEBHOOK, scheme="stripe");
        assert False , "scheme='stripe' should have raised";
    } except ValueError as e {
        assert "scheme" in str(e) , f"unexpected message: {e}";
    }
}

test "restspec - scheme requires the webhook protocol" {
    try {
        restspec(scheme="github")(SchemeProbe);
        assert False , "scheme on an HTTP walker should have raised";
    } except ValueError as e {
        assert "protocol=WEBHOOK" in str(e) , f"unexpected message: {e}";
    }
}

test "github scheme - the configured signature header is the one required" {
    client = _github_client(signature_header="X-Custom-GitHub-Signature");
    try {
        payload = json.dumps({"action": "opened"});
        body = payload.encode("utf-8");
        custom_only = client.post(
            "/webhook/GithubEvent",
            content=payload,
            headers=_github_headers(body, header="X-Custom-GitHub-Signature")
        );
        assert custom_only.status_code == 200 , (
            f"Expected 200 with only the configured header, got {custom_only.status_code}: {custom_only.text}"
        );
        rpt = extract_data(custom_only.json())["reports"][0];
        assert rpt["action"] == "opened" , f"walker did not run: {rpt}";
        default_only = client.post(
            "/webhook/GithubEvent", content=payload, headers=_github_headers(body)
        );
        assert default_only.status_code in (401, 422) , (
            f"Expected the default header to be refused, got {default_only.status_code}: {default_only.text}"
        );
        srv = client._server;
        assert srv is not None , "server must be running";
        paths = srv.app.openapi().get("paths", {});
        names = [
            p.get("name")
            for p in paths["/webhook/GithubEvent"]["post"].get("parameters", [])
        ];
        assert "x_custom_github_signature" in names , f"configured header not declared: {names}";
        assert "x_hub_signature_256" not in names , f"default header still declared: {names}";
    } finally {
        _close_github(client);
    }
}

test "github scheme - boot fails without a secret" {
    booted = False;
    try {
        client = _github_client(with_secret=False);
        booted = True;
        client.close();
    } except ValueError as e {
        assert "github_secret" in str(e) , f"unexpected boot error: {e}";
    } finally {
        reset_scale_config();
    }
    assert not booted , "a github-scheme walker booted with an empty secret";
}
