"""Test for running jac-scale examples and testing their APIs."""

import contextlib
import socket
import subprocess
import time
from pathlib import Path
from typing import Any

import requests

JacClientExamples = (
    Path(__file__).parent.parent.parent.parent
    / "jac-client"
    / "jac_client"
    / "examples"
)


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


class JacScaleTestRunner:
    """Helper class to run jac-scale examples and test their APIs."""

    def __init__(
        self, example_file: Path, session_name: str = "test", setup_npm: bool = True
    ):
        """Initialize the test runner.

        Args:
            example_file: Path to the .jac file to serve
            session_name: Name for the session file (default: "test")
            setup_npm: Whether to run npm install and setup src directory (default: True)
        """
        self.example_file = example_file
        self.port = get_free_port()
        self.base_url = f"http://localhost:{self.port}"
        self.session_file = example_file.parent / f"{session_name}_{self.port}.session"
        self.server_process: subprocess.Popen[str] | None = None
        self.token: str | None = None
        self.root_id: str | None = None
        self.setup_npm = setup_npm

    def start_server(self, timeout: int = 30) -> None:
        """Start the jac-scale server.

        Args:
            timeout: Maximum time to wait for server to start (in seconds)
        """
        example_dir = self.example_file.parent

        # Clean up directories before starting
        dirs_to_clean = ["build", "dist", "node_modules", "src"]
        for dir_name in dirs_to_clean:
            dir_path = example_dir / dir_name
            if dir_path.exists():
                subprocess.run(
                    ["rm", "-rf", dir_name],
                    cwd=example_dir,
                    check=False,
                )

        # Setup npm dependencies and src directory if needed
        if self.setup_npm:
            print(f"Setting up example directory: {example_dir}")

            # Run npm install
            npm_install = subprocess.run(
                ["jac", "add", "--cl"],
                cwd=example_dir,
                capture_output=True,
                text=True,
            )
            if npm_install.returncode != 0:
                print(f"npm install warning: {npm_install.stderr}")

            # Create src directory
            subprocess.run(
                ["mkdir", "src"],
                cwd=example_dir,
                check=True,
            )
            print("Example directory setup complete")

        cmd = [
            "jac",
            "serve",
            str(self.example_file),
            # "--session",
            # str(self.session_file),
            "--port",
            str(self.port),
        ]

        self.server_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=example_dir,  # Run from example directory
        )

        # Wait for server to be ready
        max_attempts = timeout * 5  # Check every 0.2 seconds
        server_ready = False

        for _ in range(max_attempts):
            # Check if process has died
            if self.server_process.poll() is not None:
                stdout, stderr = self.server_process.communicate()
                raise RuntimeError(
                    f"Server process terminated unexpectedly.\n"
                    f"STDOUT: {stdout}\nSTDERR: {stderr}"
                )

            try:
                response = requests.get(f"{self.base_url}/docs", timeout=2)
                if response.status_code in (200, 404):
                    print(f"Server started on port {self.port}")
                    server_ready = True
                    break
            except (requests.ConnectionError, requests.Timeout):
                time.sleep(0.2)

        if not server_ready:
            self.stop_server()
            raise RuntimeError(f"Server failed to start after {timeout} seconds")

    def stop_server(self) -> None:
        """Stop the jac-scale server and clean up session files."""
        if self.server_process:
            self.server_process.terminate()
            try:
                self.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.server_process.kill()
                self.server_process.wait()

            # Close the pipes to avoid ResourceWarning
            if self.server_process.stdout:
                self.server_process.stdout.close()
            if self.server_process.stderr:
                self.server_process.stderr.close()

        # Clean up session files
        if self.session_file.exists():
            session_dir = self.session_file.parent
            prefix = self.session_file.name

            for file in session_dir.iterdir():
                if file.name.startswith(prefix):
                    with contextlib.suppress(Exception):
                        file.unlink()

        # Clean up directories after stopping
        example_dir = self.example_file.parent
        dirs_to_clean = ["build", "dist", "node_modules", "src", "package-lock.json"]
        for dir_name in dirs_to_clean:
            dir_path = example_dir / dir_name
            if dir_path.exists():
                subprocess.run(
                    ["rm", "-rf", dir_name],
                    cwd=example_dir,
                    check=False,
                )

    def create_user(self, username: str, password: str) -> dict[str, Any]:
        """Create a new user and store the token.

        Args:
            username: Username for the new user
            password: Password for the new user

        Returns:
            User creation response
        """
        result = self.request(
            "POST", "/user/create", data={"username": username, "password": password}
        )
        self.token = result.get("token")
        self.root_id = result.get("root_id")
        return result

    def login(self, username: str, password: str) -> dict[str, Any]:
        """Login as an existing user and store the token.

        Args:
            username: Username
            password: Password

        Returns:
            Login response
        """
        result = self.request(
            "POST", "/user/login", data={"username": username, "password": password}
        )
        self.token = result.get("token")
        self.root_id = result.get("root_id")
        return result

    def request(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        use_token: bool = False,
        timeout: int = 5,
    ) -> dict[str, Any]:
        """Make an HTTP request to the server.

        Args:
            method: HTTP method (GET, POST, etc.)
            path: API path (e.g., "/walker/CreateTask")
            data: Request body data
            use_token: Whether to include authentication token
            timeout: Request timeout in seconds

        Returns:
            Response JSON data
        """
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}

        if use_token and self.token:
            headers["Authorization"] = f"Bearer {self.token}"

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
            return json_response[1]  # type: ignore[return-value]

        return json_response  # type: ignore[return-value]

    def request_raw(
        self,
        method: str,
        path: str,
        data: dict[str, Any] | None = None,
        use_token: bool = False,
        timeout: int = 10,
    ) -> str:
        """Make a raw HTTP request to the server.

        Args:
            method: HTTP method (GET, POST, etc.)
            path: API path (e.g., "/walker/CreateTask")
            data: Request body data
            use_token: Whether to include authentication token
            timeout: Request timeout in seconds

        Returns:
            Response JSON data
        """
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}

        if use_token and self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        response = requests.request(
            method=method,
            url=url,
            json=data,
            headers=headers,
            timeout=timeout,
        )

        return response.text

    def spawn_walker(
        self, walker_name: str, **kwargs: dict[str, Any]
    ) -> dict[str, Any]:
        """Spawn a walker with the given parameters.

        Args:
            walker_name: Name of the walker to spawn
            **kwargs: Walker field values

        Returns:
            Walker execution response
        """
        return self.request(
            "POST", f"/walker/{walker_name}", data=kwargs, use_token=True
        )

    def call_function(
        self, function_name: str, **kwargs: dict[str, Any]
    ) -> dict[str, Any]:
        """Call a function with the given parameters.

        Args:
            function_name: Name of the function to call
            **kwargs: Function parameter values

        Returns:
            Function result
        """
        # Build query string from kwargs
        query_params = "&".join(f"{k}={v}" for k, v in kwargs.items())
        path = f"/function/{function_name}"
        if query_params:
            path += f"?{query_params}"

        return self.request("GET", path, use_token=True)

    def __enter__(self) -> "JacScaleTestRunner":
        """Context manager entry."""
        self.start_server()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: object | None,
    ) -> None:
        """Context manager exit."""
        self.stop_server()


