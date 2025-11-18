"""Test for jac serve command and REST API server."""

import json
import os
import socket
import threading
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from jaclang.cli import cli
from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.runtimelib.server import JacAPIServer, UserManager
from jaclang.utils.test import TestCase


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


class TestServeCommand(TestCase):
    """Test jac serve REST API functionality."""

    def setUp(self) -> None:
        """Set up test."""
        super().setUp()
        self.server = None
        self.server_thread: threading.Thread | None = None
        self.httpd = None
        # Use dynamically allocated free port for each test
        try:
            self.port = get_free_port()
        except PermissionError:
            self.skipTest("Socket operations are not permitted in this environment")
            return
        self.base_url = f"http://localhost:{self.port}"
        # Use unique session file for each test
        test_name = self._testMethodName
        self.session_file = self.fixture_abs_path(f"test_serve_{test_name}.session")

    def tearDown(self) -> None:
        """Tear down test."""
        # Close user manager if it exists
        if self.server and hasattr(self.server, "user_manager"):
            try:
                self.server.user_manager.close()
            except Exception:
                pass

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
        self._del_session(self.session_file)
        super().tearDown()

    def _del_session(self, session: str) -> None:
        """Delete session files including user database files."""
        path = os.path.dirname(session)
        prefix = os.path.basename(session)
        if os.path.exists(path):
            for file in os.listdir(path):
                # Clean up session files and user database files (.users)
                if file.startswith(prefix):
                    try:
                        os.remove(f"{path}/{file}")
                    except Exception:
                        pass

    def _start_server(self) -> None:
        """Start the API server in a background thread."""
        from http.server import HTTPServer

        # Load the module
        base, mod, mach = cli.proc_file_sess(self.fixture_abs_path("serve_api.jac"), "")
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

    def _request(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> dict:
        """Make HTTP request to server."""
        status, payload, _ = self._request_raw(
            method, path, data=data, token=token, timeout=timeout
        )
        try:
            return json.loads(payload)
        except json.JSONDecodeError as exc:  # pragma: no cover - sanity guard
            raise AssertionError(f"Expected JSON response, got: {payload}") from exc

    def _request_raw(
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

    def test_user_manager_creation(self) -> None:
        """Test UserManager creates users with unique roots."""
        user_mgr = UserManager(self.session_file)

        # Create first user
        result1 = user_mgr.create_user("user1", "pass1")
        self.assertIn("token", result1)
        self.assertIn("root_id", result1)
        self.assertEqual(result1["username"], "user1")

        # Create second user
        result2 = user_mgr.create_user("user2", "pass2")
        self.assertIn("token", result2)
        self.assertIn("root_id", result2)

        # Users should have different roots
        self.assertNotEqual(result1["root_id"], result2["root_id"])

        # Duplicate username should fail
        result3 = user_mgr.create_user("user1", "pass3")
        self.assertIn("error", result3)

    def test_user_manager_authentication(self) -> None:
        """Test UserManager authentication."""
        user_mgr = UserManager(self.session_file)

        # Create user
        create_result = user_mgr.create_user("testuser", "testpass")
        original_token = create_result["token"]

        # Authenticate with correct credentials
        auth_result = user_mgr.authenticate("testuser", "testpass")
        self.assertIsNotNone(auth_result)
        self.assertEqual(auth_result["username"], "testuser")
        self.assertEqual(auth_result["token"], original_token)

        # Wrong password
        auth_fail = user_mgr.authenticate("testuser", "wrongpass")
        self.assertIsNone(auth_fail)

        # Nonexistent user
        auth_fail2 = user_mgr.authenticate("nouser", "pass")
        self.assertIsNone(auth_fail2)

    def test_user_manager_token_validation(self) -> None:
        """Test UserManager token validation."""
        user_mgr = UserManager(self.session_file)

        # Create user
        result = user_mgr.create_user("validuser", "validpass")
        token = result["token"]

        # Valid token
        username = user_mgr.validate_token(token)
        self.assertEqual(username, "validuser")

        # Invalid token
        username = user_mgr.validate_token("invalid_token")
        self.assertIsNone(username)

    def test_server_user_creation(self) -> None:
        """Test user creation endpoint."""
        self._start_server()

        # Create user
        result = self._request(
            "POST", "/user/create", {"username": "alice", "password": "secret123"}
        )

        self.assertIn("username", result)
        self.assertIn("token", result)
        self.assertIn("root_id", result)
        self.assertEqual(result["username"], "alice")

    def test_server_user_login(self) -> None:
        """Test user login endpoint."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "bob", "password": "pass456"}
        )

        # Login with correct credentials
        login_result = self._request(
            "POST", "/user/login", {"username": "bob", "password": "pass456"}
        )

        self.assertIn("token", login_result)
        self.assertEqual(login_result["username"], "bob")
        self.assertEqual(login_result["root_id"], create_result["root_id"])

        # Login with wrong password
        login_fail = self._request(
            "POST", "/user/login", {"username": "bob", "password": "wrongpass"}
        )

        self.assertIn("error", login_fail)

    def test_server_authentication_required(self) -> None:
        """Test that protected endpoints require authentication."""
        self._start_server()

        # Try to access protected endpoint without token
        result = self._request("GET", "/protected")
        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_server_list_functions(self) -> None:
        """Test listing functions endpoint."""
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST", "/user/create", {"username": "funcuser", "password": "pass"}
        )
        token = create_result["token"]

        # List functions
        result = self._request("GET", "/functions", token=token)

        self.assertIn("functions", result)
        self.assertIn("add_numbers", result["functions"])
        self.assertIn("greet", result["functions"])

    def test_server_get_function_signature(self) -> None:
        """Test getting function signature."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "siguser", "password": "pass"}
        )
        token = create_result["token"]

        # Get signature
        result = self._request("GET", "/function/add_numbers", token=token)

        self.assertIn("signature", result)
        sig = result["signature"]
        self.assertIn("parameters", sig)
        self.assertIn("a", sig["parameters"])
        self.assertIn("b", sig["parameters"])
        self.assertTrue(sig["parameters"]["a"]["required"])
        self.assertTrue(sig["parameters"]["b"]["required"])

    def test_server_call_function(self) -> None:
        """Test calling a function endpoint."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "calluser", "password": "pass"}
        )
        token = create_result["token"]

        # Call add_numbers
        result = self._request(
            "POST", "/function/add_numbers", {"args": {"a": 10, "b": 25}}, token=token
        )

        self.assertIn("result", result)
        self.assertEqual(result["result"], 35)

        # Call greet
        result2 = self._request(
            "POST", "/function/greet", {"args": {"name": "World"}}, token=token
        )

        self.assertIn("result", result2)
        self.assertEqual(result2["result"], "Hello, World!")

    def test_server_call_function_with_defaults(self) -> None:
        """Test calling function with default parameters."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "defuser", "password": "pass"}
        )
        token = create_result["token"]

        # Call greet without name (should use default)
        result = self._request("POST", "/function/greet", {"args": {}}, token=token)

        self.assertIn("result", result)
        self.assertEqual(result["result"], "Hello, World!")

    def test_server_list_walkers(self) -> None:
        """Test listing walkers endpoint."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "walkuser", "password": "pass"}
        )
        token = create_result["token"]

        # List walkers
        result = self._request("GET", "/walkers", token=token)

        self.assertIn("walkers", result)
        self.assertIn("CreateTask", result["walkers"])
        self.assertIn("ListTasks", result["walkers"])
        self.assertIn("CompleteTask", result["walkers"])

    def test_server_get_walker_info(self) -> None:
        """Test getting walker information."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "infouser", "password": "pass"}
        )
        token = create_result["token"]

        # Get walker info
        result = self._request("GET", "/walker/CreateTask", token=token)

        self.assertIn("info", result)
        info = result["info"]
        self.assertIn("fields", info)
        self.assertIn("title", info["fields"])
        self.assertIn("priority", info["fields"])
        self.assertIn("_jac_spawn_node", info["fields"])

        # Check that priority has a default
        self.assertFalse(info["fields"]["priority"]["required"])
        self.assertIsNotNone(info["fields"]["priority"]["default"])

    def test_server_spawn_walker(self) -> None:
        """Test spawning a walker."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "spawnuser", "password": "pass"}
        )
        token = create_result["token"]
        # Spawn CreateTask walker
        result = self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "Test Task", "priority": 2}},
            token=token,
        )
        jid = result["reports"][0]["_jac_id"]

        # If error, print for debugging
        if "error" in result:
            print(f"\nWalker spawn error: {result['error']}")
            if "traceback" in result:
                print(f"Traceback:\n{result['traceback']}")

        self.assertIn("result", result)
        self.assertIn("reports", result)

        # Spawn ListTasks walker to verify task was created
        result2 = self._request(
            "POST", "/walker/ListTasks", {"fields": {}}, token=token
        )

        self.assertIn("result", result2)

        # Get Task node using new GetTask walker
        result3 = self._request(
            "POST", "/walker/GetTask/" + str(jid), {"fields": {}}, token=token
        )
        self.assertIn("result", result3)

    def test_server_user_isolation(self) -> None:
        """Test that users have isolated graph spaces."""
        self._start_server()

        # Create two users
        user1 = self._request(
            "POST", "/user/create", {"username": "user1", "password": "pass1"}
        )
        user2 = self._request(
            "POST", "/user/create", {"username": "user2", "password": "pass2"}
        )

        token1 = user1["token"]
        token2 = user2["token"]

        # User1 creates a task
        self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "User1 Task", "priority": 1}},
            token=token1,
        )

        # User2 creates a different task
        self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "User2 Task", "priority": 2}},
            token=token2,
        )

        # Both users should have different root IDs
        self.assertNotEqual(user1["root_id"], user2["root_id"])

    def test_server_invalid_function(self) -> None:
        """Test calling nonexistent function."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "invaliduser", "password": "pass"}
        )
        token = create_result["token"]

        # Try to call nonexistent function
        result = self._request(
            "POST", "/function/nonexistent", {"args": {}}, token=token
        )

        self.assertIn("error", result)

    def test_server_invalid_walker(self) -> None:
        """Test spawning nonexistent walker."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "invalidwalk", "password": "pass"}
        )
        token = create_result["token"]

        # Try to spawn nonexistent walker
        result = self._request(
            "POST", "/walker/NonExistentWalker", {"fields": {}}, token=token
        )

        self.assertIn("error", result)

    def test_client_page_and_bundle_endpoints(self) -> None:
        """Render a client page and fetch the bundled JavaScript."""
        self._start_server()

        create_result = self._request(
            "POST", "/user/create", {"username": "pageuser", "password": "pass"}
        )
        token = create_result["token"]

        # Use longer timeout for page requests (they trigger bundle building)
        status, html_body, headers = self._request_raw(
            "GET", "/page/client_page", token=token, timeout=15
        )

        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))
        self.assertIn('<div id="__jac_root">', html_body)
        self.assertIn("Runtime Test", html_body)
        self.assertIn("/static/client.js?hash=", html_body)

        # Bundle should be cached from page request, but use longer timeout for CI safety
        status_js, js_body, js_headers = self._request_raw(
            "GET", "/static/client.js", timeout=15
        )
        self.assertEqual(status_js, 200)
        self.assertIn("application/javascript", js_headers.get("Content-Type", ""))
        self.assertIn("function __jacJsx", js_body)

    def test_server_root_endpoint(self) -> None:
        """Test root endpoint returns API information."""
        self._start_server()

        result = self._request("GET", "/")

        self.assertIn("message", result)
        self.assertIn("endpoints", result)
        self.assertIn("POST /user/create", result["endpoints"])
        self.assertIn("GET /functions", result["endpoints"])
        self.assertIn("GET /walkers", result["endpoints"])

    def test_module_loading_and_introspection(self) -> None:
        """Test that module loads correctly and introspection works."""
        # Load module
        base, mod, mach = cli.proc_file_sess(self.fixture_abs_path("serve_api.jac"), "")
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
            session_path=self.session_file,
            port=9999,  # Different port, won't actually start
        )
        server.load_module()

        # Check module loaded
        self.assertIsNotNone(server.module)

        # Check functions discovered
        functions = server.get_functions()
        self.assertIn("add_numbers", functions)
        self.assertIn("greet", functions)

        # Check walkers discovered
        walkers = server.get_walkers()
        self.assertIn("CreateTask", walkers)
        self.assertIn("ListTasks", walkers)
        self.assertIn("CompleteTask", walkers)

        # Check introspection
        sig = server.introspect_callable(functions["add_numbers"])
        self.assertIn("parameters", sig)
        self.assertIn("a", sig["parameters"])
        self.assertIn("b", sig["parameters"])

        # Check walker introspection
        walker_info = server.introspect_walker(walkers["CreateTask"])
        self.assertIn("fields", walker_info)
        self.assertIn("title", walker_info["fields"])
        self.assertIn("priority", walker_info["fields"])

        mach.close()

    def test_csr_mode_empty_root(self) -> None:
        """Test CSR mode returns empty __jac_root for client-side rendering."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "csruser", "password": "pass"}
        )
        token = create_result["token"]

        # Request page in CSR mode using query parameter (longer timeout for bundle building)
        status, html_body, headers = self._request_raw(
            "GET", "/page/client_page?mode=csr", token=token, timeout=15
        )

        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))

        # In CSR mode, __jac_root should be empty (no SSR)
        self.assertIn('<div id="__jac_root"></div>', html_body)

        # But __jac_init__ and client.js should still be present
        self.assertIn('<script id="__jac_init__" type="application/json">', html_body)
        self.assertIn("/static/client.js?hash=", html_body)

        # __jac_init__ should still contain the function name and args
        self.assertIn('"function": "client_page"', html_body)

    def test_csr_mode_with_server_default(self) -> None:
        """render_client_page returns an empty shell when called directly."""
        # Load module
        base, mod, mach = cli.proc_file_sess(self.fixture_abs_path("serve_api.jac"), "")
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
            session_path=self.session_file,
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
        self.assertIn("html", result)
        html_content = result["html"]
        self.assertIn('<div id="__jac_root"></div>', html_content)

        mach.close()

    def test_root_data_persistence_across_server_restarts(self) -> None:
        """Test that user data and graph persist across server restarts.

        This test verifies that both user credentials and graph data (nodes and
        edges attached to a root) are properly persisted to the session file and
        can be accessed after a server restart.
        """
        # Start first server instance
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST",
            "/user/create",
            {"username": "persistuser", "password": "testpass123"},
        )
        token = create_result["token"]
        root_id = create_result["root_id"]

        # Create multiple tasks on the root node
        task1_result = self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "Persistent Task 1", "priority": 1}},
            token=token,
        )
        self.assertIn("result", task1_result)

        task2_result = self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "Persistent Task 2", "priority": 2}},
            token=token,
        )
        self.assertIn("result", task2_result)

        task3_result = self._request(
            "POST",
            "/walker/CreateTask",
            {"fields": {"title": "Persistent Task 3", "priority": 3}},
            token=token,
        )
        self.assertIn("result", task3_result)

        # List tasks to verify they were created
        list_before = self._request(
            "POST", "/walker/ListTasks", {"fields": {}}, token=token
        )
        self.assertIn("result", list_before)

        # Shutdown first server instance
        # Close user manager first to release the shelf lock
        if self.server and hasattr(self.server, "user_manager"):
            self.server.user_manager.close()

        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()
            self.httpd = None

        if self.server_thread and self.server_thread.is_alive():
            self.server_thread.join(timeout=2)

        # Wait a moment to ensure server is fully stopped
        time.sleep(0.5)

        # Start second server instance with the same session file
        self._start_server()

        # Login with the same credentials
        login_result = self._request(
            "POST",
            "/user/login",
            {"username": "persistuser", "password": "testpass123"},
        )

        # User should be able to log in successfully
        self.assertIn("token", login_result)
        self.assertNotIn("error", login_result)

        new_token = login_result["token"]
        new_root_id = login_result["root_id"]

        # Root ID should be the same (same user, same root)
        self.assertEqual(new_root_id, root_id)

        # Token should be the same (persisted from before)
        self.assertEqual(new_token, token)

        # List tasks again to verify they persisted
        list_after = self._request(
            "POST", "/walker/ListTasks", {"fields": {}}, token=new_token
        )

        # The ListTasks walker should successfully run
        self.assertIn("result", list_after)

        # Complete one of the tasks to verify we can still interact with persisted data
        complete_result = self._request(
            "POST",
            "/walker/CompleteTask",
            {"fields": {"title": "Persistent Task 2"}},
            token=new_token,
        )
        self.assertIn("result", complete_result)

    def test_client_bundle_has_object_get_polyfill(self) -> None:
        """Test that client bundle includes Object.prototype.get polyfill."""
        self._start_server()

        # Pre-warm the bundle by requesting a page first (triggers bundle build)
        # This ensures the bundle is cached before we test it directly
        try:
            self._request("GET", "/")
        except Exception:
            pass  # Ignore errors, we just want to trigger bundle building

        # Fetch the client bundle with longer timeout for CI environments
        # Bundle building can be slow on CI runners with limited resources
        status, js_body, headers = self._request_raw(
            "GET", "/static/client.js", timeout=15
        )

        self.assertEqual(status, 200)
        self.assertIn("application/javascript", headers.get("Content-Type", ""))

        # Verify core runtime functions are present
        self.assertIn("__jacJsx", js_body)
        self.assertIn("__jacRegisterClientModule", js_body)

    def test_login_form_renders_with_correct_elements(self) -> None:
        """Test that client page renders with correct HTML elements via HTTP endpoint."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "formuser", "password": "pass"}
        )
        token = create_result["token"]

        # Request the client_page endpoint (longer timeout for bundle building)
        status, html_body, headers = self._request_raw(
            "GET", "/page/client_page", token=token, timeout=15
        )

        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))

        # Check basic HTML structure
        self.assertIn("<!DOCTYPE html>", html_body)
        self.assertIn('<div id="__jac_root">', html_body)
        self.assertIn('<script id="__jac_init__"', html_body)
        self.assertIn("/static/client.js?hash=", html_body)

        # Verify __jac_init__ contains the right function and global
        self.assertIn('"function": "client_page"', html_body)
        self.assertIn('"WELCOME_TITLE": "Runtime Test"', html_body)  # Global variable

        # Fetch and verify the bundle (should be cached from page request, but use longer timeout for CI)
        status_js, js_body, _ = self._request_raw(
            "GET", "/static/client.js", timeout=15
        )
        self.assertEqual(status_js, 200)

        # Verify the bundle has the polyfill setup function (now part of client_runtime.jac)
        self.assertIn("__jacEnsureObjectGetPolyfill", js_body)

        # Verify the function is in the bundle
        self.assertIn("function client_page", js_body)

    def test_default_page_is_csr(self) -> None:
        """Test that the default page response is CSR (client-side rendering)."""
        self._start_server()

        # Create user
        create_result = self._request(
            "POST", "/user/create", {"username": "csrdefaultuser", "password": "pass"}
        )
        token = create_result["token"]

        # Request page WITHOUT specifying mode (should use default, longer timeout for bundle building)
        status, html_body, headers = self._request_raw(
            "GET", "/page/client_page", token=token, timeout=15
        )

        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("Content-Type", ""))

        # In CSR mode (default), __jac_root should be empty
        self.assertIn('<div id="__jac_root"></div>', html_body)

        # Should NOT contain pre-rendered content
        # (The content will be rendered on the client side)
        # Note: We check that the root div is completely empty
        import re

        root_match = re.search(r'<div id="__jac_root">(.*?)</div>', html_body)
        assert root_match is not None
        root_content = root_match.group(1)
        self.assertEqual(root_content, "")  # Should be empty string

        # __jac_init__ and client.js should still be present for hydration
        self.assertIn('<script id="__jac_init__" type="application/json">', html_body)
        self.assertIn("/static/client.js?hash=", html_body)

        # Verify that explicitly requesting SSR mode is ignored (still CSR, longer timeout for bundle building)
        status_ssr, html_ssr, _ = self._request_raw(
            "GET", "/page/client_page?mode=ssr", token=token, timeout=15
        )
        self.assertEqual(status_ssr, 200)

        self.assertIn('<div id="__jac_root"></div>', html_ssr)

    def test_faux_flag_prints_endpoint_docs(self) -> None:
        """Test that --faux flag prints endpoint documentation without starting server."""
        import io
        from contextlib import redirect_stdout

        # Capture stdout
        captured_output = io.StringIO()

        try:
            with redirect_stdout(captured_output):
                # Call serve with faux=True
                cli.serve(
                    filename=self.fixture_abs_path("serve_api.jac"),
                    session=self.session_file,
                    port=self.port,
                    main=True,
                    faux=True,
                )
        except SystemExit:
            pass  # serve() may call exit() in some error cases

        output = captured_output.getvalue()

        # Verify function endpoints are documented
        self.assertIn("FUNCTIONS", output)
        self.assertIn("/function/add_numbers", output)
        self.assertIn("/function/greet", output)

        # Verify walker endpoints are documented
        self.assertIn("WALKERS", output)
        self.assertIn("/walker/CreateTask", output)
        self.assertIn("/walker/ListTasks", output)
        self.assertIn("/walker/CompleteTask", output)

        # Verify client page endpoints section is documented
        self.assertIn("CLIENT PAGES", output)
        self.assertIn("client_page", output)

        # Verify summary is present
        self.assertIn("TOTAL:", output)
        self.assertIn("2 functions", output)
        self.assertIn("4 walkers", output)
        self.assertIn("18 endpoints", output)

        # Verify parameter details are included
        self.assertIn("required", output)
        self.assertIn("optional", output)
        self.assertIn("Bearer token", output)

    def test_faux_flag_with_littlex_example(self) -> None:
        """Test that --faux flag correctly identifies functions, walkers, and endpoints in littleX example."""
        import io
        from contextlib import redirect_stdout

        # Get the absolute path to littleX file
        import os

        littlex_path = os.path.abspath(
            os.path.join(
                os.path.dirname(__file__),
                "../../../examples/littleX/littleX_single_nodeps.jac",
            )
        )

        # Skip test if file doesn't exist
        if not os.path.exists(littlex_path):
            self.skipTest(f"LittleX example not found at {littlex_path}")

        # Capture stdout
        captured_output = io.StringIO()

        try:
            with redirect_stdout(captured_output):
                # Call serve with faux=True on littleX example
                cli.serve(
                    filename=littlex_path,
                    session=self.session_file,
                    port=self.port,
                    main=True,
                    faux=True,
                )
        except SystemExit:
            pass  # serve() may call exit() in some error cases

        output = captured_output.getvalue()

        self.assertIn("littleX_single_nodeps", output)
        self.assertIn("0 functions", output)
        self.assertIn("15 walkers", output)
        self.assertIn("36 endpoints", output)

        # Verify some specific walker endpoints are documented
        self.assertIn("/walker/visit_profile", output)
        self.assertIn("/walker/create_tweet", output)
        self.assertIn("/walker/load_feed", output)
        self.assertIn("/walker/update_profile", output)

        # Verify authentication and introspection endpoints are still present
        self.assertIn("/user/create", output)
        self.assertIn("Available", output)
        self.assertIn("1 client functions", output)  # 15 client functions
        # Verify some client functions are listed
        self.assertIn("App", output)
        self.assertIn("/page/", output)


class TestAccessLevelAuthentication(TestCase):
    """Test access level-based authentication for endpoints."""

    def setUp(self) -> None:
        """Set up test."""
        super().setUp()
        self.server = None
        self.server_thread: threading.Thread | None = None
        self.httpd = None
        # Use dynamically allocated free port for each test
        try:
            self.port = get_free_port()
        except PermissionError:
            self.skipTest("Socket operations are not permitted in this environment")
            return
        self.base_url = f"http://localhost:{self.port}"
        # Use unique session file for each test
        test_name = self._testMethodName
        self.session_file = self.fixture_abs_path(
            f"test_serve_access_{test_name}.session"
        )

    def tearDown(self) -> None:
        """Tear down test."""
        # Close user manager if it exists
        if self.server and hasattr(self.server, "user_manager"):
            try:
                self.server.user_manager.close()
            except Exception:
                pass

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
        self._del_session(self.session_file)
        super().tearDown()

    def _del_session(self, session: str) -> None:
        """Delete session files including user database files."""
        path = os.path.dirname(session)
        prefix = os.path.basename(session)
        if os.path.exists(path):
            for file in os.listdir(path):
                # Clean up session files and user database files (.users)
                if file.startswith(prefix):
                    try:
                        os.remove(f"{path}/{file}")
                    except Exception:
                        pass

    def _start_server(self) -> None:
        """Start the API server in a background thread."""
        from http.server import HTTPServer

        # Load the module
        base, mod, mach = cli.proc_file_sess(
            self.fixture_abs_path("serve_api_access.jac"), ""
        )
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

    def _request(
        self,
        method: str,
        path: str,
        data: dict | None = None,
        token: str | None = None,
        timeout: int = 5,
    ) -> dict:
        """Make HTTP request to server."""
        status, payload, _ = self._request_raw(
            method, path, data=data, token=token, timeout=timeout
        )
        try:
            return json.loads(payload)
        except json.JSONDecodeError as exc:  # pragma: no cover - sanity guard
            raise AssertionError(f"Expected JSON response, got: {payload}") from exc

    def _request_raw(
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

    def test_public_function_without_auth(self) -> None:
        """Test that public functions can be called without authentication."""
        self._start_server()

        # Call public function without authentication
        result = self._request(
            "POST", "/function/public_function", {"args": {"name": "Test"}}
        )

        self.assertIn("result", result)
        self.assertEqual(result["result"], "Hello, Test! (public)")

    def test_public_function_get_info_without_auth(self) -> None:
        """Test that public function info can be retrieved without authentication."""
        self._start_server()

        # Get public function info without authentication
        result = self._request("GET", "/function/public_function")

        self.assertIn("signature", result)
        self.assertIn("parameters", result["signature"])

    def test_protected_function_requires_auth(self) -> None:
        """Test that protected functions require authentication."""
        self._start_server()

        # Try to call protected function without authentication - should fail
        result = self._request(
            "POST", "/function/protected_function", {"args": {"message": "test"}}
        )

        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_protected_function_with_auth(self) -> None:
        """Test that protected functions work with authentication."""
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST", "/user/create", {"username": "authuser", "password": "pass123"}
        )
        token = create_result["token"]

        # Call protected function with authentication
        result = self._request(
            "POST",
            "/function/protected_function",
            {"args": {"message": "secret"}},
            token=token,
        )

        self.assertIn("result", result)
        self.assertEqual(result["result"], "Protected: secret")

    def test_private_function_requires_auth(self) -> None:
        """Test that private functions require authentication."""
        self._start_server()

        # Try to call private function without authentication - should fail
        result = self._request(
            "POST", "/function/private_function", {"args": {"secret": "test"}}
        )

        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_private_function_with_auth(self) -> None:
        """Test that private functions work with authentication."""
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST", "/user/create", {"username": "privuser", "password": "pass456"}
        )
        token = create_result["token"]

        # Call private function with authentication
        result = self._request(
            "POST",
            "/function/private_function",
            {"args": {"secret": "topsecret"}},
            token=token,
        )

        self.assertIn("result", result)
        self.assertEqual(result["result"], "Private: topsecret")

    def test_public_walker_without_auth(self) -> None:
        """Test that public walkers can be spawned without authentication."""
        self._start_server()

        # Spawn public walker without authentication
        result = self._request(
            "POST", "/walker/PublicWalker", {"fields": {"message": "hello"}}
        )

        self.assertIn("result", result)
        self.assertIn("reports", result)

    def test_protected_walker_requires_auth(self) -> None:
        """Test that protected walkers require authentication."""
        self._start_server()

        # Try to spawn protected walker without authentication - should fail
        result = self._request(
            "POST", "/walker/ProtectedWalker", {"fields": {"data": "test"}}
        )

        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_protected_walker_with_auth(self) -> None:
        """Test that protected walkers work with authentication."""
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST", "/user/create", {"username": "walkuser", "password": "pass789"}
        )
        token = create_result["token"]

        # Spawn protected walker with authentication
        result = self._request(
            "POST",
            "/walker/ProtectedWalker",
            {"fields": {"data": "mydata"}},
            token=token,
        )

        self.assertIn("result", result)
        self.assertIn("reports", result)

    def test_private_walker_requires_auth(self) -> None:
        """Test that private walkers require authentication."""
        self._start_server()

        # Try to spawn private walker without authentication - should fail
        result = self._request(
            "POST", "/walker/PrivateWalker", {"fields": {"secret": "test"}}
        )

        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_private_walker_with_auth(self) -> None:
        """Test that private walkers work with authentication."""
        self._start_server()

        # Create user and get token
        create_result = self._request(
            "POST", "/user/create", {"username": "privwalk", "password": "pass000"}
        )
        token = create_result["token"]

        # Spawn private walker with authentication
        result = self._request(
            "POST",
            "/walker/PrivateWalker",
            {"fields": {"secret": "verysecret"}},
            token=token,
        )

        self.assertIn("result", result)
        self.assertIn("reports", result)

    def test_introspection_list_requires_auth(self) -> None:
        """Test that introspection list endpoints require authentication."""
        self._start_server()

        # Try to list walkers without authentication - should fail
        result = self._request("GET", "/protected")
        self.assertIn("error", result)
        self.assertIn("Unauthorized", result["error"])

    def test_mixed_access_levels(self) -> None:
        """Test server with mixed access levels (public, protected, private)."""
        self._start_server()

        # Create authenticated user
        create_result = self._request(
            "POST", "/user/create", {"username": "mixeduser", "password": "mixedpass"}
        )
        token = create_result["token"]

        # Public function without auth - should work
        result1 = self._request(
            "POST", "/function/public_add", {"args": {"a": 5, "b": 10}}
        )
        self.assertIn("result", result1)
        self.assertEqual(result1["result"], 15)

        # Protected function without auth - should fail
        result2 = self._request(
            "POST", "/function/protected_function", {"args": {"message": "test"}}
        )
        self.assertIn("error", result2)

        # Protected function with auth - should work
        result3 = self._request(
            "POST",
            "/function/protected_function",
            {"args": {"message": "test"}},
            token=token,
        )
        self.assertIn("result", result3)

        # Private function with auth - should work
        result4 = self._request(
            "POST",
            "/function/private_function",
            {"args": {"secret": "test"}},
            token=token,
        )
        self.assertIn("result", result4)
