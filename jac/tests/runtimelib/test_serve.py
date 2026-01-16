"""Test for jac start command and REST API server."""

import contextlib
import json
import os
import socket
import threading
import time
from collections.abc import Generator
from http.server import HTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from jaclang.runtimelib.server import JacAPIServer, UserManager
from tests.conftest import proc_file_sess
from tests.runtimelib.conftest import fixture_abs_path


@pytest.fixture(autouse=True)
def reset_machine(tmp_path: Path) -> Generator[None, None, None]:
    """Reset Jac machine before and after each test for session isolation."""
    # Use tmp_path for session isolation in parallel tests
    Jac.reset_machine(base_path=str(tmp_path))
    yield
    Jac.reset_machine(base_path=str(tmp_path))


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def del_session(session_file: str) -> None:
    """Delete session files including related database files."""
    session_path = Path(session_file)
    # Delete the session file itself
    if session_path.exists():
        session_path.unlink()
    # Delete related database files (SQLite WAL mode creates additional files)
    for suffix in [".db", ".db-wal", ".db-shm"]:
        related = session_path.with_suffix(suffix)
        if related.exists():
            related.unlink()


class ServerFixture:
    """Server fixture helper class."""

    def __init__(
        self, request: pytest.FixtureRequest, tmp_path: Path | None = None
    ) -> None:
        """Initialize server fixture."""

        self.server: JacAPIServer | None = None
        self.server_thread: threading.Thread | None = None
        self.httpd: HTTPServer | None = None
        try:
            self.port = get_free_port()
        except PermissionError:
            pytest.skip("Socket operations are not permitted in this environment")
        self.base_url = f"http://localhost:{self.port}"
        test_name = request.node.name
        # Use tmp_path for session isolation in parallel tests
        if tmp_path:
            self.session_dir = tmp_path
            self.session_file = str(tmp_path / f"test_serve_{test_name}.session")
        else:
            self.session_dir = Path(fixture_abs_path(""))
            self.session_file = fixture_abs_path(f"test_serve_{test_name}.session")

        # Clean up any leftover session files from previous runs
        del_session(self.session_file)

    def start_server(self, api_file: str = "serve_api.jac") -> None:
        """Start the API server in a background thread."""
        # Load the module with isolated base_path for persistence
        base, mod, mach = proc_file_sess(
            fixture_abs_path(api_file), str(self.session_dir)
        )
        Jac.jac_import(
            target=mod,
            base_path=base,
            override_name="__main__",
            lng="jac",
        )

        # Create server with same base path
        self.server = JacAPIServer(
            module_name="__main__",
            port=self.port,
            base_path=str(self.session_dir),
        )

        # Use the HTTPServer created by JacAPIServer
        self.httpd = self.server.server

        # Start server in thread
        def run_server():
            try:
                self.server.load_module()
                self.httpd.serve_forever()
            except Exception:
                pass

        self.server_thread = threading.Thread(target=run_server, daemon=True)
        self.server_thread.start()

        # Wait for server to be ready
        max_attempts = 50
        for _ in range(max_attempts):
            try:
                self.request("GET", "/", timeout=10)
                break
            except Exception:
                time.sleep(0.1)

    def request(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> dict:
        """Make HTTP request to server."""
        status, payload, _ = self.request_raw(
            method, path, data=data, token=token, timeout=timeout
        )
        try:
            return json.loads(payload)
        except json.JSONDecodeError as exc:
            raise AssertionError(f"Expected JSON response, got: {payload}") from exc

    def request_raw(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> tuple[int, str, dict[str, str]]:
        """Make an HTTP request and return status, body, and headers."""
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}

        if token:
            headers["Authorization"] = f"Bearer {token}"

        body = json.dumps(data).encode() if data else None
        request = Request(url, data=body, headers=headers, method=method)

        try:
            with urlopen(request, timeout=timeout) as response:
                payload = response.read().decode()
                return response.status, payload, dict(response.headers)
        except HTTPError as e:
            payload = e.read().decode()
            return e.code, payload, dict(e.headers)

    def cleanup(self) -> None:
        """Clean up server resources."""
        # Close user manager if it exists
        if self.server and hasattr(self.server, "user_manager"):
            with contextlib.suppress(Exception):
                self.server.user_manager.close()

        # Stop server if running
        if self.httpd:
            try:
                self.httpd.shutdown()
                self.httpd.server_close()
            except Exception:
                pass

        # Wait for thread to finish
        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=2)

        # tmp_path is automatically cleaned up by pytest


@pytest.fixture
def server_fixture(
    request: pytest.FixtureRequest, tmp_path: Path
) -> Generator[ServerFixture, None, None]:
    """Pytest fixture for server setup and teardown."""
    fixture = ServerFixture(request, tmp_path)
    yield fixture
    fixture.cleanup()


# Tests for TestServeCommand


def test_user_manager_creation(server_fixture: ServerFixture) -> None:
    """Test UserManager creates users with unique roots."""
    user_mgr = UserManager(server_fixture.session_file)

    # Create first user
    result1 = user_mgr.create_user("user1", "pass1")
    assert "token" in result1
    assert "root_id" in result1
    assert result1["username"] == "user1"

    # Create second user
    result2 = user_mgr.create_user("user2", "pass2")
    assert "token" in result2
    assert "root_id" in result2

    # Users should have different roots
    assert result1["root_id"] != result2["root_id"]

    # Duplicate username should fail
    result3 = user_mgr.create_user("user1", "pass3")
    assert "error" in result3


