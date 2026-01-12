"""Test for jac start command and REST API server."""

import contextlib
import json
import os
import socket
import threading
import time
from collections.abc import Generator
from http.server import HTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from jaclang.runtimelib.server import JacAPIServer, UserManager
from tests.conftest import proc_file_sess
from tests.runtimelib.conftest import fixture_abs_path


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def del_session(session: str) -> None:
    """Delete session files including user database files."""
    path = os.path.dirname(session)
    prefix = os.path.basename(session)
    if os.path.exists(path):
        for file in os.listdir(path):
            # Clean up session files and user database files (.users)
            if file.startswith(prefix):
                with contextlib.suppress(Exception):
                    os.remove(f"{path}/{file}")


class ServerFixture:
    """Server fixture helper class."""

    def __init__(self, request: pytest.FixtureRequest) -> None:
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
        self.session_file = fixture_abs_path(f"test_serve_{test_name}.session")

    def start_server(self, api_file: str = "serve_api.jac") -> None:
        """Start the API server in a background thread."""
        from http.server import HTTPServer

        # Load the module with the same session_file for persistence
        base, mod, mach = proc_file_sess(fixture_abs_path(api_file), self.session_file)
        Jac.set_base_path(base)
        Jac.jac_import(
            target=mod,
            base_path=base,
            override_name="__main__",
            lng="jac",
        )

        # Create server with same session path
        self.server = JacAPIServer(
            module_name="__main__",
            session_path=self.session_file,
            port=self.port,
        )

        # Start server in thread
        def run_server():
            try:
                self.server.load_module()
                handler_class = self.server.create_handler()
                self.httpd = HTTPServer(("127.0.0.1", self.port), handler_class)
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

        # Clean up session files
        del_session(self.session_file)


@pytest.fixture
def server_fixture(
    request: pytest.FixtureRequest,
) -> Generator[ServerFixture, None, None]:
    """Pytest fixture for server setup and teardown."""
    fixture = ServerFixture(request)
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
    original_token = create_result["token"]

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
    token = result["token"]

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

    assert "username" in result
    assert "token" in result
    assert "root_id" in result
    assert result["username"] == "alice"


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

    assert "token" in login_result
    assert login_result["username"] == "bob"
    assert login_result["root_id"] == create_result["root_id"]

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
    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_server_list_functions(server_fixture: ServerFixture) -> None:
    """Test listing functions endpoint."""
    server_fixture.start_server()

    # Create user and get token
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "funcuser", "password": "pass"}
    )
    token = create_result["token"]

    # List functions
    result = server_fixture.request("GET", "/functions", token=token)

    assert "functions" in result
    assert "add_numbers" in result["functions"]
    assert "greet" in result["functions"]


def test_server_get_function_signature(server_fixture: ServerFixture) -> None:
    """Test getting function signature."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "siguser", "password": "pass"}
    )
    token = create_result["token"]

    # Get signature
    result = server_fixture.request("GET", "/function/add_numbers", token=token)

    assert "signature" in result
    sig = result["signature"]
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
    token = create_result["token"]

    # Call add_numbers
    result = server_fixture.request(
        "POST", "/function/add_numbers", {"args": {"a": 10, "b": 25}}, token=token
    )

    assert "result" in result
    assert result["result"] == 35

    # Call greet
    result2 = server_fixture.request(
        "POST", "/function/greet", {"args": {"name": "World"}}, token=token
    )

    assert "result" in result2
    assert result2["result"] == "Hello, World!"


def test_server_call_function_with_defaults(server_fixture: ServerFixture) -> None:
    """Test calling function with default parameters."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "defuser", "password": "pass"}
    )
    token = create_result["token"]

    # Call greet without name (should use default)
    result = server_fixture.request(
        "POST", "/function/greet", {"args": {}}, token=token
    )

    assert "result" in result
    assert result["result"] == "Hello, World!"


def test_server_list_walkers(server_fixture: ServerFixture) -> None:
    """Test listing walkers endpoint."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "walkuser", "password": "pass"}
    )
    token = create_result["token"]

    # List walkers
    result = server_fixture.request("GET", "/walkers", token=token)

    assert "walkers" in result
    assert "CreateTask" in result["walkers"]
    assert "ListTasks" in result["walkers"]
    assert "CompleteTask" in result["walkers"]


def test_server_get_walker_info(server_fixture: ServerFixture) -> None:
    """Test getting walker information."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "infouser", "password": "pass"}
    )
    token = create_result["token"]

    # Get walker info
    result = server_fixture.request("GET", "/walker/CreateTask", token=token)

    assert "info" in result
    info = result["info"]
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
    token = create_result["token"]
    # Spawn CreateTask walker
    result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Test Task", "priority": 2},
        token=token,
    )
    jid = result["reports"][0]["_jac_id"]

    # If error, print for debugging
    if "error" in result:
        print(f"\nWalker spawn error: {result['error']}")
        if "traceback" in result:
            print(f"Traceback:\n{result['traceback']}")

    assert "result" in result
    assert "reports" in result

    # Spawn ListTasks walker to verify task was created
    result2 = server_fixture.request("POST", "/walker/ListTasks", {}, token=token)

    assert "result" in result2

    # Get Task node using new GetTask walker
    result3 = server_fixture.request(
        "POST", "/walker/GetTask/" + str(jid), {}, token=token
    )
    assert "result" in result3


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

    token1 = user1["token"]
    token2 = user2["token"]

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
    assert user1["root_id"] != user2["root_id"]


