"""Test for jac-scale serve command and REST API server."""

import contextlib
import gc
import glob
import hashlib
import hmac
import json
import socket
import subprocess
import time
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any, cast

import jwt as pyjwt
import pytest
import requests


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


class TestJacScaleServe:
    """Test jac-scale serve REST API functionality."""

    # Class attributes with type annotations
    fixtures_dir: Path
    test_file: Path
    port: int
    base_url: str
    server_process: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        """Set up test class - runs once for all tests."""
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_api.jac"

        # Ensure fixture file exists
        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        # Use dynamically allocated free port
        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        # Clean up any existing database files before starting
        cls._cleanup_db_files()

        # Start the server process
        cls.server_process = None
        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        """Tear down test class - runs once after all tests."""
        # Stop server process
        if cls.server_process:
            cls.server_process.terminate()
            try:
                cls.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                cls.server_process.wait()

        # Give the server a moment to fully release file handles
        time.sleep(0.5)
        # Run garbage collection to clean up lingering socket objects
        gc.collect()

        # Clean up database files
        cls._cleanup_db_files()

    @classmethod
    def _start_server(cls) -> None:
        """Start the jac-scale server in a subprocess."""
        import sys

        # Get the jac executable from the same directory as the current Python interpreter
        jac_executable = Path(sys.executable).parent / "jac"

        # Build the command to start the server
        # Use just the filename and set cwd to fixtures directory
        # This is required for proper bytecode caching and module resolution
        cmd = [
            str(jac_executable),
            "start",
            cls.test_file.name,
            "--port",
            str(cls.port),
        ]

        # Start the server process with cwd set to fixtures directory
        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(cls.fixtures_dir),
        )

        # Wait for server to be ready
        max_attempts = 50
        server_ready = False

        for _ in range(max_attempts):
            # Check if process has died
            if cls.server_process.poll() is not None:
                # Process has terminated, get output
                stdout, stderr = cls.server_process.communicate()
                raise RuntimeError(
                    f"Server process terminated unexpectedly.\n"
                    f"STDOUT: {stdout}\nSTDERR: {stderr}"
                )

            try:
                # Try to connect to any endpoint to verify server is up
                # Use /docs which should exist in FastAPI
                response = requests.get(f"{cls.base_url}/docs", timeout=2)
                if response.status_code in (200, 404):  # Server is responding
                    print(f"Server started successfully on port {cls.port}")
                    server_ready = True
                    break
            except (requests.ConnectionError, requests.Timeout):
                time.sleep(2)

        # If we get here and server is not ready, it failed to start
        if not server_ready:
            # Try to terminate the process
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
    def _cleanup_db_files(cls) -> None:
        """Delete SQLite database files and legacy shelf files."""
        import shutil

        # Clean up SQLite database files (WAL mode creates -wal and -shm files)
        for pattern in [
            "*.db",
            "*.db-wal",
            "*.db-shm",
            # Legacy shelf files
            "anchor_store.db.dat",
            "anchor_store.db.bak",
            "anchor_store.db.dir",
        ]:
            for db_file in glob.glob(pattern):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        # Clean up database files in fixtures directory
        for pattern in ["*.db", "*.db-wal", "*.db-shm"]:
            for db_file in glob.glob(str(cls.fixtures_dir / pattern)):
                with contextlib.suppress(Exception):
                    Path(db_file).unlink()

        # Clean up .jac directory created during serve
        client_build_dir = cls.fixtures_dir / ".jac"
        if client_build_dir.exists():
            with contextlib.suppress(Exception):
                shutil.rmtree(client_build_dir)

    @staticmethod
    def _extract_transport_response_data(
        json_response: dict[str, Any] | list[Any],
    ) -> dict[str, Any] | list[Any]:
        """Extract data from TransportResponse envelope format.

        Handles both success and error responses.
        """
        # Handle jac-scale's tuple response format [status, body]
        if isinstance(json_response, list) and len(json_response) == 2:
            body: dict[str, Any] = json_response[1]
            json_response = body

        # Handle TransportResponse envelope format
        # If response has 'ok', 'type', 'data', 'error' keys, extract data/error
        if (
            isinstance(json_response, dict)
            and "ok" in json_response
            and "data" in json_response
        ):
            if json_response.get("ok") and json_response.get("data") is not None:
                # Success case: return the data field
                return json_response["data"]
            elif not json_response.get("ok") and json_response.get("error"):
                # Error case: return error info in a format tests expect
                error_info = json_response["error"]
                result: dict[str, Any] = {
                    "error": error_info.get("message", "Unknown error")
                }
                if "code" in error_info:
                    result["error_code"] = error_info["code"]
                if "details" in error_info:
                    result["error_details"] = error_info["details"]
                return result

        # FastAPI validation errors (422) have "detail" field - return as-is
        # These come from Pydantic validation before our endpoint is called
        return json_response

    def _request(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        token: str | None = None,
        timeout: int = 5,
        max_retries: int = 60,
        retry_interval: float = 2.0,
    ) -> dict[str, Any]:
        """Make HTTP request to server and return JSON response.

        Retries on 503 Service Unavailable responses.
        """
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}

        if token:
            headers["Authorization"] = f"Bearer {token}"

        response = None
        for attempt in range(max_retries):
            response = requests.request(
                method=method,
                url=url,
                json=data,
                headers=headers,
                timeout=timeout,
            )

            if response.status_code == 503:
                print(
                    f"[DEBUG] {path} returned 503, retrying ({attempt + 1}/{max_retries})..."
                )
                time.sleep(retry_interval)
                continue

            break

        assert response is not None, "No response received"
        json_response: Any = response.json()
        return self._extract_transport_response_data(json_response)  # type: ignore[return-value]

    def _create_expired_token(self, username: str, days_ago: int = 1) -> str:
        """Create an expired JWT token for testing."""
        # Use the same secret as the server (default)
        secret = "supersecretkey"
        algorithm = "HS256"

        past_time = datetime.now(UTC) - timedelta(days=days_ago)
        payload = {
            "username": username,
            "exp": past_time + timedelta(hours=1),  # Expired 1 hour after past_time
            "iat": past_time,
        }
        return pyjwt.encode(payload, secret, algorithm=algorithm)

    def _create_very_old_token(self, username: str, days_ago: int = 15) -> str:
        """Create a token that's too old to refresh."""
        secret = "supersecretkey"
        algorithm = "HS256"

        past_time = datetime.now(UTC) - timedelta(days=days_ago)
        payload = {
            "username": username,
            "exp": past_time + timedelta(hours=1),
            "iat": past_time,
        }
        return pyjwt.encode(payload, secret, algorithm=algorithm)

    def test_server_root_endpoint(self) -> None:
        """Test that the server is running and FastAPI docs are available."""
        # Check that /docs endpoint exists (FastAPI auto-generated docs)
        response = requests.get(f"{self.base_url}/docs", timeout=5)
        assert response.status_code == 200

    def test_user_creation(self) -> None:
        """Test user creation endpoint."""
        result = self._request(
            "POST",
            "/user/register",
            {"username": "testuser1", "password": "testpass123"},
        )

        assert "username" in result
        assert "token" in result
        assert "root_id" in result
        assert result["username"] == "testuser1"

    def test_user_login(self) -> None:
        """Test user login endpoint."""
        # Create user first
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "loginuser", "password": "loginpass"},
        )

        # Login with correct credentials
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": "loginuser", "password": "loginpass"},
        )

        assert "token" in login_result
        assert login_result["username"] == "loginuser"
        assert login_result["root_id"] == create_result["root_id"]

    def test_user_login_wrong_password(self) -> None:
        """Test login fails with wrong password."""
        # Create user
        self._request(
            "POST",
            "/user/register",
            {"username": "failuser", "password": "correctpass"},
        )

        # Try to login with wrong password
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": "failuser", "password": "wrongpass"},
        )

        assert "error" in login_result

    def test_refresh_token_with_missing_token(self) -> None:
        """Test refresh endpoint without token parameter."""
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {},
        )

        # Case 1: FastAPI Automatic Validation (422 Unprocessable Entity)
        # This happens because 'token' is missing from the body entirely.
        if "detail" in refresh_result:
            assert isinstance(refresh_result["detail"], list)
            error_entry = refresh_result["detail"][0]
            assert error_entry["loc"] == ["body", "token"]
            assert error_entry["type"] == "missing"

        # Case 2: Custom Logic Error
        # This handles cases where your code manually returns an error (if you bypass Pydantic).
        else:
            assert "error" in refresh_result
            assert refresh_result["error"] in [
                "Token is required",
                "Invalid or expired token",
            ]

    def test_refresh_token_with_bearer_prefix(self) -> None:
        """Test refreshing token with 'Bearer ' prefix."""
        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "refresh_bearer", "password": "password123"},
        )
        original_token = create_result["token"]

        # Refresh with Bearer prefix
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": f"Bearer {original_token}"},
        )

        assert "token" in refresh_result
        assert "message" in refresh_result
        assert refresh_result["message"] == "Token refreshed successfully"

    def test_refresh_token_with_empty_token(self) -> None:
        """Test refresh endpoint with empty token."""
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": ""},
        )

        assert "error" in refresh_result
        assert refresh_result["error"] == "Token is required"

    def test_refresh_token_with_invalid_token(self) -> None:
        """Test refreshing with completely invalid token."""
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": "invalid.token.here"},
        )

        assert "error" in refresh_result
        assert refresh_result["error"] == "Invalid or expired token"

    def test_refresh_token_with_malformed_token(self) -> None:
        """Test refreshing with malformed JWT token."""
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": "not.a.jwt"},
        )

        assert "error" in refresh_result
        assert refresh_result["error"] == "Invalid or expired token"

    def test_refresh_token_too_old(self) -> None:
        """Test refreshing with token older than refresh window."""
        # Create user first
        self._request(
            "POST",
            "/user/register",
            {"username": "refresh_old", "password": "password123"},
        )

        # Create a very old token (15 days old, beyond refresh window)
        very_old_token = self._create_very_old_token("refresh_old", days_ago=15)

        # Try to refresh the very old token
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": very_old_token},
        )

        assert "error" in refresh_result
        assert refresh_result["error"] == "Invalid or expired token"

    def test_refresh_token_with_nonexistent_user(self) -> None:
        """Test refreshing token for user that doesn't exist."""
        # Create token for non-existent user
        fake_token = self._create_expired_token("nonexistent", days_ago=1)

        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": fake_token},
        )

        assert "error" in refresh_result
        assert refresh_result["error"] == "Invalid or expired token"

    def test_refresh_token_multiple_times(self) -> None:
        """Test refreshing token multiple times in succession."""
        # Create user and get initial token
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "refresh_multi", "password": "password123"},
        )
        token1 = create_result["token"]

        # First refresh
        refresh_result1 = self._request(
            "POST",
            "/user/refresh-token",
            {"token": token1},
        )
        token2 = refresh_result1["token"]
        assert token2 != token1

        # Second refresh
        refresh_result2 = self._request(
            "POST",
            "/user/refresh-token",
            {"token": token2},
        )
        token3 = refresh_result2["token"]
        assert token3 != token2
        assert token3 != token1

    def test_refresh_token_preserves_username(self) -> None:
        """Test that refreshed token contains correct username."""
        # Create user
        username = "refresh_preserve"
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "password123"},
        )
        original_token = create_result["token"]

        # Refresh token
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": original_token},
        )
        new_token = refresh_result["token"]

        # Decode both tokens and verify username is preserved
        secret = "supersecretkey"
        algorithm = "HS256"

        original_payload = pyjwt.decode(original_token, secret, algorithms=[algorithm])
        new_payload = pyjwt.decode(new_token, secret, algorithms=[algorithm])

        assert original_payload["username"] == username
        assert new_payload["username"] == username
        assert original_payload["username"] == new_payload["username"]

    @pytest.mark.xfail(reason="possible issue with user.json", strict=False)
    def test_refresh_token_updates_expiration(self) -> None:
        """Test that refreshed token has updated expiration time."""
        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "refresh_exp", "password": "password123"},
        )
        original_token = create_result["token"]

        # Refresh token
        refresh_result = self._request(
            "POST",
            "/user/refresh-token",
            {"token": original_token},
        )
        new_token = refresh_result["token"]

        # Decode tokens and compare expiration times
        secret = "supersecretkey"
        algorithm = "HS256"

        original_payload = pyjwt.decode(original_token, secret, algorithms=[algorithm])
        new_payload = pyjwt.decode(new_token, secret, algorithms=[algorithm])

        # New token should have later expiration time
        assert new_payload["exp"] > original_payload["exp"]
        assert new_payload["iat"] > original_payload["iat"]

    def test_refresh_endpoint_in_openapi_docs(self) -> None:
        """Test that refresh endpoint appears in OpenAPI documentation."""
        response = requests.get(f"{self.base_url}/openapi.json", timeout=5)
        assert response.status_code == 200

        openapi_spec = response.json()
        paths = openapi_spec.get("paths", {})

        # Check that refresh endpoint is documented
        assert "/user/refresh-token" in paths
        refresh_endpoint = paths["/user/refresh-token"]
        assert "post" in refresh_endpoint

        # Check endpoint metadata
        post_spec = refresh_endpoint["post"]
        assert post_spec["summary"] == "Refresh JWT token"
        assert "User APIs" in post_spec["tags"]

    def test_call_function_add_numbers(self) -> None:
        """Test calling the add_numbers function."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "adduser", "password": "pass"},
        )
        token = create_result["token"]

        # Call add_numbers
        result = self._request(
            "POST",
            "/function/add_numbers",
            {"a": 10, "b": 25},
            token=token,
        )

        assert "result" in result
        assert result["result"] == 35

    def test_call_function_greet(self) -> None:
        """Test calling the greet function."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "greetuser", "password": "pass"},
        )
        token = create_result["token"]

        # Call greet with name
        result = self._request(
            "POST",
            "/function/greet",
            {"name": "Alice"},
            token=token,
        )

        assert "result" in result
        assert result["result"] == "Hello, Alice!"

    def test_call_function_with_defaults(self) -> None:
        """Test calling function with default parameters."""
        # Create user with unique username to avoid conflicts
        username = f"defuser_{uuid.uuid4().hex[:8]}"
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "pass"},
        )
        assert "token" in create_result, f"Registration failed: {create_result}"
        token = create_result["token"]

        # Call greet without name (should use default)
        result = self._request(
            "POST",
            "/function/greet",
            {"args": {}},
            token=token,
        )

        assert "result" in result
        assert result["result"] == "Hello, World!"

    @pytest.mark.xfail(reason="possible issue with user.json", strict=False)
    def test_spawn_walker_create_task(self) -> None:
        """Test spawning a CreateTask walker."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "spawnuser", "password": "pass"},
        )
        token = create_result["token"]

        # Spawn CreateTask walker
        result = self._request(
            "POST",
            "/walker/CreateTask",
            {"title": "Test Task", "priority": 2},
            token=token,
        )

        assert "result" in result
        assert "reports" in result

    @pytest.mark.xfail(reason="possible issue with user.json", strict=False)
    def test_user_isolation(self) -> None:
        """Test that users have isolated graph spaces."""
        # Use unique emails to avoid conflicts with previous test runs
        unique_id = uuid.uuid4().hex[:8]
        username1 = f"isolate1_{unique_id}"
        username2 = f"isolate2_{unique_id}"

        # Create two users
        user1 = self._request(
            "POST",
            "/user/register",
            {"username": username1, "password": "pass1"},
        )
        user2 = self._request(
            "POST",
            "/user/register",
            {"username": username2, "password": "pass2"},
        )

        print(f"user1: {user1}")
        print(f"user2: {user2}")
        # Both users should be created successfully (no error, has root_id)
        assert "error" not in user1, f"user1 creation failed: {user1}"
        assert "error" not in user2, f"user2 creation failed: {user2}"
        assert "root_id" in user1, f"user1 missing root_id: {user1}"
        assert "root_id" in user2, f"user2 missing root_id: {user2}"
        # Users should have different root IDs
        assert user1["root_id"] != user2["root_id"]

    def test_invalid_function(self) -> None:
        """Test calling nonexistent function."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "invalidfunc", "password": "pass"},
        )
        token = create_result["token"]

        # Try to call nonexistent function
        result = self._request(
            "POST",
            "/function/nonexistent",
            {"args": {}},
            token=token,
        )

        assert "Method Not Allowed" in result["detail"]

    def test_invalid_walker(self) -> None:
        """Test spawning nonexistent walker."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "invalidwalk", "password": "pass"},
        )
        token = create_result["token"]

        # Try to spawn nonexistent walker
        result = self._request(
            "POST",
            "/walker/NonExistentWalker",
            {"fields": {}},
            token=token,
        )

        assert "Method Not Allowed" in result["detail"]

    def test_multiply_function(self) -> None:
        """Test calling the multiply function (jac-scale specific test)."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "multuser", "password": "pass"},
        )
        token = create_result["token"]

        # Call multiply
        result = self._request(
            "POST",
            "/function/multiply",
            {"x": 7, "y": 8},
            token=token,
        )

        assert "result" in result
        assert result["result"] == 56

    def test_status_code_user_register_201_success(self) -> None:
        """Test POST /user/register returns 201 on successful registration."""
        response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": "status201", "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 201
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "token" in data
        assert "username" in data
        assert data["username"] == "status201"

    def test_status_code_user_register_400_already_exists(self) -> None:
        """Test POST /user/register returns 400 when user already exists."""
        username = "status400exists"
        # Create user first
        requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5,
        )

        # Try to create again
        response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 400
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "error" in data

    def test_status_code_user_login_200_success(self) -> None:
        """Test POST /user/login returns 200 on successful login."""
        username = "status200login"
        # Create user first
        requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=5,
        )

        # Login
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_transport_response_data(response.json())
        assert "token" in data

    def test_status_code_user_login_400_missing_credentials(self) -> None:
        """Test POST /user/login returns 400/422 when username or password is missing."""
        # Missing password - FastAPI returns 422 for validation errors
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": "test"},
            timeout=5,
        )
        assert response.status_code in [400, 422]  # 422 from FastAPI validation
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        # Either custom error or FastAPI validation error
        assert "error" in data or "detail" in data

        # Missing username
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"password": "password123"},
            timeout=5,
        )
        assert response.status_code in [400, 422]

        # Missing both
        response = requests.post(
            f"{self.base_url}/user/login",
            json={},
            timeout=5,
        )
        assert response.status_code in [400, 422]

        # Empty string values - should trigger custom 400 validation
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": "", "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 400
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert data["error"] == "Username and password required"

    def test_status_code_user_login_401_invalid_credentials(self) -> None:
        """Test POST /user/login returns 401 for invalid credentials."""
        username = "status401login"
        # Create user
        requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "correctpass"},
            timeout=5,
        )

        # Wrong password
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "wrongpass"},
            timeout=5,
        )
        assert response.status_code == 401
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert data["error"] == "Invalid credentials"

        # Non-existent user
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": "nonexistent", "password": "password"},
            timeout=5,
        )
        assert response.status_code == 401

    def test_status_code_refresh_token_200_success(self) -> None:
        """Test POST /user/refresh-token returns 200 on successful refresh."""
        # Create user and get token
        create_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": "status200refresh", "password": "password123"},
            timeout=5,
        )
        create_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(create_response.json()),
        )
        token = create_data["token"]

        # Refresh token
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": token},
            timeout=5,
        )
        assert response.status_code == 200
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "token" in data
        assert data["message"] == "Token refreshed successfully"

    def test_status_code_refresh_token_400_missing_token(self) -> None:
        """Test POST /user/refresh-token returns 400/422 when token is missing."""
        # Empty token - custom validation returns 400
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": ""},
            timeout=5,
        )
        assert response.status_code == 400
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert data["error"] == "Token is required"

        # Null token - FastAPI validation may return 422
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": None},
            timeout=5,
        )
        assert response.status_code in [400, 422]

    def test_status_code_refresh_token_401_invalid_token(self) -> None:
        """Test POST /user/refresh-token returns 401 for invalid token."""
        # Invalid token format
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": "invalid_token_string"},
            timeout=5,
        )
        assert response.status_code == 401
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert data["error"] == "Invalid or expired token"

        # Malformed JWT
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": "not.a.jwt"},
            timeout=5,
        )
        assert response.status_code == 401

    def test_status_code_walker_200_success(self) -> None:
        """Test POST /walker/{name} returns 200 on successful execution."""
        # Create user
        create_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": "status200walker", "password": "password123"},
            timeout=5,
        )
        create_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(create_response.json()),
        )
        token = create_data["token"]

        # Execute walker
        response = requests.post(
            f"{self.base_url}/walker/CreateTask",
            json={"title": "Test Task", "priority": 2},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200

    def test_status_code_function_200_success(self) -> None:
        """Test POST /function/{name} returns 200 on successful execution."""
        # Create user
        create_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": "status200func", "password": "password123"},
            timeout=5,
        )
        create_data = cast(
            dict[str, Any],
            self._extract_transport_response_data(create_response.json()),
        )
        token = create_data["token"]

        # Execute function
        response = requests.post(
            f"{self.base_url}/function/add_numbers",
            json={"a": 10, "b": 20},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        assert "result" in data

    def test_status_code_page_404_not_found(self) -> None:
        """Test GET /cl/{name} returns 404 for non-existent page."""
        response = requests.get(
            f"{self.base_url}/cl/nonexistent_page_xyz",
            timeout=5,
        )
        assert response.status_code == 404
        assert "404" in response.text

    def test_status_code_static_client_js_200_or_503(self) -> None:
        """Test GET /static/client.js returns 200 or 503."""
        response = requests.get(
            f"{self.base_url}/static/client.js",
            timeout=60,
        )
        # Should be either 200 (success) or 503 (bundle generation failed)
        assert response.status_code in [200, 503, 500]
        if response.status_code == 200:
            assert "application/javascript" in response.headers.get("content-type", "")

    def test_status_code_static_file_404_not_found(self) -> None:
        """Test GET /static/{path} returns 404 for non-existent file."""
        response = requests.get(
            f"{self.base_url}/static/nonexistent_file.css",
            timeout=5,
        )
        assert response.status_code == 404
        assert "not found" in response.text.lower()

    def test_status_code_root_asset_404_not_found(self) -> None:
        """Test GET /{file_path} returns 404 for non-existent asset."""
        response = requests.get(
            f"{self.base_url}/nonexistent_image.png",
            timeout=5,
        )
        assert response.status_code == 404

    def test_status_code_root_asset_404_disallowed_extension(self) -> None:
        """Test GET /{file_path} returns 404 for disallowed file extensions."""
        # Try .exe file
        response = requests.get(
            f"{self.base_url}/malware.exe",
            timeout=5,
        )
        assert response.status_code == 404

        # Try .php file
        response = requests.get(
            f"{self.base_url}/script.php",
            timeout=5,
        )
        assert response.status_code == 404

    def test_status_code_root_asset_404_reserved_paths(self) -> None:
        """Test GET /{file_path} returns 404 for reserved path prefixes."""
        # These paths should be excluded even with valid extensions
        reserved_paths = [
            "page/something.png",
            "walker/something.png",
            "function/something.png",
            "user/something.png",
            "static/something.png",
        ]

        for path in reserved_paths:
            response = requests.get(
                f"{self.base_url}/{path}",
                timeout=5,
            )
            assert response.status_code == 404

    def test_status_code_integration_auth_flow(self) -> None:
        """Integration test for complete authentication flow with status codes."""
        username = "integration_status"

        # Register - 201
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "secure123"},
            timeout=5,
        )
        assert register_response.status_code == 201
        data = cast(
            dict[str, Any],
            self._extract_transport_response_data(register_response.json()),
        )
        token1 = data["token"]

        # Login - 200
        login_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "secure123"},
            timeout=5,
        )
        assert login_response.status_code == 200
        data = cast(
            dict[str, Any], self._extract_transport_response_data(login_response.json())
        )
        token2 = data["token"]

        # Refresh token - 200
        refresh_response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": token1},
            timeout=5,
        )
        assert refresh_response.status_code == 200
        data = cast(
            dict[str, Any],
            self._extract_transport_response_data(refresh_response.json()),
        )
        token3 = data["token"]

        # Failed login - 401
        fail_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "wrongpass"},
            timeout=5,
        )
        assert fail_response.status_code == 401

        # Verify all tokens are different
        assert token1 != token2
        assert token2 != token3
        assert token1 != token3

    def test_private_walker_401_unauthorized(self) -> None:
        """Test that private walker returns 401 without authentication."""
        response = requests.post(
            f"{self.base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=5,
        )
        assert response.status_code == 401

    @pytest.mark.xfail(reason="possible issue with user.json", strict=False)
    def test_private_walker_200_with_auth(self) -> None:
        """Test that private walker returns 200 with valid authentication."""
        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "privateuser", "password": "password123"},
        )
        token = create_result["token"]

        # Call private walker with token
        response = requests.post(
            f"{self.base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 2},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        response_data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        data = response_data["reports"][0]
        assert "message" in data
        assert data["message"] == "Private task created"
        assert "task" in data

    def test_public_walker_200_no_auth(self) -> None:
        """Test that public walker works without authentication."""
        response = requests.post(
            f"{self.base_url}/walker/PublicInfo",
            json={},
            timeout=5,
        )
        assert response.status_code == 200
        response_data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        data = response_data["reports"][0]
        assert "message" in data
        assert data["message"] == "This is a public endpoint"
        assert "auth_required" in data
        assert data["auth_required"] is False

    def test_public_walker_200_with_auth(self) -> None:
        """Test that public walker also works with authentication."""
        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": "publicuser", "password": "password123"},
        )
        token = create_result["token"]

        # Call public walker with token (should still work)
        response = requests.post(
            f"{self.base_url}/walker/PublicInfo",
            json={},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        response_data = cast(
            dict[str, Any], self._extract_transport_response_data(response.json())
        )
        data = response_data["reports"][0]
        assert "message" in data
        assert data["message"] == "This is a public endpoint"

    def test_custom_response_headers_from_config(self) -> None:
        """Test that custom response headers from jac.toml are applied."""
        # Make a request and check for custom headers defined in fixtures/jac.toml
        response = requests.get(f"{self.base_url}/docs", timeout=5)

        # Check for custom headers configured in jac.toml [environments.response.headers]
        assert "x-custom-test-header" in response.headers
        assert response.headers["x-custom-test-header"] == "test-value"

        # Check for COOP/COEP headers (needed for SharedArrayBuffer support)
        assert "cross-origin-opener-policy" in response.headers
        assert response.headers["cross-origin-opener-policy"] == "same-origin"
        assert "cross-origin-embedder-policy" in response.headers
        assert response.headers["cross-origin-embedder-policy"] == "require-corp"

    def test_update_username_success(self) -> None:
        """Test successfully updating username and logging in with new username."""
        # Create user
        username = f"olduser_{uuid.uuid4().hex[:8]}"
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "password123"},
        )
        original_token = create_result["token"]
        original_root_id = create_result["root_id"]

        # Update username
        new_username = f"newuser_{uuid.uuid4().hex[:8]}"
        update_result = self._request(
            "PUT",
            "/user/username",
            {"current_username": username, "new_username": new_username},
            token=original_token,
        )

        assert "username" in update_result
        assert update_result["username"] == new_username
        assert "token" in update_result  # New token with updated username
        assert "root_id" in update_result
        assert (
            update_result["root_id"] == original_root_id
        )  # Root ID should remain same

        # Login with new username should work
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": new_username, "password": "password123"},
        )
        assert login_result["username"] == new_username
        assert "token" in login_result

        # Old username should fail to login
        login_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "password123"},
            timeout=5,
        )
        assert login_response.status_code == 401

    def test_update_username_requires_auth(self) -> None:
        """Test that username update requires authentication."""
        # Create user
        username = f"authtest_{uuid.uuid4().hex[:8]}"
        self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "password123"},
        )

        # Try to update without token
        response = requests.put(
            f"{self.base_url}/user/username",
            json={"current_username": username, "new_username": "newname"},
            timeout=5,
        )
        assert response.status_code == 401

    def test_update_username_cannot_update_other_users(self) -> None:
        """Test that users cannot update other users' usernames."""
        # Create user1
        user1_name = f"user1_{uuid.uuid4().hex[:8]}"
        user1_result = self._request(
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"},
        )
        user1_token = user1_result["token"]

        # Create user2
        user2_name = f"user2_{uuid.uuid4().hex[:8]}"
        self._request(
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"},
        )

        # User1 tries to update user2's username
        response = requests.put(
            f"{self.base_url}/user/username",
            json={"current_username": user2_name, "new_username": "hacked"},
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5,
        )
        assert response.status_code == 403

    def test_update_username_duplicate_fails(self) -> None:
        """Test that updating to an existing username fails."""
        # Create user1
        user1_name = f"user1_{uuid.uuid4().hex[:8]}"
        user1_result = self._request(
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"},
        )
        user1_token = user1_result["token"]

        # Create user2
        user2_name = f"user2_{uuid.uuid4().hex[:8]}"
        self._request(
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"},
        )

        # Try to update user1 to user2 (already exists)
        response = requests.put(
            f"{self.base_url}/user/username",
            json={"current_username": user1_name, "new_username": user2_name},
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5,
        )
        assert response.status_code == 400

    def test_update_username_empty_validation(self) -> None:
        """Test that empty username is rejected."""
        # Create user
        username = f"testuser_{uuid.uuid4().hex[:8]}"
        user_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "password123"},
        )
        token = user_result["token"]

        # Try to update to empty username
        response = requests.put(
            f"{self.base_url}/user/username",
            json={"current_username": username, "new_username": ""},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 400

    # ==================== PASSWORD UPDATE TESTS ====================

    def test_update_password_success(self) -> None:
        """Test successfully updating password and logging in with new password."""
        # Create user
        username = f"passuser_{uuid.uuid4().hex[:8]}"
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass123"},
        )
        token = create_result["token"]

        # Update password
        update_result = self._request(
            "PUT",
            "/user/password",
            {
                "username": username,
                "current_password": "oldpass123",
                "new_password": "newpass456",
            },
            token=token,
        )

        assert "username" in update_result
        assert update_result["username"] == username
        assert "message" in update_result or "success" in str(update_result).lower()

        # Login with new password should work
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": username, "password": "newpass456"},
        )
        assert login_result["username"] == username

        # Old password should fail
        login_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "oldpass123"},
            timeout=5,
        )
        assert login_response.status_code == 401

    def test_update_password_requires_auth(self) -> None:
        """Test that password update requires authentication."""
        # Create user
        username = f"noauthuser_{uuid.uuid4().hex[:8]}"
        self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "password123"},
        )

        # Try to update without token
        response = requests.put(
            f"{self.base_url}/user/password",
            json={
                "username": username,
                "current_password": "password123",
                "new_password": "newpass",
            },
            timeout=5,
        )
        assert response.status_code == 401

    def test_update_password_wrong_current_password(self) -> None:
        """Test that wrong current password is rejected."""
        # Create user
        username = f"wrongpass_{uuid.uuid4().hex[:8]}"
        user_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "correctpass"},
        )
        token = user_result["token"]

        # Try to update with wrong current password
        response = requests.put(
            f"{self.base_url}/user/password",
            json={
                "username": username,
                "current_password": "wrongpass",
                "new_password": "newpass",
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 400

    def test_update_password_cannot_update_other_users(self) -> None:
        """Test that users cannot update other users' passwords."""
        # Create user1
        user1_name = f"passuser1_{uuid.uuid4().hex[:8]}"
        user1_result = self._request(
            "POST",
            "/user/register",
            {"username": user1_name, "password": "pass1"},
        )
        user1_token = user1_result["token"]

        # Create user2
        user2_name = f"passuser2_{uuid.uuid4().hex[:8]}"
        self._request(
            "POST",
            "/user/register",
            {"username": user2_name, "password": "pass2"},
        )

        # User1 tries to update user2's password
        response = requests.put(
            f"{self.base_url}/user/password",
            json={
                "username": user2_name,
                "current_password": "pass2",
                "new_password": "hacked",
            },
            headers={"Authorization": f"Bearer {user1_token}"},
            timeout=5,
        )
        assert response.status_code == 403

    def test_update_password_empty_validation(self) -> None:
        """Test that empty passwords are rejected."""
        # Create user
        username = f"emptypass_{uuid.uuid4().hex[:8]}"
        user_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass"},
        )
        token = user_result["token"]

        # Try to update to empty new password
        response = requests.put(
            f"{self.base_url}/user/password",
            json={
                "username": username,
                "current_password": "oldpass",
                "new_password": "",
            },
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 400

    # ==================== INTEGRATION TESTS ====================

    def test_username_and_password_update_flow(self) -> None:
        """Integration test:  Update username, then password, verify both work."""
        # Create user
        username = f"original_{uuid.uuid4().hex[:8]}"
        create_result = self._request(
            "POST",
            "/user/register",
            {"username": username, "password": "oldpass"},
        )
        token = create_result["token"]
        root_id = create_result["root_id"]

        # Update username
        new_username = f"updated_{uuid.uuid4().hex[:8]}"
        username_update = self._request(
            "PUT",
            "/user/username",
            {"current_username": username, "new_username": new_username},
            token=token,
        )
        new_token = username_update["token"]
        assert username_update["root_id"] == root_id

        # Update password with new username and new token
        password_update = self._request(
            "PUT",
            "/user/password",
            {
                "username": new_username,
                "current_password": "oldpass",
                "new_password": "newpass",
            },
            token=new_token,
        )
        assert password_update["username"] == new_username

        # Login with new username and new password
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": new_username, "password": "newpass"},
        )
        assert login_result["username"] == new_username
        assert login_result["root_id"] == root_id

        # Old username should fail
        old_username_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": username, "password": "newpass"},
            timeout=5,
        )
        assert old_username_response.status_code == 401

        # Old password should fail
        old_password_response = requests.post(
            f"{self.base_url}/user/login",
            json={"username": new_username, "password": "oldpass"},
            timeout=5,
        )
        assert old_password_response.status_code == 401

    # ========================================================================
    # Webhook Walker Tests
    # ========================================================================

    def _generate_webhook_signature(self, payload: bytes, secret: str) -> str:
        """Generate HMAC-SHA256 signature for webhook payload."""
        return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()

    def test_webhook_endpoint_exists_for_webhook_walkers(self) -> None:
        """Test 1: Verify webhook endpoints are registered for walkers with @restspec(webhook=True)."""
        response = requests.get(f"{self.base_url}/openapi.json", timeout=5)
        assert response.status_code == 200
        schema = response.json()
        paths = schema.get("paths", {})

        # PaymentReceived has @restspec(webhook=True) -> should have /webhook/ endpoint
        assert "/webhook/PaymentReceived" in paths, (
            f"Expected /webhook/PaymentReceived in paths: {list(paths.keys())}"
        )
        # MinimalWebhook has @restspec(webhook=True) -> should have /webhook/ endpoint
        assert "/webhook/MinimalWebhook" in paths, (
            f"Expected /webhook/MinimalWebhook in paths: {list(paths.keys())}"
        )

    def test_normal_walker_not_in_webhook_endpoint(self) -> None:
        """Test 2: Verify normal walkers (without @restspec(webhook=True)) are NOT in /webhook/."""
        response = requests.get(f"{self.base_url}/openapi.json", timeout=5)
        assert response.status_code == 200
        schema = response.json()
        paths = schema.get("paths", {})

        # NormalPayment does NOT have @restspec(webhook=True) -> should NOT have /webhook/ endpoint
        assert "/webhook/NormalPayment" not in paths, (
            "NormalPayment should NOT have webhook endpoint but found in paths"
        )
        # NormalPayment should be accessible via /walker/ endpoint
        assert "/walker/NormalPayment" in paths or "/walker/{walker_name}" in paths, (
            "NormalPayment should be accessible via /walker/ endpoint"
        )

    def test_normal_walker_accessible_via_walker_endpoint(self) -> None:
        """Test 2b: Verify NormalPayment (no webhook restspec) works via /walker/ endpoint."""
        # Create user and get token
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

        # Call NormalPayment via /walker/ endpoint
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

        # Try to call MinimalWebhook without API key
        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={"Content-Type": "application/json"},
            timeout=5,
        )

        # Should fail - 401 (our custom error) or 422 (FastAPI validation for missing header)
        assert response.status_code in (401, 422), (
            f"Expected 401 or 422, got {response.status_code}: {response.text}"
        )

    def test_webhook_invalid_api_key(self) -> None:
        """Test that webhook endpoints reject invalid API keys."""
        payload = json.dumps({})

        # Try with invalid API key
        response = requests.post(
            f"{self.base_url}/webhook/MinimalWebhook",
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": "invalid_key_12345",
            },
            timeout=5,
        )

        # Should fail with 401 Unauthorized
        assert response.status_code == 401, (
            f"Expected 401, got {response.status_code}: {response.text}"
        )

    def test_minimal_webhook_with_valid_api_key(self) -> None:
        """Test 3: MinimalWebhook (with @restspec(webhook=True)) works with valid API key."""
        # Create user and get auth token
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

        # Create API key
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

        # Call MinimalWebhook with valid API key (empty payload - no fields required)
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
        """Test 1: PaymentReceived webhook walker with multiple fields + @restspec(webhook=True)."""
        # Create user and get API key
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

        # Send payment webhook
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
        """Test that webhook walkers (with @restspec(webhook=True)) are NOT accessible via /walker/."""
        # Create user and get token
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

        # Try to access PaymentReceived (webhook walker) via /walker/ endpoint
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

        # Webhook walkers should not be accessible via /walker/ endpoint
        # In static mode: 404 (Not Found) or 405 (Method Not Allowed - no POST registered)
        # In dynamic mode: 400 (Bad Request - explicitly rejected)
        assert response.status_code in (400, 404, 405), (
            f"Expected 400/404/405, got {response.status_code}: {response.text}"
        )

    def test_webhook_revoked_api_key(self) -> None:
        """Test that revoked API keys are rejected."""
        # Create user and get auth token
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

        # Create API key
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

        # Should fail with 401
        assert response.status_code == 401, (
            f"Expected 401 for revoked key, got {response.status_code}: {response.text}"
        )