def test_user_manager_authentication(server_fixture: ServerFixture) -> None:
    """Test UserManager authentication."""
    user_mgr = UserManager(server_fixture.session_file)

    # Create user
    create_result = user_mgr.create_user("testuser", "testpass")
    create_data = create_result.get("data", create_result)

    original_token = create_data["token"]

    # Authenticate with correct credentials
    auth_result = user_mgr.authenticate("testuser", "testpass")
    assert auth_result is not None
    assert auth_result["username"] == "testuser"
    assert auth_result["token"] == original_token

    # Wrong password
    auth_fail = user_mgr.authenticate("testuser", "wrongpass")
    assert auth_fail is None

    # Nonexistent user
    auth_fail2 = user_mgr.authenticate("nouser", "pass")
    assert auth_fail2 is None


def test_user_manager_token_validation(server_fixture: ServerFixture) -> None:
    """Test UserManager token validation."""
    user_mgr = UserManager(server_fixture.session_file)

    # Create user
    result = user_mgr.create_user("validuser", "validpass")
    data = result.get("data", result)

    token = data["token"]

    # Valid token
    username = user_mgr.validate_token(token)
    assert username == "validuser"

    # Invalid token
    username = user_mgr.validate_token("invalid_token")
    assert username is None


def test_server_user_creation(server_fixture: ServerFixture) -> None:
    """Test user creation endpoint."""
    server_fixture.start_server()

    # Create user
    result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "alice", "password": "secret123"},
    )

    data = result.get("data", result)
    assert "username" in data
    assert "token" in data
    assert "root_id" in data
    assert data["username"] == "alice"


def test_server_user_login(server_fixture: ServerFixture) -> None:
    """Test user login endpoint."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "bob", "password": "pass456"}
    )

    # Login with correct credentials
    login_result = server_fixture.request(
        "POST", "/user/login", {"username": "bob", "password": "pass456"}
    )

    create_data = create_result.get("data", create_result)
    login_data = login_result.get("data", login_result)
    assert "token" in login_data
    assert login_data["username"] == "bob"
    assert login_data["root_id"] == create_data["root_id"]

    # Login with wrong password
    login_fail = server_fixture.request(
        "POST", "/user/login", {"username": "bob", "password": "wrongpass"}
    )

    assert "error" in login_fail


def test_server_authentication_required(server_fixture: ServerFixture) -> None:
    """Test that protected endpoints require authentication."""
    server_fixture.start_server()

    # Try to access protected endpoint without token
    result = server_fixture.request("GET", "/protected")
    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "error" in data
    assert "Unauthorized" in data["error"]


def test_server_list_functions(server_fixture: ServerFixture) -> None:
    """Test listing functions endpoint."""
    server_fixture.start_server()

    # Create user and get token
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "funcuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # List functions
    result = server_fixture.request("GET", "/functions", token=token)

    data = result.get("data", result)
    assert "functions" in data
    assert "add_numbers" in data["functions"]
    assert "greet" in data["functions"]


def test_server_get_function_signature(server_fixture: ServerFixture) -> None:
    """Test getting function signature."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "siguser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # Get signature
    result = server_fixture.request("GET", "/function/add_numbers", token=token)

    data = result.get("data", result)
    assert "signature" in data
    sig = data["signature"]
    assert "parameters" in sig
    assert "a" in sig["parameters"]
    assert "b" in sig["parameters"]
    assert sig["parameters"]["a"]["required"] is True
    assert sig["parameters"]["b"]["required"] is True


def test_server_call_function(server_fixture: ServerFixture) -> None:
    """Test calling a function endpoint."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "calluser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # Call add_numbers
    result = server_fixture.request(
        "POST", "/function/add_numbers", {"args": {"a": 10, "b": 25}}, token=token
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data
    assert data["result"] == 35

    # Call greet
    result2 = server_fixture.request(
        "POST", "/function/greet", {"args": {"name": "World"}}, token=token
    )

    data2 = result2.get("data", result2)
    assert "result" in data2
    assert data2["result"] == "Hello, World!"


def test_server_call_function_with_defaults(server_fixture: ServerFixture) -> None:
    """Test calling function with default parameters."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "defuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # Call greet without name (should use default)
    result = server_fixture.request(
        "POST", "/function/greet", {"args": {}}, token=token
    )

    data = result.get("data", result)
    assert "result" in data
    assert data["result"] == "Hello, World!"


def test_server_list_walkers(server_fixture: ServerFixture) -> None:
    """Test listing walkers endpoint."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "walkuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # List walkers
    result = server_fixture.request("GET", "/walkers", token=token)

    data = result.get("data", result)
    assert "walkers" in data
    assert "CreateTask" in data["walkers"]
    assert "ListTasks" in data["walkers"]
    assert "CompleteTask" in data["walkers"]


def test_server_get_walker_info(server_fixture: ServerFixture) -> None:
    """Test getting walker information."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "infouser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # Get walker info
    result = server_fixture.request("GET", "/walker/CreateTask", token=token)

    data = result.get("data", result)
    assert "info" in data
    info = data["info"]
    assert "fields" in info
    assert "title" in info["fields"]
    assert "priority" in info["fields"]
    assert "_jac_spawn_node" in info["fields"]

    # Check that priority has a default
    assert info["fields"]["priority"]["required"] is False
    assert info["fields"]["priority"]["default"] is not None


