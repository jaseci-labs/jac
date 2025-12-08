"""Test for jac-scale serve command and REST API server."""

import contextlib
import socket
import subprocess
import time
from pathlib import Path
from typing import Any

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
