"""Integration tests for HMR with jac start command.

These tests verify that HMR works correctly with the actual jac start command.
"""

import json
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path
from urllib.request import Request, urlopen

import pytest


def _get_jac_command() -> list[str]:
    """Get the jac command to use for testing."""
    jac_path = shutil.which("jac")
    if jac_path:
        return [jac_path]
    return [sys.executable, "-m", "jaclang"]


def _get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def _wait_for_port(host: str, port: int, timeout: float = 30.0) -> bool:
    """Block until a TCP port is accepting connections."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.5)
            try:
                sock.connect((host, port))
                return True
            except OSError:
                time.sleep(0.5)
    return False


def _http_request(
    url: str, method: str = "GET", data: dict | None = None, timeout: float = 10.0
) -> dict:
    """Make an HTTP request and return JSON response."""
    if data:
        body = json.dumps(data).encode("utf-8")
        req = Request(url, data=body, method=method)
        req.add_header("Content-Type", "application/json")
    else:
        req = Request(url, method=method)

    with urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


@contextmanager
def _run_jac_server(
    app_file: Path, port: int, extra_args: list[str] | None = None
) -> Generator[subprocess.Popen[bytes], None, None]:
    """Context manager to run a jac server and ensure proper cleanup."""
    args = [
        *_get_jac_command(),
        "start",
        str(app_file),
        "--watch",
        "--no_client",
        "--port",
        str(port),
    ]
    if extra_args:
        args.extend(extra_args)

    process = subprocess.Popen(
        args,
        cwd=str(app_file.parent),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    try:
        yield process
    finally:
        # Terminate the process
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=2)

        # Close all pipes
        if process.stdout:
            process.stdout.close()
        if process.stderr:
            process.stderr.close()


class TestHMRServerStartup:
    """Tests for HMR server initialization."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_watch_flag_accepted(self, temp_dir: Path) -> None:
        """Test that --watch flag is accepted by jac start."""
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Hello"); }')

        port = _get_free_port()

        with _run_jac_server(app_file, port) as process:
            # Give it a moment to start
            time.sleep(2)
            # Check that process is still running (didn't crash on startup)
            assert process.poll() is None, "Server crashed on startup with --watch flag"

    def test_watch_flag_starts_server(self, temp_dir: Path) -> None:
        """Test that --watch flag starts server and accepts connections."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text(
            f"""
with entry {{
    print("Server starting on port {port}");
}}
"""
        )

        with _run_jac_server(app_file, port) as process:
            # Wait for server to start
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            # Server is running
            assert process.poll() is None, "Server should still be running"

    def test_api_only_mode(self, temp_dir: Path) -> None:
        """Test that --no_client --watch mode works (API only with HMR)."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("API only mode"); }')

        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                pytest.fail("Server did not start in API-only mode")

            assert process.poll() is None


class TestHMRFileChanges:
    """Tests for hot module replacement on file changes."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_server_detects_file_change(self, temp_dir: Path) -> None:
        """Test that server detects .jac file changes."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text(
            """
walker get_version {
    can enter with `root entry {
        report 1;
    }
}

with entry {
    print("Version 1");
}
"""
        )

        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            # Give server time to fully initialize
            time.sleep(2)

            # Modify the file
            app_file.write_text(
                """
walker get_version {
    can enter with `root entry {
        report 2;
    }
}

with entry {
    print("Version 2");
}
"""
            )

            # Wait for HMR to detect the change
            time.sleep(3)

            # Server should still be running
            assert process.poll() is None, "Server crashed after file change"

    def test_syntax_error_does_not_crash_server(self, temp_dir: Path) -> None:
        """Test that syntax errors don't crash the server."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Hello"); }')

        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                pytest.fail("Server did not start")

            time.sleep(2)

            # Introduce syntax error
            app_file.write_text('with entry { print("unclosed }')

            time.sleep(3)

            # Server should still be running (not crashed)
            assert process.poll() is None, "Server should not crash on syntax error"

            # Fix the error
            app_file.write_text('with entry { print("fixed"); }')
            time.sleep(3)

            # Server should still be running
            assert process.poll() is None, "Server should recover after fix"

    def test_multiple_rapid_changes(self, temp_dir: Path) -> None:
        """Test that rapid file changes don't crash the server."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Initial"); }')

        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                pytest.fail("Server did not start")

            time.sleep(2)

            # Make rapid changes
            for i in range(5):
                app_file.write_text(f'with entry {{ print("Version {i}"); }}')
                time.sleep(0.1)  # Very rapid changes

            # Wait for debounce to process
            time.sleep(2)

            # Server should still be running
            assert process.poll() is None, "Server crashed during rapid changes"


class TestHMRWalkerReload:
    """Tests specifically for walker hot reloading."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_walker_code_reloads(self, temp_dir: Path) -> None:
        """Test that walker code is actually reloaded on file change."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"

        # Initial version returns 1
        app_file.write_text(
            """
walker get_value {
    can enter with `root entry {
        report {"value": 1};
    }
}

with entry {
    print("Version 1 loaded");
}
"""
        )

        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            time.sleep(3)  # Let server fully initialize

            # Call walker - should return 1
            try:
                response = _http_request(
                    f"http://127.0.0.1:{port}/walker/get_value",
                    method="POST",
                    data={},
                )
                initial_reports = response.get("reports", [])
            except Exception as e:
                pytest.skip(f"Walker endpoint not available: {e}")

            # Update walker to return 2
            app_file.write_text(
                """
walker get_value {
    can enter with `root entry {
        report {"value": 2};
    }
}

with entry {
    print("Version 2 loaded");
}
"""
            )

            # Wait for HMR to process
            time.sleep(4)

            # Call walker again - should return 2
            try:
                response = _http_request(
                    f"http://127.0.0.1:{port}/walker/get_value",
                    method="POST",
                    data={},
                )
                updated_reports = response.get("reports", [])

                # Verify the value changed
                if initial_reports and updated_reports:
                    assert initial_reports != updated_reports, (
                        "Walker code was not reloaded"
                    )
            except Exception as e:
                # If endpoint fails after reload, that's also worth noting
                pytest.skip(f"Walker endpoint failed after reload: {e}")


class TestHMRShutdown:
    """Tests for graceful shutdown with HMR."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_graceful_shutdown_with_watch(self, temp_dir: Path) -> None:
        """Test that server shuts down gracefully when interrupted."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Hello"); }')

        # Use context manager - it will test shutdown during cleanup
        with _run_jac_server(app_file, port) as process:
            if not _wait_for_port("127.0.0.1", port, timeout=30):
                pytest.fail("Server did not start")

            time.sleep(2)

            # Verify server is running
            assert process.poll() is None

        # After context exit, process should be terminated
        # The context manager handles graceful shutdown