def test_server_spawn_walker(server_fixture: ServerFixture) -> None:
    """Test spawning a walker."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "spawnuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]
    # Spawn CreateTask walker
    result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Test Task", "priority": 2},
        token=token,
    )
    data = result.get("data", result)
    jid = data.get("reports", [{}])[0].get("_jac_id", "")

    # If error, print for debugging
    if "error" in result:
        print(f"\nWalker spawn error: {result['error']}")
        if "traceback" in result:
            print(f"Traceback:\n{result['traceback']}")

    assert "result" in data or "reports" in data

    # Spawn ListTasks walker to verify task was created
    result2 = server_fixture.request("POST", "/walker/ListTasks", {}, token=token)

    data2 = result2.get("data", result2)
    assert "result" in data2 or "reports" in data2

    # Get Task node using new GetTask walker
    result3 = server_fixture.request(
        "POST", "/walker/GetTask/" + str(jid), {}, token=token
    )
    data3 = result3.get("data", result3)
    assert "result" in data3 or "reports" in data3


def test_server_user_isolation(server_fixture: ServerFixture) -> None:
    """Test that users have isolated graph spaces."""
    server_fixture.start_server()

    # Create two users
    user1 = server_fixture.request(
        "POST", "/user/register", {"username": "user1", "password": "pass1"}
    )
    user2 = server_fixture.request(
        "POST", "/user/register", {"username": "user2", "password": "pass2"}
    )

    user1_data = user1.get("data", user1)
    user2_data = user2.get("data", user2)
    token1 = user1_data["token"]
    token2 = user2_data["token"]

    # User1 creates a task
    server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"fields": {"title": "User1 Task", "priority": 1}},
        token=token1,
    )

    # User2 creates a different task
    server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"fields": {"title": "User2 Task", "priority": 2}},
        token=token2,
    )

    # Both users should have different root IDs
    assert user1_data["root_id"] != user2_data["root_id"]


def test_server_invalid_function(server_fixture: ServerFixture) -> None:
    """Test calling nonexistent function."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "invaliduser", "password": "pass"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Try to call nonexistent function
    result = server_fixture.request(
        "POST", "/function/nonexistent", {"args": {}}, token=token
    )

    data = result.get("data", result)
    if data is None:
        # 404 response may not have data wrapper
        assert "error" in result
    else:
        assert "error" in data


def test_server_invalid_walker(server_fixture: ServerFixture) -> None:
    """Test spawning nonexistent walker."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "invalidwalk", "password": "pass"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Try to spawn nonexistent walker
    result = server_fixture.request(
        "POST", "/walker/NonExistentWalker", {"fields": {}}, token=token
    )

    data = result.get("data", result)
    if data is None:
        # 404 response may not have data wrapper
        assert "error" in result
    else:
        assert "error" in data


def test_server_imported_functions_and_walkers(server_fixture: ServerFixture) -> None:
    """Test that imported functions and walkers are available as API endpoints.

    This test verifies that when a Jac file imports functions and walkers from
    another module, those imported items are also converted to API endpoints
    alongside the locally defined ones.
    """
    server_fixture.start_server("serve_api_with_imports.jac")

    # Create user and get token
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "importuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)
    token = create_data["token"]

    # Test listing functions - should include both local and imported
    functions_result = server_fixture.request("GET", "/functions", token=token)
    # Handle TransportResponse envelope format
    functions_data = functions_result.get("data", functions_result)
    assert "functions" in functions_data
    functions = functions_data["functions"]

    # Local functions should be available
    assert "local_add" in functions, "Local function 'local_add' not found"
    assert "local_greet" in functions, "Local function 'local_greet' not found"

    # Imported functions should also be available
    assert "multiply_numbers" in functions, (
        "Imported function 'multiply_numbers' not found"
    )
    assert "format_message" in functions, "Imported function 'format_message' not found"

    # Test listing walkers - should include both local and imported
    walkers_result = server_fixture.request("GET", "/walkers", token=token)
    # Handle TransportResponse envelope format
    walkers_data = walkers_result.get("data", walkers_result)
    assert "walkers" in walkers_data
    walkers = walkers_data["walkers"]

    # Local walker should be available
    assert "LocalCreateTask" in walkers, "Local walker 'LocalCreateTask' not found"

    # Imported walkers should also be available
    assert "ImportedWalker" in walkers, "Imported walker 'ImportedWalker' not found"
    assert "ImportedCounter" in walkers, "Imported walker 'ImportedCounter' not found"

    # Test calling local function
    local_add_result = server_fixture.request(
        "POST", "/function/local_add", {"args": {"x": 5, "y": 3}}, token=token
    )
    # Handle TransportResponse envelope format
    local_add_data = local_add_result.get("data", local_add_result)
    assert "result" in local_add_data
    assert local_add_data["result"] == 8

    # Test calling imported function
    multiply_result = server_fixture.request(
        "POST", "/function/multiply_numbers", {"args": {"a": 4, "b": 7}}, token=token
    )
    # Handle TransportResponse envelope format
    multiply_data = multiply_result.get("data", multiply_result)
    assert "result" in multiply_data
    assert multiply_data["result"] == 28

    # Test calling another imported function
    format_result = server_fixture.request(
        "POST",
        "/function/format_message",
        {"args": {"prefix": "INFO", "message": "test"}},
        token=token,
    )
    # Handle TransportResponse envelope format
    format_data = format_result.get("data", format_result)
    assert "result" in format_data
    assert format_data["result"] == "INFO: test"

    # Test spawning local walker
    local_walker_result = server_fixture.request(
        "POST",
        "/walker/LocalCreateTask",
        {"task_title": "My Local Task"},
        token=token,
    )
    # Handle TransportResponse envelope format
    local_walker_data = local_walker_result.get("data", local_walker_result)
    assert "result" in local_walker_data or "reports" in local_walker_data
    if "reports" in local_walker_data:
        assert len(local_walker_data["reports"]) > 0

    # Test spawning imported walker
    imported_walker_result = server_fixture.request(
        "POST",
        "/walker/ImportedWalker",
        {"item_name": "Imported Item 1"},
        token=token,
    )
    # Handle TransportResponse envelope format
    imported_walker_data = imported_walker_result.get("data", imported_walker_result)
    assert "result" in imported_walker_data or "reports" in imported_walker_data
    if "reports" in imported_walker_data:
        assert len(imported_walker_data["reports"]) > 0


@pytest.mark.xfail(reason="Flaky: timing-dependent client bundle building")
def test_client_page_and_bundle_endpoints(server_fixture: ServerFixture) -> None:
    """Render a client page and fetch the bundled JavaScript."""
    server_fixture.start_server()

    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "pageuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Use longer timeout for page requests (they trigger bundle building)
    status, html_body, headers = server_fixture.request_raw(
        "GET", "/cl/client_page", token=token, timeout=15
    )

    assert status == 200
    assert "text/html" in headers.get("Content-Type", "")
    assert '<div id="__jac_root">' in html_body
    assert "Runtime Test" in html_body
    assert "/static/client.js?hash=" in html_body

    # Bundle should be cached from page request, but use longer timeout for CI safety
    status_js, js_body, js_headers = server_fixture.request_raw(
        "GET", "/static/client.js", timeout=15
    )
    assert status_js == 200
    assert "application/javascript" in js_headers.get("Content-Type", "")
    assert "function __jacJsx" in js_body


def test_server_root_endpoint(server_fixture: ServerFixture) -> None:
    """Test root endpoint returns API information."""
    server_fixture.start_server()

    result = server_fixture.request("GET", "/")

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "message" in data
    assert "endpoints" in data
    assert "POST /user/register" in data["endpoints"]
    assert "GET /functions" in data["endpoints"]
    assert "GET /walkers" in data["endpoints"]


def test_module_loading_and_introspection(server_fixture: ServerFixture) -> None:
    """Test that module loads correctly and introspection works."""
    # Load module with isolated base_path
    base, mod, mach = proc_file_sess(
        fixture_abs_path("serve_api.jac"), str(server_fixture.session_dir)
    )
    Jac.jac_import(
        target=mod,
        base_path=base,
        override_name="__main__",
        lng="jac",
    )

    # Create server
    server = JacAPIServer(
        module_name="__main__",
        port=9999,  # Different port, won't actually start
        base_path=str(server_fixture.session_dir),
    )
    server.load_module()

    # Check module loaded
    assert server.module is not None

    # Check functions discovered
    functions = server.get_functions()
    assert "add_numbers" in functions
    assert "greet" in functions

    # Check walkers discovered
    walkers = server.get_walkers()
    assert "CreateTask" in walkers
    assert "ListTasks" in walkers
    assert "CompleteTask" in walkers

    # Check introspection
    sig = server.introspect_callable(functions["add_numbers"])
    assert "parameters" in sig
    assert "a" in sig["parameters"]
    assert "b" in sig["parameters"]

    # Check walker introspection
    walker_info = server.introspect_walker(walkers["CreateTask"])
    assert "fields" in walker_info
    assert "title" in walker_info["fields"]
    assert "priority" in walker_info["fields"]

    # Clean up server socket
    server.user_manager.close()
    if server.server:
        server.server.server_close()
    mach.close()


def test_csr_mode_empty_root(server_fixture: ServerFixture) -> None:
    """Test CSR mode returns empty __jac_root for client-side rendering."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "csruser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Request page in CSR mode using query parameter (longer timeout for bundle building)
    status, html_body, headers = server_fixture.request_raw(
        "GET", "/cl/client_page?mode=csr", token=token, timeout=15
    )

    assert status == 200
    assert "text/html" in headers.get("Content-Type", "")

    # In CSR mode, __jac_root should be empty (no SSR)
    assert '<div id="__jac_root"></div>' in html_body

    # But __jac_init__ and client.js should still be present
    assert '<script id="__jac_init__" type="application/json">' in html_body
    assert "/static/client.js?hash=" in html_body

    # __jac_init__ should still contain the function name and args
    assert '"function": "client_page"' in html_body