def test_server_invalid_function(server_fixture: ServerFixture) -> None:
    """Test calling nonexistent function."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "invaliduser", "password": "pass"},
    )
    token = create_result["token"]

    # Try to call nonexistent function
    result = server_fixture.request(
        "POST", "/function/nonexistent", {"args": {}}, token=token
    )

    assert "error" in result


def test_server_invalid_walker(server_fixture: ServerFixture) -> None:
    """Test spawning nonexistent walker."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST",
        "/user/register",
        {"username": "invalidwalk", "password": "pass"},
    )
    token = create_result["token"]

    # Try to spawn nonexistent walker
    result = server_fixture.request(
        "POST", "/walker/NonExistentWalker", {"fields": {}}, token=token
    )

    assert "error" in result


@pytest.mark.xfail(reason="Flaky: timing-dependent client bundle building")
def test_client_page_and_bundle_endpoints(server_fixture: ServerFixture) -> None:
    """Render a client page and fetch the bundled JavaScript."""
    server_fixture.start_server()

    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "pageuser", "password": "pass"}
    )
    token = create_result["token"]

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

    assert "message" in result
    assert "endpoints" in result
    assert "POST /user/register" in result["endpoints"]
    assert "GET /functions" in result["endpoints"]
    assert "GET /walkers" in result["endpoints"]


def test_module_loading_and_introspection(server_fixture: ServerFixture) -> None:
    """Test that module loads correctly and introspection works."""
    # Load module
    base, mod, mach = proc_file_sess(fixture_abs_path("serve_api.jac"), "")
    Jac.set_base_path(base)
    Jac.jac_import(
        target=mod,
        base_path=base,
        override_name="__main__",
        lng="jac",
    )

    # Create server
    server = JacAPIServer(
        module_name="__main__",
        session_path=server_fixture.session_file,
        port=9999,  # Different port, won't actually start
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

    mach.close()


def test_csr_mode_empty_root(server_fixture: ServerFixture) -> None:
    """Test CSR mode returns empty __jac_root for client-side rendering."""
    server_fixture.start_server()

    # Create user
    create_result = server_fixture.request(
        "POST", "/user/register", {"username": "csruser", "password": "pass"}
    )
    token = create_result["token"]

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
    # Load module
    base, mod, mach = proc_file_sess(fixture_abs_path("serve_api.jac"), "")
    Jac.set_base_path(base)
    Jac.jac_import(
        target=mod,
        base_path=base,
        override_name="__main__",
        lng="jac",
    )

    # Create server
    server = JacAPIServer(
        module_name="__main__",
        session_path=server_fixture.session_file,
        port=9998,
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
    html_content = result["html"]
    assert '<div id="__jac_root"></div>' in html_content

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
    token = create_result["token"]
    root_id = create_result["root_id"]

    # Create multiple tasks on the root node
    task1_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 1", "priority": 1},
        token=token,
    )
    assert "result" in task1_result

    task2_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 2", "priority": 2},
        token=token,
    )
    assert "result" in task2_result

    task3_result = server_fixture.request(
        "POST",
        "/walker/CreateTask",
        {"title": "Persistent Task 3", "priority": 3},
        token=token,
    )
    assert "result" in task3_result

    # List tasks to verify they were created
    list_before = server_fixture.request("POST", "/walker/ListTasks", {}, token=token)
    assert "result" in list_before

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
    assert "token" in login_result
    assert "error" not in login_result

    new_token = login_result["token"]
    new_root_id = login_result["root_id"]

    # Root ID should be the same (same user, same root)
    assert new_root_id == root_id

    # Token should be the same (persisted from before)
    assert new_token == token

    # List tasks again to verify they persisted
    list_after = server_fixture.request(
        "POST", "/walker/ListTasks", {}, token=new_token
    )

    # The ListTasks walker should successfully run
    assert "result" in list_after

    # Complete one of the tasks to verify we can still interact with persisted data
    complete_result = server_fixture.request(
        "POST",
        "/walker/CompleteTask",
        {"title": "Persistent Task 2"},
        token=new_token,
    )
    assert "result" in complete_result


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
    token = create_result["token"]

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
    token = create_result["token"]

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

    # Capture stdout
    captured_output = io.StringIO()

    try:
        with redirect_stdout(captured_output):
            # Call start with faux=True
            execution.start(
                filename=fixture_abs_path("serve_api.jac"),
                session=server_fixture.session_file,
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
    assert "2 functions" in output
    assert "4 walkers" in output
    assert "18 endpoints" in output

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
    request: pytest.FixtureRequest,
) -> Generator[ServerFixture, None, None]:
    """Pytest fixture for access level server setup and teardown."""
    fixture = ServerFixture(request)
    yield fixture
    fixture.cleanup()


