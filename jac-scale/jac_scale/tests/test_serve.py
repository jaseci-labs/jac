"""Test for jac-scale serve command and REST API server."""

import contextlib
import glob
import socket
import subprocess
import time
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import jwt as pyjwt
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
    session_file: Path
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

        # Use unique session file for tests
        cls.session_file = cls.fixtures_dir / f"test_serve_{cls.port}.session"

        # Clean up any existing session files before starting
        cls._cleanup_session_files()

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

        # Clean up session files
        cls._cleanup_session_files()

    @classmethod
    def _start_server(cls) -> None:
        """Start the jac-scale server in a subprocess."""
        # Build the command to start the server
        cmd = [
            "jac",
            "serve",
            str(cls.test_file),
            "--session",
            str(cls.session_file),
            "--port",
            str(cls.port),
        ]

        # Start the server process
        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
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
                time.sleep(0.2)

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
    def _cleanup_session_files(cls) -> None:
        """Delete session files including user database files."""
        if cls.session_file.exists():
            session_dir = cls.session_file.parent
            prefix = cls.session_file.name

            for file in session_dir.iterdir():
                if file.name.startswith(prefix):
                    with contextlib.suppress(Exception):
                        file.unlink()

        session_pattern = str(cls.fixtures_dir / "test_serve_*.session*")
        for file_path in glob.glob(session_pattern):
            with contextlib.suppress(Exception):
                Path(file_path).unlink()

    def _request(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> dict[str, Any]:
        """Make HTTP request to server and return JSON response."""
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}

        if token:
            headers["Authorization"] = f"Bearer {token}"

        response = requests.request(
            method=method,
            url=url,
            json=data,
            headers=headers,
            timeout=timeout,
        )

        json_response: Any = response.json()

        # Handle jac-scale's tuple response format [status, body]
        if isinstance(json_response, list) and len(json_response) == 2:
            body: dict[str, Any] = json_response[1]
            return body

        return json_response  # type: ignore[return-value]

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
            {"email": "testuser1@example.com", "password": "testpass123"},
        )

        assert "email" in result
        assert "token" in result
        assert "root_id" in result
        assert result["email"] == "testuser1@example.com"

    def test_user_login(self) -> None:
        """Test user login endpoint."""
        # Create user first
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": "loginuser@example.com", "password": "loginpass"},
        )

        # Login with correct credentials
        login_result = self._request(
            "POST",
            "/user/login",
            {"email": "loginuser@example.com", "password": "loginpass"},
        )

        assert "token" in login_result
        assert login_result["email"] == "loginuser@example.com"
        assert login_result["root_id"] == create_result["root_id"]

    def test_user_login_wrong_password(self) -> None:
        """Test login fails with wrong password."""
        # Create user
        self._request(
            "POST",
            "/user/register",
            {"email": "failuser@example.com", "password": "correctpass"},
        )

        # Try to login with wrong password
        login_result = self._request(
            "POST",
            "/user/login",
            {"email": "failuser@example.com", "password": "wrongpass"},
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
            {"email": "refresh_bearer@example.com", "password": "password123"},
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
            {"email": "refresh_old@example.com", "password": "password123"},
        )

        # Create a very old token (15 days old, beyond refresh window)
        very_old_token = self._create_very_old_token(
            "refresh_old@example.com", days_ago=15
        )

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
        fake_token = self._create_expired_token("nonexistent@example.com", days_ago=1)

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
            {"email": "refresh_multi@example.com", "password": "password123"},
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
        email = "refresh_preserve@example.com"
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": email, "password": "password123"},
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

        assert original_payload["username"] == email
        assert new_payload["username"] == email
        assert original_payload["username"] == new_payload["username"]

    def test_refresh_token_updates_expiration(self) -> None:
        """Test that refreshed token has updated expiration time."""
        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": "refresh_exp@example.com", "password": "password123"},
        )
        original_token = create_result["token"]

        # Wait a moment to ensure time difference
        time.sleep(1)

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
            {"email": "adduser@example.com", "password": "pass"},
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
            {"email": "greetuser@example.com", "password": "pass"},
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
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": "defuser@example.com", "password": "pass"},
        )
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

    def test_spawn_walker_create_task(self) -> None:
        """Test spawning a CreateTask walker."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": "spawnuser@example.com", "password": "pass"},
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

    def test_user_isolation(self) -> None:
        """Test that users have isolated graph spaces."""
        # Create two users
        user1 = self._request(
            "POST",
            "/user/register",
            {"email": "isolate1@example.com", "password": "pass1"},
        )
        user2 = self._request(
            "POST",
            "/user/register",
            {"email": "isolate2@example.com", "password": "pass2"},
        )

        print(user1)
        # Users should have different root IDs
        assert user1["root_id"] != user2["root_id"]

    def test_invalid_function(self) -> None:
        """Test calling nonexistent function."""
        # Create user
        create_result = self._request(
            "POST",
            "/user/register",
            {"email": "invalidfunc@example.com", "password": "pass"},
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
            {"email": "invalidwalk@example.com", "password": "pass"},
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
            {"email": "multuser@example.com", "password": "pass"},
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
            json={"email": "status201@example.com", "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 201
        data = response.json()
        assert "token" in data
        assert "email" in data
        assert data["email"] == "status201@example.com"

    def test_status_code_user_register_400_already_exists(self) -> None:
        """Test POST /user/register returns 400 when user already exists."""
        email = "status400exists@example.com"
        # Create user first
        requests.post(
            f"{self.base_url}/user/register",
            json={"email": email, "password": "password123"},
            timeout=5,
        )

        # Try to create again
        response = requests.post(
            f"{self.base_url}/user/register",
            json={"email": email, "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 400
        data = response.json()
        assert "error" in data

    def test_status_code_user_login_200_success(self) -> None:
        """Test POST /user/login returns 200 on successful login."""
        email = "status200login@example.com"
        # Create user first
        requests.post(
            f"{self.base_url}/user/register",
            json={"email": email, "password": "password123"},
            timeout=5,
        )

        # Login
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": email, "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 200
        data = response.json()
        assert "token" in data

    def test_status_code_user_login_400_missing_credentials(self) -> None:
        """Test POST /user/login returns 400/422 when email or password is missing."""
        # Missing password - FastAPI returns 422 for validation errors
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": "test@example.com"},
            timeout=5,
        )
        assert response.status_code in [400, 422]  # 422 from FastAPI validation
        data = response.json()
        # Either custom error or FastAPI validation error
        assert "error" in data or "detail" in data

        # Missing email
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
            json={"email": "", "password": "password123"},
            timeout=5,
        )
        assert response.status_code == 400
        data = response.json()
        assert data["error"] == "Email and password required"

    def test_status_code_user_login_401_invalid_credentials(self) -> None:
        """Test POST /user/login returns 401 for invalid credentials."""
        email = "status401login@example.com"
        # Create user
        requests.post(
            f"{self.base_url}/user/register",
            json={"email": email, "password": "correctpass"},
            timeout=5,
        )

        # Wrong password
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": email, "password": "wrongpass"},
            timeout=5,
        )
        assert response.status_code == 401
        data = response.json()
        assert data["error"] == "Invalid credentials"

        # Non-existent user
        response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": "nonexistent@example.com", "password": "password"},
            timeout=5,
        )
        assert response.status_code == 401

    def test_status_code_refresh_token_200_success(self) -> None:
        """Test POST /user/refresh-token returns 200 on successful refresh."""
        # Create user and get token
        create_response = requests.post(
            f"{self.base_url}/user/register",
            json={"email": "status200refresh@example.com", "password": "password123"},
            timeout=5,
        )
        token = create_response.json()["token"]

        # Refresh token
        response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": token},
            timeout=5,
        )
        assert response.status_code == 200
        data = response.json()
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
        data = response.json()
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
        data = response.json()
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
            json={"email": "status200walker@example.com", "password": "password123"},
            timeout=5,
        )
        token = create_response.json()["token"]

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
            json={"email": "status200func@example.com", "password": "password123"},
            timeout=5,
        )
        token = create_response.json()["token"]

        # Execute function
        response = requests.post(
            f"{self.base_url}/function/add_numbers",
            json={"a": 10, "b": 20},
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = response.json()
        assert "result" in data

    def test_status_code_page_404_not_found(self) -> None:
        """Test GET /page/{name} returns 404 for non-existent page."""
        response = requests.get(
            f"{self.base_url}/page/nonexistent_page_xyz",
            timeout=5,
        )
        assert response.status_code == 404
        assert "404" in response.text

    def test_status_code_static_client_js_200_or_503(self) -> None:
        """Test GET /static/client.js returns 200 or 503."""
        response = requests.get(
            f"{self.base_url}/static/client.js",
            timeout=5,
        )
        # Should be either 200 (success) or 503 (bundle generation failed)
        assert response.status_code in [200, 503]
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
        email = "integration_status@example.com"

        # Register - 201
        register_response = requests.post(
            f"{self.base_url}/user/register",
            json={"email": email, "password": "secure123"},
            timeout=5,
        )
        assert register_response.status_code == 201
        token1 = register_response.json()["token"]

        # Login - 200
        login_response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": email, "password": "secure123"},
            timeout=5,
        )
        assert login_response.status_code == 200
        token2 = login_response.json()["token"]

        # Refresh token - 200
        refresh_response = requests.post(
            f"{self.base_url}/user/refresh-token",
            json={"token": token1},
            timeout=5,
        )
        assert refresh_response.status_code == 200
        token3 = refresh_response.json()["token"]

        # Failed login - 401
        fail_response = requests.post(
            f"{self.base_url}/user/login",
            json={"email": email, "password": "wrongpass"},
            timeout=5,
        )
        assert fail_response.status_code == 401

        # Verify all tokens are different
        assert token1 != token2
        assert token2 != token3
        assert token1 != token3
