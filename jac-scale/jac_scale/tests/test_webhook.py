"""Tests for webhook walkers - runs both without and with MongoDB."""

import contextlib
import gc
import glob
import hashlib
import hmac
import json
import os
import socket
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import Any, cast

import requests
from testcontainers.mongodb import MongoDbContainer


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


class WebhookTestMixin:
    """Mixin containing all webhook test methods.

    Subclasses must provide: base_url, fixtures_dir, test_file attributes.
    """

    base_url: str
    fixtures_dir: Path
    test_file: Path

    @staticmethod
    def _extract_transport_response_data(
        json_response: dict[str, Any] | list[Any],
    ) -> dict[str, Any] | list[Any]:
        """Extract data from TransportResponse envelope format."""
        if isinstance(json_response, list) and len(json_response) == 2:
            body: dict[str, Any] = json_response[1]
            json_response = body

        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ):
            if json_response.get("ok") and json_response.get("data") is not None:
                return json_response["data"]
            elif not json_response.get("ok") and json_response.get("error"):
                error_info = json_response["error"]
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                }
                if "code" in error_info:
                    result["error_code"] = error_info["code"]
                if "details" in error_info:
                    result["error_details"] = error_info["details"]
                return result

        return json_response

    def _generate_webhook_signature(self, payload: bytes, secret: str) -> str:
        """Generate HMAC-SHA256 signature for webhook payload."""
        return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()

    def test_webhook_endpoint_exists_for_webhook_walkers(self) -> None:
        """Verify webhook endpoints are registered for walkers with @restspec(protocol=APIProtocol.WEBHOOK)."""
        response = requests.get(f"{self.base_url}/openapi.json", timeout=5)
        assert response.status_code == 200
        schema = response.json()
        paths = schema.get("paths", {})

        assert "/webhook/PaymentReceived" in paths, (
            f"Expected /webhook/PaymentReceived in paths: {list(paths.keys())}"
        )
        assert "/webhook/MinimalWebhook" in paths, (
            f"Expected /webhook/MinimalWebhook in paths: {list(paths.keys())}"
        )

    def test_normal_walker_not_in_webhook_endpoint(self) -> None:
        """Verify normal walkers are NOT in /webhook/."""
        response = requests.get(f"{self.base_url}/openapi.json", timeout=5)
        assert response.status_code == 200
        schema = response.json()
        paths = schema.get("paths", {})

        assert "/webhook/NormalPayment" not in paths, (
            "NormalPayment should NOT have webhook endpoint but found in paths"
        )
        assert "/walker/NormalPayment" in paths or "/walker/{walker_name}" in paths, (
            "NormalPayment should be accessible via /walker/ endpoint"
        )

    def test_normal_walker_accessible_via_walker_endpoint(self) -> None:
        """Verify NormalPayment (no webhook restspec) works via /walker/ endpoint."""
        username = f"normal_walker_user_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        register_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token = register_data["token"]

        response = requests.post(
            f"{self.base_url}/walker/NormalPayment",
            json={
                "payment_id": "PAY-NORMAL-001",
                "order_id": "ORD-NORMAL-001",
                "amount": 50.00,
                "currency": "EUR",
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "reports" in data
        report = data["reports"][0]
        assert report["status"] == "success"
        assert report["payment_id"] == "PAY-NORMAL-001"
        assert report["transport"] == "http"

    def test_webhook_requires_api_key(self) -> None:
        """Test that webhook endpoints require API key authentication."""
        payload = json.dumps({})

        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={"Content-Type": "application/json"},
            timeout=5,
        )

        assert response.status_code in (401, 422), (
            f"Expected 401 or 422, got {response.status_code}: {response.text}"
        )

    def test_webhook_invalid_api_key(self) -> None:
        """Test that webhook endpoints reject invalid API keys."""
        payload = json.dumps({})

        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": "invalid_key_12345",
            },
            timeout=5,
        )

        assert response.status_code == 401, (
            f"Expected 401, got {response.status_code}: {response.text}"
        )

    def test_minimal_webhook_with_valid_api_key(self) -> None:
        """MinimalWebhook works with valid API key."""
        username = f"minimal_webhook_user_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        register_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token = register_data["token"]

        api_key_response = requests.post(
            f"{self.base_url}/api-key/create",
            json={"name": "minimal_webhook_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        assert api_key_response.status_code == 201, (
            f"Failed to create API key: {api_key_response.text}"
        )
        api_key_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(api_key_response.json()),
        )
        api_key = api_key_data["api_key"]

        payload = json.dumps({})
        payload_bytes = payload.encode("utf-8")
        signature = self._generate_webhook_signature(payload_bytes, api_key)
        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
            },
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "reports" in data
        assert data["reports"][0]["status"] == "received"
        assert data["reports"][0]["transport"] == "webhook"

    def test_webhook_payment_received_with_fields(self) -> None:
        """PaymentReceived webhook walker with multiple fields."""
        username = f"payment_user_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        register_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token = register_data["token"]

        api_key_response = requests.post(
            f"{self.base_url}/api-key/create",
            json={"name": "payment_webhook_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        assert api_key_response.status_code == 201
        api_key_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(api_key_response.json()),
        )
        api_key = api_key_data["api_key"]

        payload = json.dumps(
            {
                "payment_id": "PAY-12345",
                "order_id": "ORD-67890",
                "amount": 99.99,
                "currency": "USD",
            }
        )
        payload_bytes = payload.encode("utf-8")
        signature = self._generate_webhook_signature(payload_bytes, api_key)

        response = requests.post(
            f"{self.base_url}/webhook/PaymentReceived",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
            },
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "reports" in data
        report = data["reports"][0]
        assert report["status"] == "success"
        assert report["payment_id"] == "PAY-12345"
        assert report["order_id"] == "ORD-67890"
        assert report["amount"] == 99.99
        assert report["currency"] == "USD"

    def test_webhook_not_accessible_via_regular_walker_endpoint(self) -> None:
        """Webhook walkers are NOT accessible via /walker/."""
        username = f"webhook_path_user_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        register_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token = register_data["token"]

        response = requests.post(
            f"{self.base_url}/walker/PaymentReceived",
            json={
                "payment_id": "PAY-TEST",
                "order_id": "ORD-TEST",
                "amount": 10.00,
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )

        assert response.status_code in (400, 404, 405), (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        )

    def test_webhook_revoked_api_key(self) -> None:
        """Test that revoked API keys are rejected."""
        username = f"webhook_revoke_user_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        register_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token = register_data["token"]

        api_key_response = requests.post(
            f"{self.base_url}/api-key/create",
            json={"name": "key_to_revoke", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        assert api_key_response.status_code == 201
        api_key_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(api_key_response.json()),
        )
        api_key = api_key_data["api_key"]
        api_key_id = api_key_data["api_key_id"]

        # Verify API key works with MinimalWebhook
        payload = json.dumps({})
        payload_bytes = payload.encode("utf-8")
        signature = self._generate_webhook_signature(payload_bytes, api_key)
        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
            },
            timeout=10,
        )
        assert response.status_code == 200

        # Revoke the API key
        revoke_response = requests.delete(
            f"{self.base_url}/api-key/{api_key_id}",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        assert revoke_response.status_code == 200, (
            f"Failed to revoke key: {revoke_response.text}"
        )

        # Try to use revoked key (same payload and signature)
        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": api_key,
                "X-Webhook-Signature": signature,
            },
            timeout=10,
        )

        assert response.status_code == 401, (
            f"Expected 401 for revoked key, got {response.status_code}: {response.text}"
        )