def test_csr_mode_with_server_default(server_fixture: ServerFixture) -> None:
    """render_client_page returns an empty shell when called directly."""
    # Load module with isolated base_path
    base, mod, mach = proc_file_sess(
        fixture_abs_path("serve_api.jac"), str(server_fixture.session_dir)
    )
    Jac.jac_import(
        target=mod,
        base_path=base,
        override_name="__main__",
        lng="jac",
    )

    # Create server
    server = JacAPIServer(
        module_name="__main__",
        port=9998,
        base_path=str(server_fixture.session_dir),
    )
    server.load_module()

    # Create a test user
    server.user_manager.create_user("testuser", "testpass")

    # Call render_client_page (always CSR)
    result = server.render_client_page(
        function_name="client_page",
        args={},
        username="testuser",
    )

    # Should have empty HTML body (CSR mode)
    assert "html" in result
    html_content = result.get("data", result)["html"]
    assert '<div id="__jac_root"></div>' in html_content

    # Clean up server socket
    server.user_manager.close()
    if server.server:
        server.server.server_close()
    mach.close()


def test_root_data_persistence_across_server_restarts(
    server_fixture: ServerFixture,
) -> None:
    """Test that user data and graph persist across server restarts.

    This test verifies that both user credentials and graph data (nodes and
    edges attached to a root) are properly persisted to the session file and
    can be accessed after a server restart.
    """
    # Start first server instance
    server_fixture.start_server()

    # Create user and get token
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "persistuser", "password": "testpass123"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]
    root_id = create_result.get("data", create_result)["root_id"]

    # Create multiple tasks on the root node
    task1_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 1", "priority": 1},
        token=token,
    )
    data1 = task1_result.get("data", task1_result)
    assert "result" in data1 or "reports" in data1

    task2_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 2", "priority": 2},
        token=token,
    )
    data2 = task2_result.get("data", task2_result)
    assert "result" in data2 or "reports" in data2

    task3_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 3", "priority": 3},
        token=token,
    )
    data3 = task3_result.get("data", task3_result)
    assert "result" in data3 or "reports" in data3

    # List tasks to verify they were created
    list_before = server_fixture.request("POST", "/walker/ListTasks", {}, token=token)
    list_before_data = list_before.get("data", list_before)
    assert "result" in list_before_data or "reports" in list_before_data

    # Shutdown first server instance
    # Close user manager first
    if server_fixture.server and hasattr(server_fixture.server, "user_manager"):
        server_fixture.server.user_manager.close()

    # Commit and close the ExecutionContext to release the shelf lock
    Jac.commit()
    Jac.get_context().close()

    if server_fixture.httpd:
        server_fixture.httpd.shutdown()
        server_fixture.httpd.server_close()
        server_fixture.httpd = None

    if server_fixture.server_thread and server_fixture.server_thread.is_alive():
        server_fixture.server_thread.join(timeout=2)

    # Wait a moment to ensure server is fully stopped
    time.sleep(0.5)

    # Start second server instance with the same session file
    server_fixture.start_server()

    # Login with the same credentials
    login_result = server_fixture.request(
        "POST",
        "/user/login",
        {"username": "persistuser", "password": "testpass123"},
    )

    # User should be able to log in successfully
    login_data = login_result.get("data", login_result)
    assert "token" in login_data
    assert login_result.get("error") is None

    new_token = login_data["token"]
    new_root_id = login_data["root_id"]

    # Root ID should be the same (same user, same root)
    assert new_root_id == root_id

    # Token should be the same (persisted from before)
    assert new_token == token

    # List tasks again to verify they persisted
    list_after = server_fixture.request(
        "POST", "/walker/ListTasks", {}, token=new_token
    )

    # The ListTasks walker should successfully run
    list_after_data = list_after.get("data", list_after)
    assert "result" in list_after_data or "reports" in list_after_data

    # Complete one of the tasks to verify we can still interact with persisted data
    complete_result = server_fixture.request(
        "POST",
        "/walker/CompleteTask",
        {"title": "Persistent Task 2"},
        token=new_token,
    )
    complete_data = complete_result.get("data", complete_result)
    assert "result" in complete_data or "reports" in complete_data


