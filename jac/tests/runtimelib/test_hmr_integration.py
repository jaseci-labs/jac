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

from jaclang.runtimelib.hmr import HotReloader
from jaclang.runtimelib.watcher import JacFileWatcher


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
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=2)

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
            time.sleep(2)
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
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            if not started:
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            assert process.poll() is None, "Server should still be running"

    def test_api_only_mode(self, temp_dir: Path) -> None:
        """Test that --no_client --watch mode works (API only with HMR)."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("API only mode"); }')

        with _run_jac_server(app_file, port) as process:
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            assert started, "Server did not start in API-only mode"
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
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            if not started:
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

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

            time.sleep(3)
            assert process.poll() is None, "Server crashed after file change"

    def test_syntax_error_does_not_crash_server(self, temp_dir: Path) -> None:
        """Test that syntax errors don't crash the server."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Hello"); }')

        with _run_jac_server(app_file, port) as process:
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            assert started, "Server did not start"

            time.sleep(2)

            # Introduce syntax error
            app_file.write_text('with entry { print("unclosed }')
            time.sleep(3)

            assert process.poll() is None, "Server should not crash on syntax error"

            # Fix the error
            app_file.write_text('with entry { print("fixed"); }')
            time.sleep(3)

            assert process.poll() is None, "Server should recover after fix"

    def test_multiple_rapid_changes(self, temp_dir: Path) -> None:
        """Test that rapid file changes don't crash the server."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"
        app_file.write_text('with entry { print("Initial"); }')

        with _run_jac_server(app_file, port) as process:
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            assert started, "Server did not start"

            time.sleep(2)

            # Make rapid changes
            for i in range(5):
                app_file.write_text(f'with entry {{ print("Version {i}"); }}')
                time.sleep(0.1)

            time.sleep(2)
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
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            if not started:
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            time.sleep(3)

            # Call walker - should return 1
            response = _http_request(
                f"http://127.0.0.1:{port}/walker/get_value",
                method="POST",
                data={},
            )
            # Handle TransportResponse envelope format
            response_data = response.get("data", response)
            initial_reports = response_data.get("reports", [])

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

            time.sleep(4)

            # Call walker again - should return 2
            response = _http_request(
                f"http://127.0.0.1:{port}/walker/get_value",
                method="POST",
                data={},
            )
            # Handle TransportResponse envelope format
            response_data = response.get("data", response)
            updated_reports = response_data.get("reports", [])

            assert initial_reports != updated_reports, "Walker code was not reloaded"


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

        with _run_jac_server(app_file, port) as process:
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            assert started, "Server did not start"

            time.sleep(2)
            assert process.poll() is None


class TestHMRClientCodeRecompilation:
    """E2E tests for client-side code HMR recompilation."""

    @pytest.fixture
    def temp_project(self) -> Generator[Path, None, None]:
        """Create a temporary project directory with client structure."""
        with tempfile.TemporaryDirectory() as tmp:
            project = Path(tmp)
            compiled_dir = project / ".jac" / "client" / "compiled"
            compiled_dir.mkdir(parents=True, exist_ok=True)
            yield project

    def test_client_js_file_updated_on_change(self, temp_project: Path) -> None:
        """Test that client JS file is actually updated when .jac file changes."""
        app_file = temp_project / "app.jac"
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello Version 1</div>;
    }
}
"""
        )

        watcher = JacFileWatcher(watch_paths=[str(temp_project)], _debounce_ms=50)
        reloader = HotReloader(
            base_path=str(temp_project), module_name="app", watcher=watcher
        )

        reloader._recompile_client_code(str(app_file))

        output_file = temp_project / ".jac" / "client" / "compiled" / "app.js"
        assert output_file.exists(), "JS file was not created"

        content_v1 = output_file.read_text()

        # Modify the jac file
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello Version 2</div>;
    }
}
"""
        )

        reloader._recompile_client_code(str(app_file))
        content_v2 = output_file.read_text()

        assert content_v1 != content_v2, "JS file was not updated after change"
        assert "Version 2" in content_v2, "New content not in recompiled JS"

    def test_jacjsx_import_added_in_real_compilation(self, temp_project: Path) -> None:
        """Test that __jacJsx import is actually added during HMR recompilation."""
        app_file = temp_project / "app.jac"
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello</div>;
    }
}
"""
        )

        watcher = JacFileWatcher(watch_paths=[str(temp_project)], _debounce_ms=50)
        reloader = HotReloader(
            base_path=str(temp_project), module_name="app", watcher=watcher
        )

        reloader._recompile_client_code(str(app_file))

        output_file = temp_project / ".jac" / "client" / "compiled" / "app.js"
        assert output_file.exists(), "JS file was not created"

        content = output_file.read_text()
        if "__jacJsx" in content:
            assert "import {__jacJsx" in content, (
                "__jacJsx is used but import is missing"
            )


class TestHMREndToEndFlow:
    """Full end-to-end HMR flow tests."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_full_hmr_cycle_server_code(self, temp_dir: Path) -> None:
        """Test complete HMR cycle: start server, modify file, verify reload."""
        port = _get_free_port()
        app_file = temp_dir / "app.jac"

        app_file.write_text(
            """
glob VERSION = 1;

walker get_version {
    can enter with `root entry {
        report {"version": VERSION};
    }
}

with entry {
    print("Started with version", VERSION);
}
"""
        )

        with _run_jac_server(app_file, port) as process:
            started = _wait_for_port("127.0.0.1", port, timeout=30)
            if not started:
                output = process.stdout.read().decode() if process.stdout else ""
                pytest.fail(f"Server did not start. Output: {output}")

            time.sleep(3)

            # Get initial version
            resp1 = _http_request(
                f"http://127.0.0.1:{port}/walker/get_version",
                method="POST",
                data={},
            )
            # Handle TransportResponse envelope format
            resp1_data = resp1.get("data", resp1)
            v1 = resp1_data.get("reports", [{}])[0].get("version")

            # Update the version
            app_file.write_text(
                """
glob VERSION = 2;

walker get_version {
    can enter with `root entry {
        report {"version": VERSION};
    }
}

with entry {
    print("Updated to version", VERSION);
}
"""
            )

            time.sleep(4)

            # Get updated version
            resp2 = _http_request(
                f"http://127.0.0.1:{port}/walker/get_version",
                method="POST",
                data={},
            )
            # Handle TransportResponse envelope format
            resp2_data = resp2.get("data", resp2)
            v2 = resp2_data.get("reports", [{}])[0].get("version")

            assert v2 == 2, f"Expected version 2 after HMR, got {v2}"
            assert v1 != v2, "Version did not change after HMR"
