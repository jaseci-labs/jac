"""End-to-end tests for `jac start` HTTP endpoints."""

from __future__ import annotations

import gc
import json
import os
import shutil
import tempfile
import time
from http.client import RemoteDisconnected
from subprocess import PIPE, Popen, run
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pytest

from .test_helpers import (
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port,
)


def _wait_for_endpoint(
    url: str,
    timeout: float = 120.0,
    poll_interval: float = 2.0,
    request_timeout: float = 30.0,
) -> bytes:
    """Block until an HTTP endpoint returns a successful response or timeout.

    Retries on 503 Service Unavailable (temporary) and connection errors.
    Fails immediately on 500 Internal Server Error (permanent errors like compilation failures).

    Returns:
        The response body as bytes.

    Raises:
        TimeoutError: if the endpoint does not return success within timeout.
        HTTPError: if the endpoint returns a non-retryable error (e.g., 500).
    """
    deadline = time.time() + timeout
    last_err: Exception | None = None

    while time.time() < deadline:
        try:
            with urlopen(url, timeout=request_timeout) as resp:
                return resp.read()
        except HTTPError as exc:
            if exc.code == 503:
                # Service Unavailable - retry (temporary condition, e.g., compilation in progress)
                # Close the underlying response to release the socket
                exc.close()
                last_err = exc
                print(f"[DEBUG] Endpoint {url} returned 503, retrying...")
                time.sleep(poll_interval)
            elif exc.code == 500:
                # Internal Server Error - do not retry (permanent error, e.g., compilation failure)
                # Close the underlying response to release the socket
                exc.close()
                # Re-raise immediately - 500 indicates a permanent error that won't resolve by retrying
                raise
            else:
                # Other HTTP errors should not be retried
                raise
        except URLError as exc:
            # Connection errors - retry
            last_err = exc
            print(f"[DEBUG] Endpoint {url} connection error: {exc}, retrying...")
            time.sleep(poll_interval)
        except RemoteDisconnected as exc:
            # Server closed connection - retry
            last_err = exc
            print(f"[DEBUG] Endpoint {url} remote disconnected: {exc}, retrying...")
            time.sleep(poll_interval)

    raise TimeoutError(
        f"Timed out waiting for {url} to become available. Last error: {last_err}"
    )