def test_client_bundle_has_object_get_polyfill(server_fixture: ServerFixture) -> None:
    """Test that client bundle includes Object.prototype.get polyfill."""
    server_fixture.start_server()

    # Pre-warm the bundle by requesting a page first (triggers bundle build)
    # This ensures the bundle is cached before we test it directly
    with contextlib.suppress(Exception):
        # Ignore errors, we just want to trigger bundle building
        server_fixture.request("GET", "/")

    # Fetch the client bundle with longer timeout for CI environments
    # Bundle building can be slow on CI runners with limited resources
    status, js_body, headers = server_fixture.request_raw(
        "GET", "/static/client.js", timeout=15
    )

    assert status == 200
    assert "application/javascript" in headers.get("Content-Type", "")

    # Verify core runtime functions are present
    assert "__jacJsx" in js_body
    assert "__jacRegisterClientModule" in js_body


def test_login_form_renders_with_correct_elements(
    server_fixture: ServerFixture,
) -> None:
    """Test that client page renders with correct HTML elements via HTTP endpoint."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "formuser", "password": "pass"}
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Request the client_page endpoint (longer timeout for bundle building)
    status, html_body, headers = server_fixture.request_raw(
        "GET", "/cl/client_page", token=token, timeout=15
    )

    assert status == 200
    assert "text/html" in headers.get("Content-Type", "")

    # Check basic HTML structure
    assert "<!DOCTYPE html>" in html_body
    assert '<div id="__jac_root">' in html_body
    assert '<script id="__jac_init__"' in html_body
    assert "/static/client.js?hash=" in html_body

    # Verify __jac_init__ contains the right function and global
    assert '"function": "client_page"' in html_body
    assert '"WELCOME_TITLE": "Runtime Test"' in html_body  # Global variable

    # Fetch and verify the bundle (should be cached from page request, but use longer timeout for CI)
    status_js, js_body, _ = server_fixture.request_raw(
        "GET", "/static/client.js", timeout=15
    )
    assert status_js == 200

    # Verify the bundle has the polyfill setup function (now part of client_runtime.cl.jac)
    assert "__jacEnsureObjectGetPolyfill" in js_body

    # Verify the function is in the bundle
    assert "function client_page" in js_body


def test_default_page_is_csr(server_fixture: ServerFixture) -> None:
    """Test that the default page response is CSR (client-side rendering)."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "csrdefaultuser", "password": "pass"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Request page WITHOUT specifying mode (should use default, longer timeout for bundle building)
    status, html_body, headers = server_fixture.request_raw(
        "GET", "/cl/client_page", token=token, timeout=15
    )

    assert status == 200
    assert "text/html" in headers.get("Content-Type", "")

    # In CSR mode (default), __jac_root should be empty
    assert '<div id="__jac_root"></div>' in html_body

    # Should NOT contain pre-rendered content
    # (The content will be rendered on the client side)
    # Note: We check that the root div is completely empty
    import re

    root_match = re.search(r'<div id="__jac_root">(.*?)</div>', html_body)
    assert root_match is not None
    root_content = root_match.group(1)
    assert root_content == ""  # Should be empty string

    # __jac_init__ and client.js should still be present for hydration
    assert '<script id="__jac_init__" type="application/json">' in html_body
    assert "/static/client.js?hash=" in html_body

    # Verify that explicitly requesting SSR mode is ignored (still CSR, longer timeout for bundle building)
    status_ssr, html_ssr, _ = server_fixture.request_raw(
        "GET", "/cl/client_page?mode=ssr", token=token, timeout=15
    )
    assert status_ssr == 200

    assert '<div id="__jac_root"></div>' in html_ssr


