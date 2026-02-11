"""Test for restspec decorator functionality."""

import contextlib
import gc
import glob
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


class TestRestSpec:
    """Test restspec decorator functionality."""

    fixtures_dir: Path
    test_file: Path
    port: int
    base_url: str
    server_process: subprocess.Popen[str] | None = None

    @classmethod
    def setup_class(cls) -> None:
        """Set up test class - runs once for all tests."""
        cls.fixtures_dir = Path(__file__).parent / "fixtures"
        cls.test_file = cls.fixtures_dir / "test_restspec.jac"

        if not cls.test_file.exists():
            raise FileNotFoundError(f"Test fixture not found: {cls.test_file}")

        cls.port = get_free_port()
        cls.base_url = f"http://localhost:{cls.port}"

        cls._cleanup_db_files()
        cls._start_server()

    @classmethod
    def teardown_class(cls) -> None:
        """Tear down test class - runs once after all tests."""
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
    def _start_server(cls) -> None:
        """Start the jac-scale server in a subprocess."""
        import sys

        jac_executable = Path(sys.executable).parent / "jac"
        cmd = [
            str(jac_executable),
            "start",
            cls.test_file.name,
            "--port",
            str(cls.port),
        ]

        cls.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(cls.fixtures_dir),
        )

        # Wait for server
        max_attempts = 50
        for _ in range(max_attempts):
            if cls.server_process.poll() is not None:
                stdout, stderr = cls.server_process.communicate()
                raise RuntimeError(f"Server died: {stdout}\n{stderr}")
            try:
                requests.get(f"{cls.base_url}/docs", timeout=1)
                return
            except requests.RequestException:
                time.sleep(0.5)

        cls.server_process.kill()
        raise RuntimeError("Server failed to start")

    @classmethod
    def _cleanup_db_files(cls) -> None:
        """Cleanup database files."""
        import shutil

        for pattern in ["*.db", "*.db-wal", "*.db-shm", "anchor_store*"]:
            for f in glob.glob(pattern):
                with contextlib.suppress(Exception):
                    Path(f).unlink()
        for pattern in ["*.db", "*.db-wal", "*.db-shm"]:
            for f in glob.glob(str(cls.fixtures_dir / pattern)):
                with contextlib.suppress(Exception):
                    Path(f).unlink()
        client_dir = cls.fixtures_dir / ".jac"
        if client_dir.exists():
            with contextlib.suppress(Exception):
                shutil.rmtree(client_dir)

    def _extract_data(self, response: dict[str, Any] | list[Any]) -> Any:  # noqa: ANN401
        # Handle tuple response [status, body]
        if isinstance(response, list) and len(response) == 2:
            response = response[1]

        if isinstance(response, dict) and "data" in response:
            return response["data"]
        return response

    def test_custom_method_walker(self) -> None:
        """Test walker with custom GET method."""
        response = requests.get(f"{self.base_url}/walker/GetWalker", timeout=5)
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["reports"][0]["message"] == "GetWalker executed"

    def test_custom_path_walker(self) -> None:
        """Test walker with custom path."""
        response = requests.get(f"{self.base_url}/custom/walker", timeout=5)
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["reports"][0]["message"] == "CustomPathWalker executed"
        assert data["reports"][0]["path"] == "/custom/walker"

    def test_post_method_walker(self) -> None:
        """Test walker with explicit POST method."""
        response = requests.post(f"{self.base_url}/walker/PostWalker", timeout=5)
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["reports"][0]["message"] == "PostWalker executed"
        assert data["reports"][0]["method"] == "POST"

    def test_default_method_walker(self) -> None:
        """Test walker with default method (POST)."""
        response = requests.post(f"{self.base_url}/walker/DefaultWalker", timeout=5)
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["reports"][0]["message"] == "DefaultWalker executed"
        assert data["reports"][0]["method"] == "DEFAULT"

    def test_custom_method_func(self) -> None:
        """Test function with custom GET method."""
        requests.post(
            f"{self.base_url}/user/register", json={"username": "u1", "password": "p1"}
        )
        login = requests.post(
            f"{self.base_url}/user/login", json={"username": "u1", "password": "p1"}
        )
        token = self._extract_data(login.json())["token"]

        response = requests.get(
            f"{self.base_url}/function/get_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["result"]["message"] == "get_func executed"

    def test_custom_path_func(self) -> None:
        """Test function with custom path."""
        # Use existing user token if possible, but simplest is fresh login
        login = requests.post(
            f"{self.base_url}/user/login", json={"username": "u1", "password": "p1"}
        )
        token = self._extract_data(login.json())["token"]

        response = requests.get(
            f"{self.base_url}/custom/func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["result"]["message"] == "custom_path_func executed"
        assert data["result"]["path"] == "/custom/func"

    def test_post_method_func(self) -> None:
        """Test function with explicit POST method."""
        # Use existing user token if possible, but simplest is fresh login
        login = requests.post(
            f"{self.base_url}/user/login", json={"username": "u1", "password": "p1"}
        )
        token = self._extract_data(login.json())["token"]

        response = requests.post(
            f"{self.base_url}/function/post_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["result"]["message"] == "post_func executed"
        assert data["result"]["method"] == "POST"

    def test_default_method_func(self) -> None:
        """Test function with default method (POST)."""
        # Use existing user token if possible, but simplest is fresh login
        login = requests.post(
            f"{self.base_url}/user/login", json={"username": "u1", "password": "p1"}
        )
        token = self._extract_data(login.json())["token"]

        response = requests.post(
            f"{self.base_url}/function/default_func",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["result"]["message"] == "default_func executed"
        assert data["result"]["method"] == "DEFAULT"

    def test_get_walker_with_params(self) -> None:
        """Test walker with GET method and query parameters."""
        # Parameters should be passed as query string
        params: dict[str, str | int] = {"name": "Alice", "age": 30}
        response = requests.get(
            f"{self.base_url}/walker/GetWalkerWithParams",
            params=params,
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["reports"][0]["message"] == "GetWalkerWithParams executed"
        assert data["reports"][0]["name"] == "Alice"
        assert data["reports"][0]["age"] == 30

    def test_get_func_with_params(self) -> None:
        """Test function with GET method and query parameters."""
        # Use existing user token if possible, but simplest is fresh login
        login = requests.post(
            f"{self.base_url}/user/login", json={"username": "u1", "password": "p1"}
        )
        token = self._extract_data(login.json())["token"]

        # Parameters should be passed as query string
        params: dict[str, str | int] = {"name": "Bob", "age": 40}
        response = requests.get(
            f"{self.base_url}/function/get_func_with_params",
            headers={"Authorization": f"Bearer {token}"},
            params=params,
            timeout=5,
        )
        assert response.status_code == 200
        data = self._extract_data(response.json())
        assert data["result"]["message"] == "get_func_with_params executed"
        assert data["result"]["name"] == "Bob"
        assert data["result"]["age"] == 40

    def test_openapi_specs(self) -> None:
        """Verify OpenAPI documentation reflects custom paths and methods."""
        spec = requests.get(f"{self.base_url}/openapi.json").json()
        paths = spec["paths"]

        assert "/custom/walker" in paths
        assert "get" in paths["/custom/walker"]

        assert "/custom/func" in paths
        assert "get" in paths["/custom/func"]

        assert "/walker/GetWalker" in paths
        assert "get" in paths["/walker/GetWalker"]
        assert "post" not in paths["/walker/GetWalker"]

        assert "/walker/PostWalker" in paths
        assert "post" in paths["/walker/PostWalker"]
        assert "get" not in paths["/walker/PostWalker"]

        assert "/walker/DefaultWalker" in paths
        assert "post" in paths["/walker/DefaultWalker"]
        assert "get" not in paths["/walker/DefaultWalker"]