class TestJacClientExamples:
    """Template for testing custom examples."""

    def test_all_in_one(self) -> None:
        """Test a custom example file."""
        # Point to your example file
        example_file = JacClientExamples / "all-in-one" / "app.jac"
        with JacScaleTestRunner(
            example_file, session_name="custom_test", setup_npm=True
        ) as runner:
            assert "background-image" in runner.request_raw("GET", "/styles.css")
            assert "PNG" in runner.request_raw("GET", "/static/assets/burger.png")
            assert "/static/client.js" in runner.request_raw("GET", "/page/app")
            assert (
                runner.request_raw("GET", "/static/client.js")
                != "Static file not found"
            )
            assert (
                runner.request_raw("GET", "/static/client.jss")
                == "Static file not found"
            )

    def test_js_styling(self) -> None:
        """Test JS and styling example file."""
        # Point to your example file
        example_file = JacClientExamples / "css-styling" / "js-styling" / "app.jac"
        with JacScaleTestRunner(
            example_file, session_name="js_styling_test", setup_npm=True
        ) as runner:
            assert "const countDisplay" in runner.request_raw("GET", "/styles.js")
            assert "/static/client.js" in runner.request_raw("GET", "/page/app")

    def test_material_ui(self) -> None:
        """Test Material-UI styling example."""
        example_file = JacClientExamples / "css-styling" / "material-ui" / "app.jac"
        with JacScaleTestRunner(
            example_file, session_name="material_ui_test", setup_npm=True
        ) as runner:
            assert "/static/client.js" in runner.request_raw("GET", "/page/app")

    def test_pure_css(self) -> None:
        """Test Pure CSS example."""
        example_file = JacClientExamples / "css-styling" / "pure-css" / "app.jac"
        with JacScaleTestRunner(
            example_file, session_name="pure_css_test", setup_npm=True
        ) as runner:
            page_content = runner.request_raw("GET", "/page/app")
            assert "/static/client.js" in page_content
            assert ".container {" in runner.request_raw("GET", "/styles.css")

    def test_styled_components(self) -> None:
        """Test Styled Components example."""
        example_file = (
            JacClientExamples / "css-styling" / "styled-components" / "app.jac"
        )
        with JacScaleTestRunner(
            example_file, session_name="styled_components_test", setup_npm=True
        ) as runner:
            assert "/static/client.js" in runner.request_raw("GET", "/page/app")
            assert "import styled from" in runner.request_raw("GET", "/styled.js")