def test_faux_flag_prints_endpoint_docs(server_fixture: ServerFixture) -> None:
    """Test that --faux flag prints endpoint documentation without starting server."""
    import io
    from contextlib import redirect_stdout

    # Set base_path to server_fixture's session_dir for isolation
    Jac.set_base_path(str(server_fixture.session_dir))

    # Capture stdout
    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            # Call start with faux=True
            execution.start(
                filename=fixture_abs_path("serve_api.jac"),
                port=server_fixture.port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass  # start() may call exit() in some error cases

    output = captured_output.getvalue()

    # Verify function endpoints are documented
    assert "FUNCTIONS" in output
    assert "/function/add_numbers" in output
    assert "/function/greet" in output

    # Verify walker endpoints are documented
    assert "WALKERS" in output
    assert "/walker/CreateTask" in output
    assert "/walker/ListTasks" in output
    assert "/walker/CompleteTask" in output

    # Verify client page endpoints section is documented
    assert "CLIENT PAGES" in output
    assert "client_page" in output

    # Verify summary is present
    assert "TOTAL:" in output
    # Note: With imported functions now exposed as endpoints, we have more than the 2 defined functions
    assert "10 functions" in output
    assert "4 walkers" in output
    assert "34 endpoints" in output

    # Verify parameter details are included
    assert "required" in output
    assert "optional" in output
    assert "Bearer token" in output


def test_faux_flag_with_littlex_example(server_fixture: ServerFixture) -> None:
    """Test that --faux flag correctly identifies functions, walkers, and endpoints in littleX example."""
    import io

    # Get the absolute path to littleX file
    import os
    from contextlib import redirect_stdout

    littlex_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../../../examples/littleX/littleX_single_nodeps.jac",
        )
    )

    # Skip test if file doesn't exist
    if not os.path.exists(littlex_path):
        pytest.skip(f"LittleX example not found at {littlex_path}")

    # Capture stdout
    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            # Call start with faux=True on littleX example
            execution.start(
                filename=littlex_path,
                session=server_fixture.session_file,
                port=server_fixture.port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass  # start() may call exit() in some error cases

    output = captured_output.getvalue()

    assert "littleX_single_nodeps" in output
    assert "0 functions" in output
    assert "15 walkers" in output
    assert "36 endpoints" in output

    # Verify some specific walker endpoints are documented
    assert "/walker/visit_profile" in output
    assert "/walker/create_tweet" in output
    assert "/walker/load_feed" in output
    assert "/walker/update_profile" in output

    # Verify authentication and introspection endpoints are still present
    assert "/user/register" in output
    assert "Available" in output
    assert "1 client functions" in output  # 15 client functions
    # Verify some client functions are listed
    assert "App" in output
    assert "/cl/" in output


# Tests for TestAccessLevelAuthentication


@pytest.fixture
def access_server_fixture(
    request: pytest.FixtureRequest, tmp_path: Path
) -> Generator[ServerFixture, None, None]:
    """Pytest fixture for access level server setup and teardown."""
    fixture = ServerFixture(request, tmp_path)
    yield fixture
    fixture.cleanup()


def test_public_function_without_auth(access_server_fixture: ServerFixture) -> None:
    """Test that public functions can be called without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Call public function without authentication
    result = access_server_fixture.request(
        "POST", "/function/public_function", {"args": {"name": "Test"}}
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data
    assert data["result"] == "Hello, Test! (public)"


def test_public_function_get_info_without_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that public function info can be retrieved without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Get public function info without authentication
    result = access_server_fixture.request("GET", "/function/public_function")

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "signature" in data
    assert "parameters" in data["signature"]


def test_protected_function_requires_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that protected functions require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to call protected function without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/function/protected_function", {"args": {"message": "test"}}
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "error" in data
    assert "Unauthorized" in data["error"]


def test_protected_function_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected functions work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "authuser", "password": "pass123"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Call protected function with authentication
    result = access_server_fixture.request(
        "POST",
        "/function/protected_function",
        {"args": {"message": "secret"}},
        token=token,
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data
    assert data["result"] == "Protected: secret"


def test_private_function_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private functions require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to call private function without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/function/private_function", {"args": {"secret": "test"}}
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "error" in data
    assert "Unauthorized" in data["error"]


def test_private_function_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private functions work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "privuser", "password": "pass456"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Call private function with authentication
    result = access_server_fixture.request(
        "POST",
        "/function/private_function",
        {"args": {"secret": "topsecret"}},
        token=token,
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data
    assert data["result"] == "Private: topsecret"


def test_public_walker_without_auth(access_server_fixture: ServerFixture) -> None:
    """Test that public walkers can be spawned without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Spawn public walker without authentication
    result = access_server_fixture.request(
        "POST", "/walker/PublicWalker", {"message": "hello"}
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data or "reports" in data


def test_protected_walker_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected walkers require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to spawn protected walker without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/walker/ProtectedWalker", {"data": "test"}
    )

    data = result.get("data", result)
    assert "error" in data
    data = result.get("data", result)
    assert "Unauthorized" in data["error"]


def test_protected_walker_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected walkers work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "walkuser", "password": "pass789"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Spawn protected walker with authentication
    result = access_server_fixture.request(
        "POST",
        "/walker/ProtectedWalker",
        {"data": "mydata"},
        token=token,
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data or "reports" in data


def test_private_walker_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private walkers require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to spawn private walker without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/walker/PrivateWalker", {"secret": "test"}
    )

    data = result.get("data", result)
    assert "error" in data
    data = result.get("data", result)
    assert "Unauthorized" in data["error"]


def test_private_walker_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private walkers work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "privwalk", "password": "pass000"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Spawn private walker with authentication
    result = access_server_fixture.request(
        "POST",
        "/walker/PrivateWalker",
        {"secret": "verysecret"},
        token=token,
    )

    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "result" in data or "reports" in data


def test_introspection_list_requires_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that introspection list endpoints require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to list walkers without authentication - should fail
    result = access_server_fixture.request("GET", "/protected")
    # Handle TransportResponse envelope format
    data = result.get("data", result)
    assert "error" in data
    assert "Unauthorized" in data["error"]


def test_mixed_access_levels(access_server_fixture: ServerFixture) -> None:
    """Test server with mixed access levels (public, protected, private)."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create authenticated user
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "mixeduser", "password": "mixedpass"},
    )
    create_data = create_result.get("data", create_result)

    token = create_data["token"]

    # Public function without auth - should work
    result1 = access_server_fixture.request(
        "POST", "/function/public_add", {"args": {"a": 5, "b": 10}}
    )
    data1 = result1.get("data", result1)
    assert "result" in data1
    assert data1["result"] == 15

    # Protected function without auth - should fail
    result2 = access_server_fixture.request(
        "POST", "/function/protected_function", {"args": {"message": "test"}}
    )
    data2 = result2.get("data", result2)
    assert "error" in data2

    # Protected function with auth - should work
    result3 = access_server_fixture.request(
        "POST",
        "/function/protected_function",
        {"args": {"message": "test"}},
        token=token,
    )
    data3 = result3.get("data", result3)
    assert "result" in data3

    # Private function with auth - should work
    result4 = access_server_fixture.request(
        "POST",
        "/function/private_function",
        {"args": {"secret": "test"}},
        token=token,
    )
    data4 = result4.get("data", result4)
    assert "result" in data4


# Tests for CL Route Configuration with jac.toml


class ConfiguredServerFixture:
    """Server fixture that loads config from a jac.toml file."""

    def __init__(
        self, request: pytest.FixtureRequest, temp_dir: str, jac_toml_content: str
    ) -> None:
        """Initialize server fixture with custom jac.toml."""
        import shutil

        self.server: JacAPIServer | None = None
        self.server_thread: threading.Thread | None = None
        self.httpd: HTTPServer | None = None
        try:
            self.port = get_free_port()
        except PermissionError:
            pytest.skip("Socket operations are not permitted in this environment")
        self.base_url = f"http://localhost:{self.port}"
        test_name = request.node.name

        # Create temp directory with jac.toml and test jac file
        self.temp_dir = temp_dir
        self.project_dir = os.path.join(temp_dir, "test_project")
        os.makedirs(self.project_dir, exist_ok=True)

        # Write jac.toml
        with open(os.path.join(self.project_dir, "jac.toml"), "w") as f:
            f.write(jac_toml_content)

        # Copy serve_api.jac to the project directory
        src_file = fixture_abs_path("serve_api.jac")
        self.jac_file = os.path.join(self.project_dir, "serve_api.jac")
        shutil.copy(src_file, self.jac_file)

        self.session_file = os.path.join(self.project_dir, f"test_{test_name}.session")

    def start_server(self) -> None:
        """Start the API server in a background thread."""
        from jaclang.project.config import get_config, set_config

        # Reset config so it will be re-discovered from the project dir
        set_config(None)

        # Change to project directory so config is discovered
        original_cwd = os.getcwd()
        os.chdir(self.project_dir)

        try:
            # Force config re-discovery from the new directory
            get_config(force_discover=True)

            # Load the module with project_dir as base_path
            base, mod, mach = proc_file_sess(self.jac_file, self.project_dir)
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name="__main__",
                lng="jac",
            )

            # Create server
            self.server = JacAPIServer(
                module_name="__main__",
                port=self.port,
                base_path=self.project_dir,
            )

            # Use the HTTPServer created by JacAPIServer
            self.httpd = self.server.server

            # Start server in thread
            def run_server():
                try:
                    self.server.load_module()
                    self.httpd.serve_forever()
                except Exception:
                    pass

            self.server_thread = threading.Thread(target=run_server, daemon=True)
            self.server_thread.start()

            # Wait for server to be ready
            max_attempts = 50
            for _ in range(max_attempts):
                try:
                    self._request("GET", "/", timeout=10)
                    break
                except Exception:
                    time.sleep(0.1)
        finally:
            os.chdir(original_cwd)

    def _request(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> dict:
        """Make HTTP request to server."""
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        body = json.dumps(data).encode() if data else None
        req = Request(url, data=body, headers=headers, method=method)

        try:
            with urlopen(req, timeout=timeout) as response:
                return json.loads(response.read().decode())
        except HTTPError as e:
            return json.loads(e.read().decode())

    def request_raw(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> tuple[int, str, dict]:
        """Make HTTP request and return status, body, headers."""
        url = f"{self.base_url}{path}"
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        body = json.dumps(data).encode() if data else None
        req = Request(url, data=body, headers=headers, method=method)

        try:
            with urlopen(req, timeout=timeout) as response:
                return (
                    response.status,
                    response.read().decode(),
                    dict(response.headers),
                )
        except HTTPError as e:
            return e.code, e.read().decode(), dict(e.headers)

    def cleanup(self) -> None:
        """Stop server and cleanup."""
        from jaclang.project.config import set_config

        # Close user manager if it exists
        if self.server and hasattr(self.server, "user_manager"):
            with contextlib.suppress(Exception):
                self.server.user_manager.close()

        # Commit and close the ExecutionContext
        with contextlib.suppress(Exception):
            Jac.commit()
            Jac.get_context().close()

        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()
        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=2)
        set_config(None)
        # temp_dir is automatically cleaned up by tempfile.TemporaryDirectory


def test_cl_route_prefix_from_jac_toml(request: pytest.FixtureRequest) -> None:
    """Test that cl_route_prefix from jac.toml changes the CL app route."""
    import tempfile

    jac_toml = """
[project]
name = "route-prefix-test"
version = "0.1.0"

[serve]
cl_route_prefix = "pages"
"""

    with tempfile.TemporaryDirectory() as temp_dir:
        fixture = ConfiguredServerFixture(request, temp_dir, jac_toml)
        try:
            fixture.start_server()

            # The root endpoint should show the custom route prefix
            result = fixture._request("GET", "/")
            data = result.get("data", result)
            assert "endpoints" in data
            assert "GET /pages/<name>" in data["endpoints"]

            # Verify the default /cl/ route no longer works (404)
            status, _, _ = fixture.request_raw("GET", "/cl/client_page", timeout=5)
            assert status == 404

            # Verify the custom /pages/ route works
            status, html_body, headers = fixture.request_raw(
                "GET", "/pages/client_page", timeout=15
            )
            assert status == 200
            assert "text/html" in headers.get("Content-Type", "")
            assert '<div id="__jac_root">' in html_body
        finally:
            fixture.cleanup()


def test_base_route_app_from_jac_toml(request: pytest.FixtureRequest) -> None:
    """Test that base_route_app from jac.toml serves the app at /."""
    import tempfile

    jac_toml = """
[project]
name = "base-route-test"
version = "0.1.0"

[serve]
base_route_app = "client_page"
"""

    with tempfile.TemporaryDirectory() as temp_dir:
        fixture = ConfiguredServerFixture(request, temp_dir, jac_toml)
        try:
            fixture.start_server()

            # The root / should now serve the client_page app instead of API info
            status, html_body, headers = fixture.request_raw("GET", "/", timeout=15)
            assert status == 200
            assert "text/html" in headers.get("Content-Type", "")
            assert '<div id="__jac_root">' in html_body
            assert '"function": "client_page"' in html_body

            # The /cl/ route should still work
            status, html_body2, _ = fixture.request_raw(
                "GET", "/cl/client_page", timeout=15
            )
            assert status == 200
            assert '<div id="__jac_root">' in html_body2
        finally:
            fixture.cleanup()


def test_both_serve_options_from_jac_toml(request: pytest.FixtureRequest) -> None:
    """Test both cl_route_prefix and base_route_app from jac.toml work together."""
    import tempfile

    jac_toml = """
[project]
name = "combined-test"
version = "0.1.0"

[serve]
cl_route_prefix = "app"
base_route_app = "client_page"
"""

    with tempfile.TemporaryDirectory() as temp_dir:
        fixture = ConfiguredServerFixture(request, temp_dir, jac_toml)
        try:
            fixture.start_server()

            # Root / should serve the base_route_app
            status, html_body, headers = fixture.request_raw("GET", "/", timeout=15)
            assert status == 200
            assert "text/html" in headers.get("Content-Type", "")
            assert '"function": "client_page"' in html_body

            # Custom prefix /app/ should work
            status, html_body2, _ = fixture.request_raw(
                "GET", "/app/client_page", timeout=15
            )
            assert status == 200
            assert '<div id="__jac_root">' in html_body2

            # Default /cl/ should NOT work (404)
            status, _, _ = fixture.request_raw("GET", "/cl/client_page", timeout=5)
            assert status == 404
        finally:
            fixture.cleanup()


def test_start_with_default_main_jac(tmp_path: Path) -> None:
    """Test that jac start uses main.jac as default when available."""
    import io
    from contextlib import redirect_stderr

    main_jac = tmp_path / "main.jac"
    main_jac.write_text('with entry { "Hello from main.jac" :> print; }')

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            execution.start(
                filename="main.jac",
                port=get_free_port(),
                main=True,
                faux=True,
            )

        output = captured_output.getvalue()
        assert "not found" not in output.lower()
    finally:
        os.chdir(original_cwd)


def test_start_without_main_jac_error(tmp_path: Path) -> None:
    """Test that jac start provides helpful error when main.jac is missing."""
    import io
    from contextlib import redirect_stderr

    main_jac = tmp_path / "main.jac"
    if main_jac.exists():
        main_jac.unlink()

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            result = execution.start(
                filename="main.jac",
                port=get_free_port(),
                main=True,
                faux=True,
            )

        assert result == 1

        output = captured_output.getvalue()
        assert "main.jac" in output
        assert "not found" in output.lower()
        assert "Current directory" in output
        assert "Please specify a file" in output
    finally:
        os.chdir(original_cwd)


def test_start_with_explicit_file(server_fixture: ServerFixture) -> None:
    """Test that explicit filename still works (backward compatibility)."""
    import io
    from contextlib import redirect_stdout

    Jac.set_base_path(str(server_fixture.session_dir))

    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            execution.start(
                filename=fixture_abs_path("serve_api.jac"),
                port=server_fixture.port,
                main=True,
                faux=True,
            )
    except SystemExit:
        pass

    output = captured_output.getvalue()
    assert "FUNCTIONS" in output
    assert "/function/add_numbers" in output


def test_start_with_nonexistent_file_error(tmp_path: Path) -> None:
    """Test that jac start provides clear error for non-existent explicit file."""
    import io
    from contextlib import redirect_stderr

    original_cwd = os.getcwd()
    try:
        os.chdir(tmp_path)
        Jac.set_base_path(str(tmp_path))

        captured_output = io.StringIO()

        with redirect_stderr(captured_output):
            result = execution.start(
                filename="nonexistent.jac",
                port=get_free_port(),
                main=True,
                faux=True,
            )

        assert result == 1

        output = captured_output.getvalue()
        assert "nonexistent.jac" in output
        assert "not found" in output.lower()
        assert "Current directory" in output
        assert "Please specify a file" not in output
    finally:
        os.chdir(original_cwd)