class TestJacScaleServeDevMode:
    """Test jac-scale serve with --dev mode (dynamic routing).

    This tests that the dynamic routing endpoints correctly parse request body
    parameters, which is essential for HMR support.
    """

    fixtures_dir: Path
    test_file: Path
    port: int
    base_url: str
    server_process: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        """Set up test class - runs once for all tests."""
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_api.jac"

        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        cls._cleanup_db_files()
        cls.server_process = None
        cls._start_server_dev_mode()

    @classmethod
    def teardown_class(cls) -> None:
        """Tear down test class."""
        if cls.server_process:
            cls.server_process.terminate()
            try:
                cls.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.server_process.kill()
                cls.server_process.wait()

        time.sleep(0.5)
        gc.collect()
        cls._cleanup_db_files()

    @classmethod
    def _start_server_dev_mode(cls) -> None:
        """Start the jac-scale server in dev mode (dynamic routing).

        In dev mode, the REST API runs on port+1 while Vite runs on port.
        We connect directly to the REST API port to avoid Vite dependency issues.
        """
        import sys

        jac_executable = Path(sys.executable).parent / "jac"
        # Use --api-only to skip Vite dev server (if supported), otherwise use base port
        # The REST API in dev mode runs on base_port + 1
        vite_port = cls.port
        api_port = cls.port + 1
        cls.base_url = f"http://localhost:{api_port}"

        cmd = [
            str(jac_executable),
            "start",
            str(cls.test_file),
            "--port",
            str(vite_port),
            "--dev",  # Enable dev mode for dynamic routing
        ]

        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
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
                # Connect to the REST API port (port+1), not Vite port
                response = requests.get(f"{cls.base_url}/docs", timeout=2)
                if response.status_code in (200, 404):
                    print(
                        f"Dev mode server started successfully on API port {api_port}"
                    )
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
                f"Server failed to start in dev mode after {max_attempts} attempts.\n"
                f"STDOUT: {stdout}\nSTDERR: {stderr}"
            )

    @classmethod
    def _cleanup_db_files(cls) -> None:
        """Delete SQLite database files."""
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

    @staticmethod
    def _extract_data(json_response: dict[str, Any]) -> dict[str, Any]:
        """Extract data from TransportResponse envelope."""
        if isinstance(json_response, dict) and "ok" in json_response:
            if json_response.get("ok") and json_response.get("data") is not None:
                return json_response["data"]
            elif not json_response.get("ok") and json_response.get("error"):
                error_info = json_response["error"]
                return {"error": error_info.get("message", "Unknown error")}
        return json_response

    def test_dev_mode_walker_body_parsing(self) -> None:
        """Test that walkers in dev mode correctly parse request body parameters.

        This is a regression test for the fix where dynamic routing endpoints
        weren't parsing JSON body content into walker fields.
        """
        # Register user
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": f"devtest_{uuid.uuid4().hex[:8]}", "password": "pass"},
            timeout=10,
        )
        assert register_response.status_code == 201
        token = self._extract_data(register_response.json())["token"]

        # Call walker with body parameters - this is what was broken
        response = requests.post(
            f"{self.base_url}/walker/CreateTask",
            json={"title": "Watch Mode Task", "priority": 5},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = self._extract_data(response.json())

        # Verify the walker received and processed the body parameters
        assert "result" in data or "reports" in data, f"Unexpected response: {data}"

    def test_dev_mode_function_body_parsing(self) -> None:
        """Test that functions in dev mode correctly parse request body parameters."""
        # Register user
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": f"devfunc_{uuid.uuid4().hex[:8]}", "password": "pass"},
            timeout=10,
        )
        assert register_response.status_code == 201
        token = self._extract_data(register_response.json())["token"]

        # Call function with body parameters
        response = requests.post(
            f"{self.base_url}/function/add_numbers",
            json={"a": 42, "b": 58},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = self._extract_data(response.json())

        # Verify the function received and processed the body parameters
        assert "result" in data, f"Expected 'result' in response: {data}"
        assert data["result"] == 100, f"Expected 100, got {data['result']}"

    def test_dev_mode_public_walker_no_auth(self) -> None:
        """Test that public walkers work without auth in dev mode."""
        response = requests.post(
            f"{self.base_url}/walker/PublicInfo",
            json={},
            timeout=10,
        )

        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert "reports" in data
        assert data["reports"][0]["message"] == "This is a public endpoint"

    def test_dev_mode_private_walker_requires_auth(self) -> None:
        """Test that private walkers require auth in dev mode."""
        response = requests.post(
            f"{self.base_url}/walker/PrivateCreateTask",
            json={"title": "Private Task", "priority": 1},
            timeout=10,
        )

        assert response.status_code == 401

    # Async Walker Test
    def test_async_walker_basic_execution(self) -> None:
        """Test that async walkers execute correctly with await."""
        # Create user
        username = f"asyncuser_{uuid.uuid4().hex[:8]}"
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"username": username, "password": "password123"},
            timeout=10,
        )
        assert register_response.status_code == 201
        token = self._extract_data(register_response.json())["token"]

        # Spawn async walker
        response = requests.post(
            f"{self.base_url}/walker/AsyncCreateTask",
            json={"title": "Async Test Task", "delay_ms": 50},
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )

        assert response.status_code == 200, (
            f"Expected 200, got {response.status_code}: {response.text}"
        )
        data = self._extract_data(response.json())

        # Verify reports show the async execution flow
        assert "reports" in data, f"Expected 'reports' in response: {data}"
        reports = data["reports"]

        # Should have 3 reports: started, after_async_wait, completed
        assert len(reports) >= 3, f"Expected at least 3 reports, got {len(reports)}"

        # Check the execution order
        assert reports[0]["status"] == "started"
        assert reports[0]["title"] == "Async Test Task"
        assert reports[1]["status"] == "after_async_wait"
        assert reports[2]["status"] == "completed"
        assert "task" in reports[2]

    def test_walker_stream_response(self) -> None:
        """Test that walker streaming responses work correctly."""
        response = requests.post(
            f"{self.base_url}/walker/WalkerStream",
            json={"count": 3},
            timeout=30,
            stream=True,
        )

        assert response.status_code == 200, (
            f"Failed with status {response.status_code}: {response.text}"
        )
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8"
        assert response.headers.get("cache-control") == "no-cache"
        assert response.headers.get("connection") == "close"

        # Collect streaming content
        content = ""
        for chunk in response.iter_content(chunk_size=1024, decode_unicode=True):
            if chunk:
                content += chunk

        # The generator yields "Report 0", "Report 1", "Report 2" without delimiters
        # They get concatenated together in the stream
        expected = "Report 0Report 1Report 2"
        assert content == expected, f"Expected '{expected}', got '{content}'"

    def test_function_stream_response(self) -> None:
        """Test that function streaming responses work correctly."""
        response = requests.post(
            f"{self.base_url}/function/FunctionStream",
            json={"count": 2},
            timeout=30,
            stream=True,
        )

        assert response.status_code == 200, (
            f"Failed with status {response.status_code}: {response.text}"
        )
        assert response.headers["content-type"] == "text/event-stream; charset=utf-8"
        assert response.headers.get("cache-control") == "no-cache"
        assert response.headers.get("connection") == "close"

        # Collect streaming content
        content = ""
        for chunk in response.iter_content(chunk_size=1024, decode_unicode=True):
            if chunk:
                content += chunk

        # The generator yields "Func 0", "Func 1" without delimiters
        # They get concatenated together in the stream
        expected = "Func 0Func 1"
        assert content == expected, f"Expected '{expected}', got '{content}'"