# ---------------------------------------------------------------------------
# Server lifecycle helpers shared by both test classes
# ---------------------------------------------------------------------------


class _ServerMixin:
    """Shared server start/stop/cleanup logic."""

    fixtures_dir: Path
    test_file: Path
    port: int
    base_url: str
    server_process: subprocess.Popen[str] | None

    @classmethod
    def _start_server(cls) -> None:
        """Start the jac-scale server in a subprocess."""
        jac_executable = Path(sys.executable).parent / "jac"

        cmd = [
            str(jac_executable),
            "start",
            cls.test_file.name,
            "--port",
            str(cls.port),
        ]

        env = os.environ.copy()

        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(cls.fixtures_dir),
            env=env,
        )

        max_attempts = 50
        server_ready = False

        for _ in range(max_attempts):
            if cls.server_process.poll() is not None:
                stdout, stderr = cls.server_process.communicate()
                raise RuntimeError(
                    f"Server process terminated unexpectedly.\n"
                    f"STDOUT: {stdout}\nSTDERR: {stderr}"
                )

            try:
                response = requests.get(f"{cls.base_url}/docs", timeout=2)
                if response.status_code in (200, 404):
                    print(f"Server started successfully on port {cls.port}")
                    server_ready = True
                    break
            except (requests.ConnectionError, requests.Timeout):
                time.sleep(2)

        if not server_ready:
            cls.server_process.terminate()
            try:
                stdout, stderr = cls.server_process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                stdout, stderr = cls.server_process.communicate()

            raise RuntimeError(
                f"Server failed to start after {max_attempts} attempts.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            )

    @classmethod
    def _stop_server(cls) -> None:
        if cls.server_process:
            cls.server_process.terminate()
            try:
                cls.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                cls.server_process.wait()

        time.sleep(0.5)
        gc.collect()

    @classmethod
    def _cleanup_db_files(cls) -> None:
        """Delete SQLite database files and legacy shelf files."""
        import shutil

        for pattern in [
            "*.db",
            "*.db-wal",
            "*.db-shm",
            "anchor_store.db.dat",
            "anchor_store.db.bak",
            "anchor_store.db.dir",
        ]:
            for db_file in glob.glob(pattern):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        for pattern in ["*.db", "*.db-wal", "*.db-shm"]:
            for db_file in glob.glob(str(cls.fixtures_dir / pattern)):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        client_build_dir = cls.fixtures_dir / ".jac"
        if client_build_dir.exists():
            with contextlib.suppress(Exception):
                shutil.rmtree(client_build_dir)


# ---------------------------------------------------------------------------
# Test class 1: Webhook tests WITHOUT MongoDB (file-based storage)
# ---------------------------------------------------------------------------


class TestWebhookWithoutMongo(_ServerMixin, WebhookTestMixin):
    """Webhook tests using file-based storage (no MongoDB)."""

    server_process: subprocess.Popen[str] | None = None
    _original_mongodb_uri: str | None = None

    @classmethod
    def setup_class(cls) -> None:
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_api.jac"

        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        # Ensure no MONGODB_URI is set
        cls._original_mongodb_uri = os.environ.pop("MONGODB_URI", None)

        cls._cleanup_db_files()
        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        cls._stop_server()
        cls._cleanup_db_files()

        # Restore MONGODB_URI if it was previously set
        if cls._original_mongodb_uri is not None:
            os.environ["MONGODB_URI"] = cls._original_mongodb_uri


# ---------------------------------------------------------------------------
# Test class 2: Webhook tests WITH MongoDB (via testcontainers)
# ---------------------------------------------------------------------------


class TestWebhookWithMongo(_ServerMixin, WebhookTestMixin):
    """Webhook tests using MongoDB storage via testcontainers."""

    server_process: subprocess.Popen[str] | None = None
    mongo_container: MongoDbContainer

    @classmethod
    def setup_class(cls) -> None:
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_api.jac"

        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        # Start MongoDB container
        cls.mongo_container = MongoDbContainer("mongo:latest")
        cls.mongo_container.start()
        mongo_uri = cls.mongo_container.get_connection_url()

        # Set env var so the server subprocess picks it up
        os.environ["MONGODB_URI"] = mongo_uri

        cls._cleanup_db_files()
        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        cls._stop_server()

        # Remove env var
        os.environ.pop("MONGODB_URI", None)

        # Stop MongoDB container
        cls.mongo_container.stop()

        cls._cleanup_db_files()