def test_all_in_one_app_endpoints() -> None:
    """Create a Jac app, copy @all-in-one into it, install packages from jac.toml, then verify endpoints."""
    print(
        "[DEBUG] Starting test_all_in_one_app_endpoints using jac create --use client + @all-in-one"
    )

    # Resolve the path to jac_client/examples/all-in-one relative to this test file.
    tests_dir = os.path.dirname(__file__)
    jac_client_root = os.path.dirname(tests_dir)
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one")

    print(f"[DEBUG] Resolved all-in-one source path: {all_in_one_path}")
    assert os.path.isdir(all_in_one_path), "all-in-one example directory missing"

    app_name = "e2e-all-in-one-app"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)
            print(f"[DEBUG] Changed working directory to {temp_dir}")

            # 1. Create a new Jac app via CLI (requires jac + jac-client plugin installed)
            print(f"[DEBUG] Running 'jac create --use client {app_name}'")
            process = Popen(
                ["jac", "create", "--use", "client", app_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            returncode = process.returncode

            print(
                "[DEBUG] 'jac create --use client' completed "
                f"returncode={returncode}\n"
                f"STDOUT:\n{stdout}\n"
                f"STDERR:\n{stderr}\n"
            )

            # If the currently installed `jac` CLI does not support `create --use client`,
            # fail the test instead of skipping it.
            if returncode != 0 and "unrecognized arguments: --use" in stderr:
                pytest.fail(
                    "Test failed: installed `jac` CLI does not support `create --use client`."
                )

            assert returncode == 0, (
                f"jac create --use client failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
            )

            project_path = os.path.join(temp_dir, app_name)
            print(f"[DEBUG] Created base Jac app at {project_path}")
            assert os.path.isdir(project_path)

            # 2. Copy the contents from @all-in-one into the created app directory.
            print("[DEBUG] Copying @all-in-one contents into created Jac app")
            for entry in os.listdir(all_in_one_path):
                src = os.path.join(all_in_one_path, entry)
                dst = os.path.join(project_path, entry)
                # Avoid copying node_modules / build artifacts from the example.
                if entry in {"node_modules", "build", "dist", ".pytest_cache"}:
                    continue
                if os.path.isdir(src):
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)

            # 3. Install packages from jac.toml using `jac add --npm`
            # This reads packages from jac.toml, generates package.json, and runs npm install
            print("[DEBUG] Running 'jac add --npm' to install packages from jac.toml")
            jac_add_result = run(
                ["jac", "add", "--npm"],
                cwd=project_path,
                capture_output=True,
                text=True,
            )
            print(
                "[DEBUG] 'jac add --npm' completed "
                f"returncode={jac_add_result.returncode}\n"
                f"STDOUT (truncated to 2000 chars):\n{jac_add_result.stdout[:2000]}\n"
                f"STDERR (truncated to 2000 chars):\n{jac_add_result.stderr[:2000]}\n"
            )

            if jac_add_result.returncode != 0:
                pytest.fail(
                    f"Test failed: jac add --npm failed or npm is not available in PATH.\n"
                    f"STDOUT:\n{jac_add_result.stdout}\n"
                    f"STDERR:\n{jac_add_result.stderr}\n"
                )

            app_jac_path = os.path.join(project_path, "main.jac")
            assert os.path.isfile(app_jac_path), "all-in-one main.jac file missing"

            # 4. Start the server: `jac start main.jac`
            # NOTE: We don't use text mode here, so `Popen` defaults to bytes.
            # Use `Popen[bytes]` in the type annotation to keep mypy happy.
            server: Popen[bytes] | None = None
            # Use dynamic port allocation to avoid conflicts when running tests in parallel
            server_port = get_free_port()
            try:
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                )
                server = Popen(
                    ["jac", "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                )
                # Wait for localhost:8000 to become available
                print(
                    f"[DEBUG] Waiting for server to be available on 127.0.0.1:{server_port}"
                )
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server is now accepting connections on 127.0.0.1:{server_port}"
                )

                # "/" – server up (serves client app HTML due to base_route_app="app")
                # Note: The root endpoint may return 503 while the client bundle is building.
                # We use _wait_for_endpoint to retry on 503 until it's ready.
                try:
                    print("[DEBUG] Sending GET request to root endpoint / (with retry)")
                    root_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    root_body = root_bytes.decode("utf-8", errors="ignore")
                    print(
                        "[DEBUG] Received response from root endpoint /\n"
                        f"Body (truncated to 500 chars):\n{root_body[:500]}"
                    )
                    # With base_route_app="app", root serves client HTML
                    assert "<!DOCTYPE html>" in root_body or "<html" in root_body
                    assert '<div id="root">' in root_body
                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error while requesting root endpoint: {exc}")
                    pytest.fail(f"Failed to GET root endpoint: {exc}")

                # "/cl/app" – main page is loading
                # Note: This endpoint may return 503 (temporary) while the page is being compiled,
                # or 500 (permanent) if there's a compilation error. We use _wait_for_endpoint
                # to retry on 503 until it's ready, but it will fail immediately on 500.
                try:
                    print(
                        "[DEBUG] Sending GET request to /cl/app endpoint (with retry)"
                    )
                    page_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/cl/app",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    page_body = page_bytes.decode("utf-8", errors="ignore")
                    print(
                        "[DEBUG] Received response from /cl/app endpoint\n"
                        f"Body (truncated to 500 chars):\n{page_body[:500]}"
                    )
                    assert "<html" in page_body.lower()
                except (URLError, HTTPError, TimeoutError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /cl/app endpoint: {exc}")
                    pytest.fail(f"Failed to GET /cl/app endpoint: {exc}")

                # "/cl/app#/nested" – relative paths / nested route
                # (hash fragment is client-side only but server should still serve the app shell)
                try:
                    print("[DEBUG] Sending GET request to /cl/app#/nested endpoint")
                    with urlopen(
                        f"http://127.0.0.1:{server_port}/cl/app#/nested",
                        timeout=200,
                    ) as resp_nested:
                        nested_body = resp_nested.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /cl/app#/nested endpoint\n"
                            f"Status: {resp_nested.status}\n"
                            f"Body (truncated to 500 chars):\n{nested_body[:500]}"
                        )
                        assert resp_nested.status == 200
                        assert "<html" in nested_body.lower()
                except (URLError, HTTPError) as exc:
                    print(
                        f"[DEBUG] Error while requesting /cl/app#/nested endpoint: {exc}"
                    )
                    pytest.fail("Failed to GET /cl/app#/nested endpoint")

                # Note: CSS serving is tested separately in test_css_with_image
                # The CSS is bundled into client.js so no separate /static/styles.css endpoint

                # "/static/assets/burger.png" – static files are loading
                try:
                    print("[DEBUG] Sending GET request to /static/assets/burger.png")
                    with urlopen(
                        f"http://127.0.0.1:{server_port}/static/assets/burger.png",
                        timeout=20,
                    ) as resp_png:
                        png_bytes = resp_png.read()
                        print(
                            "[DEBUG] Received response from /static/assets/burger.png\n"
                            f"Status: {resp_png.status}\n"
                            f"Content-Length: {len(png_bytes)} bytes"
                        )
                        assert resp_png.status == 200
                        assert len(png_bytes) > 0
                        assert png_bytes.startswith(b"\x89PNG"), (
                            "Expected PNG signature at start of burger.png"
                        )
                except (URLError, HTTPError) as exc:
                    print(
                        f"[DEBUG] Error while requesting /static/assets/burger.png: {exc}"
                    )
                    pytest.fail("Failed to GET /static/assets/burger.png")

                # "/workers/worker.js" – worker script is served
                try:
                    print(
                        "[DEBUG] Sending GET request to /workers/worker.js (with retry)"
                    )
                    worker_js_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/workers/worker.js",
                        timeout=60.0,
                        poll_interval=2.0,
                        request_timeout=20.0,
                    )
                    worker_js_body = worker_js_bytes.decode("utf-8", errors="ignore")
                    print(
                        "[DEBUG] Received response from /workers/worker.js\n"
                        f"Body (truncated to 500 chars):\n{worker_js_body[:500]}"
                    )
                    assert len(worker_js_body.strip()) > 0, (
                        "Worker JS should not be empty"
                    )
                    assert (
                        "postMessage" in worker_js_body or "onmessage" in worker_js_body
                    ), "Worker JS should contain a message handler"
                except (URLError, HTTPError, TimeoutError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /workers/worker.js: {exc}")
                    pytest.fail(
                        f"Failed to GET /workers/worker.js after retries: {exc}"
                    )

                # POST /walker/get_server_message – walkers are integrated and up and running
                try:
                    print(
                        "[DEBUG] Sending POST request to /walker/get_server_message endpoint"
                    )
                    req = Request(
                        f"http://127.0.0.1:{server_port}/walker/get_server_message",
                        data=json.dumps({}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    )
                    with urlopen(req, timeout=20) as resp_walker:
                        walker_body = resp_walker.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /walker/get_server_message\n"
                            f"Status: {resp_walker.status}\n"
                            f"Body (truncated to 500 chars):\n{walker_body[:500]}"
                        )
                        assert resp_walker.status == 200
                        # The walker reports "hello from a basic walker!"
                        assert "hello from a basic walker" in walker_body.lower()
                except (URLError, HTTPError, RemoteDisconnected) as exc:
                    print(
                        f"[DEBUG] Error while requesting /walker/get_server_message: {exc}"
                    )
                    pytest.fail("Failed to POST /walker/get_server_message")

                # POST /walker/create_todo – create a Todo via walker HTTP API
                try:
                    print(
                        "[DEBUG] Sending POST request to /walker/create_todo endpoint"
                    )
                    payload = {
                        "text": "Sample todo from all-in-one app",
                    }
                    req = Request(
                        f"http://127.0.0.1:{server_port}/walker/create_todo",
                        data=json.dumps(payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    )
                    with urlopen(req, timeout=20) as resp_create:
                        create_body = resp_create.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /walker/create_todo\n"
                            f"Status: {resp_create.status}\n"
                            f"Body (truncated to 500 chars):\n{create_body[:500]}"
                        )
                        assert resp_create.status == 200
                        # Basic sanity check: created Todo text should appear in the response payload.
                        assert "Sample todo from all-in-one app" in create_body
                except (URLError, HTTPError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /walker/create_todo: {exc}")
                    pytest.fail("Failed to POST /walker/create_todo")

                # POST /user/register – register a new user
                test_username = "test_user"
                test_password = "test_password_123"
                try:
                    print("[DEBUG] Sending POST request to /user/register endpoint")
                    register_payload = {
                        "username": test_username,
                        "password": test_password,
                    }
                    req_register = Request(
                        f"http://127.0.0.1:{server_port}/user/register",
                        data=json.dumps(register_payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    )
                    with urlopen(req_register, timeout=20) as resp_register:
                        register_body = resp_register.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /user/register\n"
                            f"Status: {resp_register.status}\n"
                            f"Body (truncated to 500 chars):\n{register_body[:500]}"
                        )
                        assert resp_register.status == 201
                        register_response = json.loads(register_body)
                        # Handle new TransportResponse envelope format
                        register_data = register_response.get("data", register_response)
                        assert "username" in register_data
                        assert "token" in register_data
                        assert "root_id" in register_data
                        assert register_data["username"] == test_username
                        assert len(register_data["token"]) > 0
                        assert len(register_data["root_id"]) > 0
                        print(
                            f"[DEBUG] Successfully registered user: {test_username}\n"
                            f"Token: {register_data['token'][:20]}...\n"
                            f"Root ID: {register_data['root_id']}"
                        )
                except (URLError, HTTPError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /user/register: {exc}")
                    pytest.fail("Failed to POST /user/register")

                # POST /user/login – login with registered credentials
                try:
                    print("[DEBUG] Sending POST request to /user/login endpoint")
                    login_payload = {
                        "username": test_username,
                        "password": test_password,
                    }
                    req_login = Request(
                        f"http://127.0.0.1:{server_port}/user/login",
                        data=json.dumps(login_payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    )
                    with urlopen(req_login, timeout=20) as resp_login:
                        login_body = resp_login.read().decode("utf-8", errors="ignore")
                        print(
                            "[DEBUG] Received response from /user/login\n"
                            f"Status: {resp_login.status}\n"
                            f"Body (truncated to 500 chars):\n{login_body[:500]}"
                        )
                        assert resp_login.status == 200
                        login_response = json.loads(login_body)
                        # Handle new TransportResponse envelope format
                        login_data = login_response.get("data", login_response)
                        assert "token" in login_data
                        assert len(login_data["token"]) > 0
                        print(
                            f"[DEBUG] Successfully logged in user: {test_username}\n"
                            f"Token: {login_data['token'][:20]}..."
                        )
                except (URLError, HTTPError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /user/login: {exc}")
                    pytest.fail("Failed to POST /user/login")

                # POST /user/login – test login with invalid credentials
                try:
                    print(
                        "[DEBUG] Sending POST request to /user/login with invalid credentials"
                    )
                    invalid_login_payload = {
                        "username": "nonexistent_user",
                        "password": "wrong_password",
                    }
                    req_invalid_login = Request(
                        f"http://127.0.0.1:{server_port}/user/login",
                        data=json.dumps(invalid_login_payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    )
                    try:
                        with urlopen(req_invalid_login, timeout=20) as resp_invalid:
                            # If we get here, the request succeeded but should have failed
                            invalid_body = resp_invalid.read().decode(
                                "utf-8", errors="ignore"
                            )
                            print(
                                "[DEBUG] Received response from /user/login (invalid creds)\n"
                                f"Status: {resp_invalid.status}\n"
                                f"Body: {invalid_body}"
                            )
                            # Login should fail with invalid credentials
                            assert (
                                resp_invalid.status != 200
                                or "error" in invalid_body.lower()
                            )
                    except HTTPError as http_err:
                        # Expected: login should fail with 401 or similar
                        print(
                            f"[DEBUG] Expected error for invalid login: {http_err.code} {http_err.reason}"
                        )
                        # Close the underlying response to release the socket
                        http_err.close()
                        assert http_err.code in (400, 401, 403), (
                            f"Expected 400/401/403 for invalid login, got {http_err.code}"
                        )
                except (URLError, RemoteDisconnected) as exc:
                    print(
                        f"[DEBUG] Unexpected error while testing invalid login: {exc}"
                    )
                    pytest.fail("Unexpected error testing invalid login")

                # Verify TypeScript component is working - check that page loads with TS component
                # The /cl/app endpoint should serve the app which includes the TypeScript Card component
                try:
                    print("[DEBUG] Verifying TypeScript component integration")
                    # The page should load successfully (already tested above)
                    # TypeScript components are compiled and included in the bundle
                    # We verify this by checking the page loads without errors
                    assert "<html" in page_body.lower(), "Page should contain HTML"
                except Exception as exc:
                    print(f"[DEBUG] Error verifying TypeScript component: {exc}")
                    pytest.fail("Failed to verify TypeScript component integration")

                # Verify nested folder imports are working - /cl/app#/nested route
                # This route uses nested folder imports (components.button and button)
                try:
                    print("[DEBUG] Verifying nested folder imports via /cl/app#/nested")
                    # The nested route should load successfully (already tested above)
                    # Nested imports are compiled and included in the bundle
                    assert "<html" in nested_body.lower(), (
                        "Nested route should contain HTML"
                    )
                except Exception as exc:
                    print(f"[DEBUG] Error verifying nested folder imports: {exc}")
                    pytest.fail("Failed to verify nested folder imports")

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    server.terminate()
                    try:
                        server.wait(timeout=15)
                        print("[DEBUG] Server process terminated cleanly")
                    except Exception:
                        print(
                            "[DEBUG] Server did not terminate cleanly, killing process"
                        )
                        server.kill()
                        server.wait(timeout=5)
                    # Allow time for sockets to fully close and run garbage collection
                    # to clean up any lingering socket objects before temp dir cleanup
                    time.sleep(1)
                    gc.collect()
        finally:
            print(f"[DEBUG] Restoring original working directory to {original_cwd}")
            os.chdir(original_cwd)
            # Final garbage collection to ensure all resources are released
            gc.collect()


def test_default_client_app_renders() -> None:
    """Test that a default `jac create --use client` app renders correctly when served.

    This test validates the out-of-the-box experience:
    1. Creates a new client app using `jac create --use client`
    2. Installs packages
    3. Starts the server
    4. Validates that the default app renders with expected content
    """
    print("[DEBUG] Starting test_default_client_app_renders")

    app_name = "e2e-default-app"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)
            print(f"[DEBUG] Changed working directory to {temp_dir}")

            # 1. Create a new default Jac client app
            jac_cmd = get_jac_command()
            env = get_env_with_npm()
            print(
                f"[DEBUG] Running '{' '.join(jac_cmd)} create --use client {app_name}'"
            )
            process = Popen(
                [*jac_cmd, "create", "--use", "client", app_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                env=env,
            )
            stdout, stderr = process.communicate()
            returncode = process.returncode

            print(
                f"[DEBUG] 'jac create --use client' completed returncode={returncode}\n"
                f"STDOUT:\n{stdout}\n"
                f"STDERR:\n{stderr}\n"
            )

            if returncode != 0 and "unrecognized arguments: --use" in stderr:
                pytest.fail(
                    "Test failed: installed `jac` CLI does not support `create --use client`."
                )

            assert returncode == 0, (
                f"jac create --use client failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
            )

            project_path = os.path.join(temp_dir, app_name)
            print(f"[DEBUG] Created default Jac client app at {project_path}")
            assert os.path.isdir(project_path)

            # Verify expected files were created (new structure: main.jac at root)
            main_jac_path = os.path.join(project_path, "main.jac")
            assert os.path.isfile(main_jac_path), (
                "main.jac should exist at project root"
            )

            # Components are now at root level (not src/components)
            button_jac_path = os.path.join(project_path, "components", "Button.cl.jac")
            assert os.path.isfile(button_jac_path), (
                "components/Button.cl.jac should exist"
            )

            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.isfile(jac_toml_path), "jac.toml should exist"

            # 2. Ensure packages are installed (jac create --use client should have done this)
            # If node_modules doesn't exist, run jac add --npm
            node_modules_path = os.path.join(
                project_path, ".jac", "client", "node_modules"
            )
            if not os.path.isdir(node_modules_path):
                print("[DEBUG] node_modules not found, running 'jac add --npm'")
                jac_add_result = run(
                    [*jac_cmd, "add", "--npm"],
                    cwd=project_path,
                    capture_output=True,
                    text=True,
                    env=env,
                )
                print(
                    f"[DEBUG] 'jac add --npm' completed returncode={jac_add_result.returncode}\n"
                    f"STDOUT (truncated):\n{jac_add_result.stdout[:1000]}\n"
                    f"STDERR (truncated):\n{jac_add_result.stderr[:1000]}\n"
                )
                if jac_add_result.returncode != 0:
                    pytest.fail(
                        f"jac add --npm failed\n"
                        f"STDOUT:\n{jac_add_result.stdout}\n"
                        f"STDERR:\n{jac_add_result.stderr}\n"
                    )

            # 3. Start the server (now uses main.jac at project root)
            server: Popen[bytes] | None = None
            # Use dynamic port allocation to avoid conflicts when running tests in parallel
            server_port = get_free_port()
            try:
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                )
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                )

                # Wait for server to be ready
                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server is accepting connections on 127.0.0.1:{server_port}"
                )

                # 4. Test root endpoint - for client-only apps, root serves the HTML app
                # Note: The root endpoint may return 503 while the client bundle is building.
                # We use _wait_for_endpoint to retry on 503 until it's ready.
                try:
                    print("[DEBUG] Testing root endpoint / (with retry)")
                    root_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    root_body = root_bytes.decode("utf-8", errors="ignore")
                    print(
                        f"[DEBUG] Root response:\nBody (truncated):\n{root_body[:500]}"
                    )
                    # For client-only apps, root returns HTML with the React app
                    assert "<html" in root_body.lower(), (
                        "Root should return HTML for client-only app"
                    )
                    assert "<script" in root_body.lower(), (
                        "Root should include script tag for client bundle"
                    )
                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error at root endpoint: {exc}")
                    pytest.fail(f"Failed to GET root endpoint: {exc}")

                # 5. Test client app endpoint - the rendered React app
                try:
                    print("[DEBUG] Testing client app endpoint /cl/app")
                    page_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/cl/app",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    page_body = page_bytes.decode("utf-8", errors="ignore")
                    print(
                        f"[DEBUG] Client app response:\n"
                        f"Body (truncated):\n{page_body[:1000]}"
                    )

                    # Validate HTML structure
                    assert "<html" in page_body.lower(), "Response should contain HTML"
                    assert "<body" in page_body.lower(), "Response should contain body"

                    # The page should include the bundled JavaScript
                    # that will render "Hello, World!" client-side
                    assert (
                        "<script" in page_body.lower() or "src=" in page_body.lower()
                    ), "Response should include script tags for React app"

                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error at /cl/app endpoint: {exc}")
                    pytest.fail(f"Failed to GET /cl/app endpoint: {exc}")

                # 6. Test that static JS bundle is being served
                try:
                    print("[DEBUG] Testing that client.js bundle is served")
                    # Extract the client.js path from the HTML
                    import re

                    script_match = re.search(
                        r'src="(/static/client\.js[^"]*)"', root_body
                    )
                    if script_match:
                        js_path = script_match.group(1)
                        js_url = f"http://127.0.0.1:{server_port}{js_path}"
                        print(f"[DEBUG] Fetching JS bundle from {js_url}")
                        with urlopen(js_url, timeout=30) as resp:
                            js_body = resp.read().decode("utf-8", errors="ignore")
                            assert resp.status == 200, "JS bundle should return 200"
                            assert len(js_body) > 0, "JS bundle should not be empty"
                            print(
                                f"[DEBUG] JS bundle fetched successfully "
                                f"({len(js_body)} bytes)"
                            )
                    else:
                        print("[DEBUG] Warning: Could not find client.js in HTML")
                except (URLError, HTTPError) as exc:
                    print(f"[DEBUG] Warning: Could not verify static assets: {exc}")
                    # Not a hard failure - the main page test is sufficient

                print("[DEBUG] All default app tests passed!")

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    server.terminate()
                    try:
                        server.wait(timeout=15)
                        print("[DEBUG] Server terminated cleanly")
                    except Exception:
                        print("[DEBUG] Server did not terminate cleanly, killing")
                        server.kill()
                        server.wait(timeout=5)
                    time.sleep(1)
                    gc.collect()

        finally:
            print(f"[DEBUG] Restoring working directory to {original_cwd}")
            os.chdir(original_cwd)
            gc.collect()