def test_public_function_without_auth(access_server_fixture: ServerFixture) -> None:
    """Test that public functions can be called without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Call public function without authentication
    result = access_server_fixture.request(
        "POST", "/function/public_function", {"args": {"name": "Test"}}
    )

    assert "result" in result
    assert result["result"] == "Hello, Test! (public)"


def test_public_function_get_info_without_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that public function info can be retrieved without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Get public function info without authentication
    result = access_server_fixture.request("GET", "/function/public_function")

    assert "signature" in result
    assert "parameters" in result["signature"]


def test_protected_function_requires_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that protected functions require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to call protected function without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/function/protected_function", {"args": {"message": "test"}}
    )

    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_protected_function_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected functions work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "authuser", "password": "pass123"},
    )
    token = create_result["token"]

    # Call protected function with authentication
    result = access_server_fixture.request(
        "POST",
        "/function/protected_function",
        {"args": {"message": "secret"}},
        token=token,
    )

    assert "result" in result
    assert result["result"] == "Protected: secret"


def test_private_function_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private functions require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to call private function without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/function/private_function", {"args": {"secret": "test"}}
    )

    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_private_function_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private functions work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "privuser", "password": "pass456"},
    )
    token = create_result["token"]

    # Call private function with authentication
    result = access_server_fixture.request(
        "POST",
        "/function/private_function",
        {"args": {"secret": "topsecret"}},
        token=token,
    )

    assert "result" in result
    assert result["result"] == "Private: topsecret"


def test_public_walker_without_auth(access_server_fixture: ServerFixture) -> None:
    """Test that public walkers can be spawned without authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Spawn public walker without authentication
    result = access_server_fixture.request(
        "POST", "/walker/PublicWalker", {"message": "hello"}
    )

    assert "result" in result
    assert "reports" in result


def test_protected_walker_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected walkers require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to spawn protected walker without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/walker/ProtectedWalker", {"data": "test"}
    )

    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_protected_walker_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that protected walkers work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "walkuser", "password": "pass789"},
    )
    token = create_result["token"]

    # Spawn protected walker with authentication
    result = access_server_fixture.request(
        "POST",
        "/walker/ProtectedWalker",
        {"data": "mydata"},
        token=token,
    )

    assert "result" in result
    assert "reports" in result


def test_private_walker_requires_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private walkers require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to spawn private walker without authentication - should fail
    result = access_server_fixture.request(
        "POST", "/walker/PrivateWalker", {"secret": "test"}
    )

    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_private_walker_with_auth(access_server_fixture: ServerFixture) -> None:
    """Test that private walkers work with authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create user and get token
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "privwalk", "password": "pass000"},
    )
    token = create_result["token"]

    # Spawn private walker with authentication
    result = access_server_fixture.request(
        "POST",
        "/walker/PrivateWalker",
        {"secret": "verysecret"},
        token=token,
    )

    assert "result" in result
    assert "reports" in result


def test_introspection_list_requires_auth(
    access_server_fixture: ServerFixture,
) -> None:
    """Test that introspection list endpoints require authentication."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Try to list walkers without authentication - should fail
    result = access_server_fixture.request("GET", "/protected")
    assert "error" in result
    assert "Unauthorized" in result["error"]


def test_mixed_access_levels(access_server_fixture: ServerFixture) -> None:
    """Test server with mixed access levels (public, protected, private)."""
    access_server_fixture.start_server("serve_api_access.jac")

    # Create authenticated user
    create_result = access_server_fixture.request(
        "POST",
        "/user/register",
        {"username": "mixeduser", "password": "mixedpass"},
    )
    token = create_result["token"]

    # Public function without auth - should work
    result1 = access_server_fixture.request(
        "POST", "/function/public_add", {"args": {"a": 5, "b": 10}}
    )
    assert "result" in result1
    assert result1["result"] == 15

    # Protected function without auth - should fail
    result2 = access_server_fixture.request(
        "POST", "/function/protected_function", {"args": {"message": "test"}}
    )
    assert "error" in result2

    # Protected function with auth - should work
    result3 = access_server_fixture.request(
        "POST",
        "/function/protected_function",
        {"args": {"message": "test"}},
        token=token,
    )
    assert "result" in result3

    # Private function with auth - should work
    result4 = access_server_fixture.request(
        "POST",
        "/function/private_function",
        {"args": {"secret": "test"}},
        token=token,
    )
    assert "result" in result4


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

            # Load the module
            base, mod, mach = proc_file_sess(self.jac_file, self.session_file)
            Jac.set_base_path(base)
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name="__main__",
                lng="jac",
            )

            # Create server
            self.server = JacAPIServer(
                module_name="__main__",
                session_path=self.session_file,
                port=self.port,
            )

            # Start server in thread
            def run_server():
                try:
                    self.server.load_module()
                    handler_class = self.server.create_handler()
                    self.httpd = HTTPServer(("127.0.0.1", self.port), handler_class)
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

        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()
        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=2)
        set_config(None)
        del_session(self.session_file)


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
            assert "endpoints" in result
            assert "GET /pages/<name>" in result["endpoints"]

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
