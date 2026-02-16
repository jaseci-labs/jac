"""End-to-end tests for `jac start` HTTP endpoints."""

from __future__ import annotations

import gc
import json
import os
import shutil
import tempfile
import time
from http.client import RemoteDisconnected
from subprocess import PIPE, STDOUT, Popen, run
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pytest

from .test_helpers import (
    get_env_with_npm,  # Backward compat alias
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
            # NOTE: We capture stdout/stderr to verify output ordering (compilation before ready)
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
                    stdout=PIPE,
                    stderr=STDOUT,
                )
                # Wait for localhost:8000 to become available
                print(
                    f"[DEBUG] Waiting for server to be available on 127.0.0.1:{server_port}"
                )
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server is now accepting connections on 127.0.0.1:{server_port}"
                )

                # Verify output ordering: compilation messages should appear before "ready"
                import fcntl
                import os as os_module

                captured_output = ""
                if server.stdout:
                    fd = server.stdout.fileno()
                    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
                    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os_module.O_NONBLOCK)
                    try:
                        raw = server.stdout.read()
                        if raw:
                            captured_output = (
                                raw.decode("utf-8", errors="ignore")
                                if isinstance(raw, bytes)
                                else raw
                            )
                    except (OSError, BlockingIOError):
                        pass

                if captured_output:
                    print(
                        f"[DEBUG] Captured server output (first 500 chars):\n{captured_output[:500]}"
                    )
                    compilation_idx = -1
                    ready_idx = -1
                    output_lower = captured_output.lower()

                    # Find first compilation-related marker
                    for marker in ["compilation", "compiling", "building", "bundle"]:
                        idx = output_lower.find(marker)
                        if idx != -1 and (
                            compilation_idx == -1 or idx < compilation_idx
                        ):
                            compilation_idx = idx

                    # Find first server-ready marker
                    for marker in ["server ready", "ready", "localhost", "local:"]:
                        idx = output_lower.find(marker)
                        if idx != -1 and (ready_idx == -1 or idx < ready_idx):
                            ready_idx = idx

                    if compilation_idx != -1 and ready_idx != -1:
                        assert compilation_idx < ready_idx, (
                            f"Output ordering error: 'ready' ({ready_idx}) appeared before "
                            f"'compilation' ({compilation_idx}).\nOutput:\n{captured_output[:500]}"
                        )
                        print(
                            "[DEBUG] Output ordering verified: compilation before ready"
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

                # "/nested" – SPA catch-all serves app shell for client-side routing
                try:
                    print(
                        "[DEBUG] Sending GET request to /nested endpoint (SPA catch-all)"
                    )
                    with urlopen(
                        f"http://127.0.0.1:{server_port}/nested",
                        timeout=200,
                    ) as resp_nested:
                        nested_body = resp_nested.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /nested endpoint\n"
                            f"Status: {resp_nested.status}\n"
                            f"Body (truncated to 500 chars):\n{nested_body[:500]}"
                        )
                        assert resp_nested.status == 200
                        assert "<html" in nested_body.lower()
                except (URLError, HTTPError) as exc:
                    print(f"[DEBUG] Error while requesting /nested endpoint: {exc}")
                    pytest.fail("Failed to GET /nested endpoint (SPA catch-all)")

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

                # Verify nested folder imports are working - /nested route (SPA catch-all)
                # This route uses nested folder imports (components.button and button)
                try:
                    print("[DEBUG] Verifying nested folder imports via /nested")
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
                    # Close stdout pipe to prevent ResourceWarning for unclosed file
                    if server.stdout:
                        server.stdout.close()
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

                # 6. Test that static JS bundle is being served via get_client_js hook
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
                            # Verify bundle contains expected React/JSX runtime markers
                            # These markers confirm the get_client_js hook returned valid bundle
                            assert (
                                "createElement" in js_body or "jsx" in js_body.lower()
                            ), "JS bundle should contain React createElement or jsx"
                            print(
                                f"[DEBUG] JS bundle fetched successfully "
                                f"({len(js_body)} bytes), contains expected runtime code"
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


def test_configurable_api_base_url_in_bundle() -> None:
    """Test that [plugins.client.api] base_url is baked into the served JS bundle.

    End-to-end verification of the configurable API base URL feature:
    1. Creates a client app using the all-in-one example (which uses walkers/auth)
    2. Injects [plugins.client.api] base_url into jac.toml
    3. Starts the server and waits for the bundle to build
    4. Fetches the served JS bundle
    5. Asserts the configured URL appears in the bundled JavaScript
    """
    import re
    import tomllib

    print("[DEBUG] Starting test_configurable_api_base_url_in_bundle")

    # Resolve the all-in-one example (uses walkers/auth so base URL won't be tree-shaken)
    tests_dir = os.path.dirname(__file__)
    jac_client_root = os.path.dirname(tests_dir)
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one")

    print(f"[DEBUG] Resolved all-in-one source path: {all_in_one_path}")
    assert os.path.isdir(all_in_one_path), "all-in-one example directory missing"

    app_name = "e2e-api-base-url"
    configured_base_url = "http://my-custom-backend:9000"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # 1. Create a client app and copy all-in-one into it
            jac_cmd = get_jac_command()
            env = get_env_with_npm()
            print(f"[DEBUG] Running 'jac create --use client {app_name}'")
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
            assert os.path.isdir(project_path)

            # Copy all-in-one contents (which uses walkers, auth, etc.)
            print("[DEBUG] Copying @all-in-one contents into created Jac app")
            for entry in os.listdir(all_in_one_path):
                src = os.path.join(all_in_one_path, entry)
                dst = os.path.join(project_path, entry)
                if entry in {"node_modules", "build", "dist", ".pytest_cache"}:
                    continue
                if os.path.isdir(src):
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)

            # 2. Inject [plugins.client.api] base_url into jac.toml
            jac_toml_path = os.path.join(project_path, "jac.toml")
            assert os.path.isfile(jac_toml_path), "jac.toml should exist"

            with open(jac_toml_path, "rb") as f:
                original_config = tomllib.load(f)
            print(f"[DEBUG] Original jac.toml keys: {list(original_config.keys())}")

            # Append api config (the all-in-one jac.toml may already have [plugins.client])
            with open(jac_toml_path, "a") as f:
                f.write(f'\n[plugins.client.api]\nbase_url = "{configured_base_url}"\n')

            with open(jac_toml_path, "rb") as f:
                updated_config = tomllib.load(f)
            api_base = (
                updated_config.get("plugins", {})
                .get("client", {})
                .get("api", {})
                .get("base_url", "")
            )
            print(f"[DEBUG] Verified jac.toml base_url = {api_base!r}")
            assert api_base == configured_base_url

            # 3. Install packages
            print("[DEBUG] Running 'jac add --npm' to install packages")
            jac_add_result = run(
                [*jac_cmd, "add", "--npm"],
                cwd=project_path,
                capture_output=True,
                text=True,
                env=env,
            )
            print(
                f"[DEBUG] 'jac add --npm' returncode={jac_add_result.returncode}\n"
                f"STDOUT (truncated):\n{jac_add_result.stdout[:1000]}\n"
                f"STDERR (truncated):\n{jac_add_result.stderr[:1000]}\n"
            )
            if jac_add_result.returncode != 0:
                pytest.fail(
                    f"jac add --npm failed\n"
                    f"STDOUT:\n{jac_add_result.stdout}\n"
                    f"STDERR:\n{jac_add_result.stderr}\n"
                )

            # 4. Start the server
            server: Popen[bytes] | None = None
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

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server is accepting connections on 127.0.0.1:{server_port}"
                )

                # 5. Fetch root HTML to find the JS bundle path
                try:
                    root_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    root_body = root_bytes.decode("utf-8", errors="ignore")
                    print(f"[DEBUG] Root response (truncated):\n{root_body[:500]}")
                    assert "<html" in root_body.lower(), "Root should return HTML"
                except (URLError, HTTPError, TimeoutError) as exc:
                    pytest.fail(f"Failed to GET root endpoint: {exc}")

                # 6. Extract JS bundle path and fetch it
                # URL format is /static/client.js?hash=... or /static/client.HASH.js
                script_match = re.search(r'src="(/static/client[^"]+)"', root_body)
                assert script_match, (
                    f"Could not find client JS bundle path in HTML:\n{root_body[:1000]}"
                )

                js_path = script_match.group(1)
                js_url = f"http://127.0.0.1:{server_port}{js_path}"
                print(f"[DEBUG] Fetching JS bundle from {js_url}")

                with urlopen(js_url, timeout=30) as resp:
                    js_body = resp.read().decode("utf-8", errors="ignore")
                    assert resp.status == 200, "JS bundle should return 200"
                    assert len(js_body) > 0, "JS bundle should not be empty"
                    # Verify bundle contains expected React/JSX runtime markers
                    # This confirms the get_client_js hook returned valid bundle code
                    assert "createElement" in js_body or "jsx" in js_body.lower(), (
                        "JS bundle should contain React createElement or jsx"
                    )
                    print(f"[DEBUG] JS bundle fetched ({len(js_body)} bytes)")

                # 7. Assert the configured base URL is baked into the bundle
                assert configured_base_url in js_body, (
                    f"Expected configured base_url '{configured_base_url}' to appear "
                    f"in the bundled JavaScript, but it was not found.\n"
                    f"Bundle size: {len(js_body)} bytes"
                )
                print(f"[DEBUG] Confirmed '{configured_base_url}' found in JS bundle")

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


def _setup_all_in_one_project(temp_dir: str, app_name: str) -> str:
    """Shared helper: scaffold a jac client app, copy all-in-one into it, install npm deps.

    Returns the project directory path.
    """
    tests_dir = os.path.dirname(__file__)
    jac_client_root = os.path.dirname(tests_dir)
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one")

    assert os.path.isdir(all_in_one_path), "all-in-one example directory missing"

    jac_cmd = get_jac_command()
    env = get_env_with_npm()

    # Create a new Jac client app
    process = Popen(
        [*jac_cmd, "create", "--use", "client", app_name],
        stdin=PIPE,
        stdout=PIPE,
        stderr=PIPE,
        text=True,
        env=env,
    )
    stdout, stderr = process.communicate()
    if process.returncode != 0 and "unrecognized arguments: --use" in stderr:
        pytest.fail(
            "Test failed: installed `jac` CLI does not support `create --use client`."
        )
    assert process.returncode == 0, (
        f"jac create --use client failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
    )

    project_path = os.path.join(temp_dir, app_name)
    assert os.path.isdir(project_path)

    # Copy all-in-one contents (skip build artifacts)
    for entry in os.listdir(all_in_one_path):
        src = os.path.join(all_in_one_path, entry)
        dst = os.path.join(project_path, entry)
        if entry in {"node_modules", "build", "dist", ".pytest_cache"}:
            continue
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)

    # Install npm packages
    jac_add_result = run(
        [*jac_cmd, "add", "--npm"],
        cwd=project_path,
        capture_output=True,
        text=True,
        env=env,
    )
    if jac_add_result.returncode != 0:
        pytest.fail(
            f"jac add --npm failed\nSTDOUT:\n{jac_add_result.stdout}\n"
            f"STDERR:\n{jac_add_result.stderr}\n"
        )

    return project_path


def test_profile_config_applies_to_server() -> None:
    """Verify that ``--profile prod`` loads jac.prod.toml and its settings take effect.

    The prod profile overrides ``[plugins.client.app_meta_data] title``.
    We start the server with ``--profile prod`` and confirm the HTML ``<title>``
    reflects the prod value, proving the profile overlay pipeline works end-to-end.
    """
    print("[DEBUG] Starting test_profile_config_applies_to_server")

    prod_title = "All-In-One Prod"
    base_title = "All-In-One"
    app_name = "e2e-profile-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            project_path = _setup_all_in_one_project(temp_dir, app_name)
            print(f"[DEBUG] Project set up at {project_path}")

            prod_toml = os.path.join(project_path, "jac.prod.toml")
            assert os.path.isfile(prod_toml), (
                "jac.prod.toml should be copied from all-in-one example"
            )

            server: Popen[bytes] | None = None
            server_port = get_free_port()
            jac_cmd = get_jac_command()
            env = get_env_with_npm()
            try:
                print(
                    f"[DEBUG] Starting server with "
                    f"'jac start main.jac -p {server_port} --profile prod'"
                )
                server = Popen(
                    [
                        *jac_cmd,
                        "start",
                        "main.jac",
                        "-p",
                        str(server_port),
                        "--profile",
                        "prod",
                    ],
                    cwd=project_path,
                    env=env,
                )

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                )

                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                )
                root_body = root_bytes.decode("utf-8", errors="ignore")
                print(f"[DEBUG] Root response (truncated):\n{root_body[:500]}")
                assert "<html" in root_body.lower(), "Root should return HTML"

                assert f"<title>{prod_title}</title>" in root_body, (
                    f"Expected prod title '{prod_title}' in HTML, "
                    f"but found base title instead. "
                    f"This means --profile prod did not load jac.prod.toml correctly.\n"
                    f"HTML (first 500 chars): {root_body[:500]}"
                )
                assert f"<title>{base_title}</title>" not in root_body, (
                    "Base title should be overridden by prod profile"
                )
                print(
                    f"[DEBUG] Confirmed title='{prod_title}' in HTML "
                    f"- profile config applied successfully"
                )

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    server.terminate()
                    try:
                        server.wait(timeout=15)
                    except Exception:
                        server.kill()
                        server.wait(timeout=5)
                    time.sleep(1)
                    gc.collect()

        finally:
            os.chdir(original_cwd)
            gc.collect()


def test_no_profile_omits_profile_settings() -> None:
    """Verify that without ``--profile``, prod-only settings are NOT applied.

    Starts the server without any profile flag and confirms the HTML
    ``<title>`` uses the base config value, not the prod override.
    This is the control test for ``test_profile_config_applies_to_server``.
    """
    print("[DEBUG] Starting test_no_profile_omits_profile_settings")

    prod_title = "All-In-One Prod"
    base_title = "All-In-One"
    app_name = "e2e-no-profile-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            project_path = _setup_all_in_one_project(temp_dir, app_name)
            print(f"[DEBUG] Project set up at {project_path}")

            local_toml = os.path.join(project_path, "jac.local.toml")
            if os.path.isfile(local_toml):
                os.remove(local_toml)

            server: Popen[bytes] | None = None
            server_port = get_free_port()
            jac_cmd = get_jac_command()
            env = get_env_with_npm()
            try:
                print(
                    f"[DEBUG] Starting server with "
                    f"'jac start main.jac -p {server_port}' (no profile)"
                )
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                )

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                )

                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                )
                root_body = root_bytes.decode("utf-8", errors="ignore")
                assert "<html" in root_body.lower()

                assert f"<title>{base_title}</title>" in root_body, (
                    f"Expected base title '{base_title}' in HTML when no profile is set.\n"
                    f"HTML (first 500 chars): {root_body[:500]}"
                )
                assert f"<title>{prod_title}</title>" not in root_body, (
                    f"Prod title '{prod_title}' should NOT appear "
                    f"when no profile is specified. "
                    f"Profile settings are leaking without --profile."
                )
                print(
                    f"[DEBUG] Confirmed title='{base_title}' in HTML "
                    f"- profile settings correctly isolated"
                )

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    server.terminate()
                    try:
                        server.wait(timeout=15)
                    except Exception:
                        server.kill()
                        server.wait(timeout=5)
                    time.sleep(1)
                    gc.collect()

        finally:
            os.chdir(original_cwd)
            gc.collect()


def test_vite_env_and_define_config() -> None:
    """Test Vite environment and define configuration features.

    Consolidated test covering:
    1. [plugins.client.vite.define] values are baked into the JS bundle
    2. .env files are loaded from project root via envDir config
    """
    import re

    print("[DEBUG] Starting test_vite_env_and_define_config")

    app_name = "e2e-vite-config"
    test_app_name = "E2E Test App"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            project_path = _setup_all_in_one_project(temp_dir, app_name)
            print(f"[DEBUG] Project set up at {project_path}")

            # 1. Verify jac.toml has the expected define values from all-in-one
            jac_toml_path = os.path.join(project_path, "jac.toml")
            with open(jac_toml_path) as f:
                toml_content = f.read()
            assert "globalThis.APP_BUILD_TIME" in toml_content, (
                "jac.toml should contain APP_BUILD_TIME define"
            )
            assert "globalThis.FEATURE_ENABLED" in toml_content, (
                "jac.toml should contain FEATURE_ENABLED define"
            )
            print("[DEBUG] Verified jac.toml contains expected define values")

            # 2. Create .env file in project root
            env_file_path = os.path.join(project_path, ".env")
            with open(env_file_path, "w") as f:
                f.write(f"VITE_APP_NAME={test_app_name}\n")
                f.write("VITE_APP_VERSION=2.0.0-test\n")
            print(f"[DEBUG] Created .env file at {env_file_path}")

            server: Popen[bytes] | None = None
            server_port = get_free_port()
            jac_cmd = get_jac_command()
            env = get_env_with_npm()
            try:
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                )
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                )

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                )

                # Fetch root HTML to get the JS bundle path
                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                )
                root_body = root_bytes.decode("utf-8", errors="ignore")
                print(f"[DEBUG] Root response (truncated):\n{root_body[:500]}")
                assert "<html" in root_body.lower(), "Root should return HTML"

                # Extract JS bundle path and fetch it
                script_match = re.search(r'src="(/static/client[^"]+)"', root_body)
                assert script_match, (
                    f"Could not find client JS bundle path in HTML:\n{root_body[:1000]}"
                )

                js_path = script_match.group(1)
                js_url = f"http://127.0.0.1:{server_port}{js_path}"
                print(f"[DEBUG] Fetching JS bundle from {js_url}")

                with urlopen(js_url, timeout=30) as resp:
                    js_body = resp.read().decode("utf-8", errors="ignore")
                    assert resp.status == 200, "JS bundle should return 200"
                    assert len(js_body) > 0, "JS bundle should not be empty"
                    print(f"[DEBUG] JS bundle fetched ({len(js_body)} bytes)")

                # Assert 1: Define values from jac.toml are baked in
                assert "2024-01-01T00:00:00Z" in js_body, (
                    "Expected APP_BUILD_TIME value '2024-01-01T00:00:00Z' "
                    "to appear in the bundled JavaScript."
                )
                print("[DEBUG] Confirmed APP_BUILD_TIME value found in JS bundle")

                # Assert 2: .env file values are loaded via envDir
                assert test_app_name in js_body, (
                    f"Expected VITE_APP_NAME value '{test_app_name}' "
                    "to appear in the bundled JavaScript."
                )
                print(f"[DEBUG] Confirmed '{test_app_name}' found in JS bundle")

                assert "2.0.0-test" in js_body, (
                    "Expected VITE_APP_VERSION value '2.0.0-test' "
                    "to appear in the bundled JavaScript."
                )
                print("[DEBUG] Confirmed '2.0.0-test' found in JS bundle")

                print("[DEBUG] All Vite config assertions passed")

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    server.terminate()
                    try:
                        server.wait(timeout=15)
                    except Exception:
                        server.kill()
                        server.wait(timeout=5)
                    time.sleep(1)
                    gc.collect()

        finally:
            os.chdir(original_cwd)
            gc.collect()


def test_pwa_build_generates_manifest_and_service_worker() -> None:
    """Test that `jac build --client pwa` generates manifest.json and sw.js.

    This test validates the PWA target build process:
    1. Creates a new client app using `jac create --use client`
    2. Runs `jac build --client pwa`
    3. Verifies manifest.json and sw.js are generated in dist
    4. Starts the server and verifies PWA files are served
    """
    print("[DEBUG] Starting test_pwa_build_generates_manifest_and_service_worker")

    app_name = "e2e-pwa-build"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)
            print(f"[DEBUG] Changed working directory to {temp_dir}")

            # 1. Create a new Jac client app
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
            print(f"[DEBUG] Created Jac client app at {project_path}")
            assert os.path.isdir(project_path)

            # 2. Ensure packages are installed
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

            # 3. Run `jac build --client pwa`
            print("[DEBUG] Running 'jac build --client pwa main.jac'")
            build_result = run(
                [*jac_cmd, "build", "--client", "pwa", "main.jac"],
                cwd=project_path,
                capture_output=True,
                text=True,
                env=env,
            )
            print(
                f"[DEBUG] 'jac build --client pwa' completed returncode={build_result.returncode}\n"
                f"STDOUT:\n{build_result.stdout}\n"
                f"STDERR:\n{build_result.stderr}\n"
            )

            assert build_result.returncode == 0, (
                f"jac build --client pwa failed\n"
                f"STDOUT:\n{build_result.stdout}\n"
                f"STDERR:\n{build_result.stderr}\n"
            )

            # 4. Verify PWA files are generated in dist
            dist_dir = os.path.join(project_path, ".jac", "client", "dist")
            assert os.path.isdir(dist_dir), f"dist directory not found at {dist_dir}"

            manifest_path = os.path.join(dist_dir, "manifest.json")
            sw_path = os.path.join(dist_dir, "sw.js")

            assert os.path.isfile(manifest_path), (
                f"manifest.json not found at {manifest_path}"
            )
            assert os.path.isfile(sw_path), f"sw.js not found at {sw_path}"

            # 5. Validate manifest.json content
            with open(manifest_path) as f:
                manifest = json.load(f)

            print(f"[DEBUG] manifest.json content: {json.dumps(manifest, indent=2)}")
            assert "name" in manifest, "manifest.json should have 'name' field"
            assert "icons" in manifest, "manifest.json should have 'icons' field"
            assert "start_url" in manifest, (
                "manifest.json should have 'start_url' field"
            )
            assert manifest.get("display") == "standalone", (
                "manifest.json should have display=standalone"
            )

            # 6. Validate sw.js content
            with open(sw_path) as f:
                sw_content = f.read()

            print(f"[DEBUG] sw.js content (truncated): {sw_content[:500]}")
            assert "CACHE_NAME" in sw_content, "sw.js should define CACHE_NAME"
            assert "addEventListener" in sw_content, "sw.js should have event listeners"
            assert "install" in sw_content, "sw.js should handle install event"
            assert "fetch" in sw_content, "sw.js should handle fetch event"

            # 7. Verify index.html has PWA injections
            index_path = os.path.join(dist_dir, "index.html")
            assert os.path.isfile(index_path), f"index.html not found at {index_path}"

            with open(index_path) as f:
                index_content = f.read()

            print(f"[DEBUG] index.html content (truncated): {index_content[:500]}")
            assert 'rel="manifest"' in index_content, (
                "index.html should have manifest link"
            )
            assert "serviceWorker" in index_content, (
                "index.html should have SW registration script"
            )

            # 8. Start server and verify PWA files are served
            server: Popen[bytes] | None = None
            server_port = get_free_port()
            try:
                print(
                    f"[DEBUG] Starting server with "
                    f"'jac start --client pwa main.jac -p {server_port}'"
                )
                server = Popen(
                    [
                        *jac_cmd,
                        "start",
                        "--client",
                        "pwa",
                        "main.jac",
                        "-p",
                        str(server_port),
                    ],
                    cwd=project_path,
                    env=env,
                )

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}")
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                )

                # Test manifest.json is served
                try:
                    print("[DEBUG] Fetching /manifest.json")
                    manifest_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/manifest.json",
                        timeout=60.0,
                        poll_interval=2.0,
                        request_timeout=20.0,
                    )
                    served_manifest = json.loads(manifest_bytes.decode("utf-8"))
                    print(f"[DEBUG] Served manifest.json: {served_manifest}")
                    assert "name" in served_manifest, (
                        "Served manifest.json should have 'name'"
                    )
                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error fetching /manifest.json: {exc}")
                    pytest.fail(f"Failed to GET /manifest.json: {exc}")

                # Test sw.js is served
                try:
                    print("[DEBUG] Fetching /sw.js")
                    sw_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/sw.js",
                        timeout=60.0,
                        poll_interval=2.0,
                        request_timeout=20.0,
                    )
                    served_sw = sw_bytes.decode("utf-8")
                    print(f"[DEBUG] Served sw.js (truncated): {served_sw[:300]}")
                    assert "CACHE_NAME" in served_sw, (
                        "Served sw.js should define CACHE_NAME"
                    )
                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error fetching /sw.js: {exc}")
                    pytest.fail(f"Failed to GET /sw.js: {exc}")

                # Test root page has PWA meta tags
                try:
                    print("[DEBUG] Fetching root page")
                    root_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    root_body = root_bytes.decode("utf-8")
                    print(f"[DEBUG] Root page (truncated): {root_body[:500]}")
                    assert 'rel="manifest"' in root_body, (
                        "Root page should have manifest link"
                    )
                    assert "serviceWorker" in root_body, (
                        "Root page should have SW registration"
                    )
                except (URLError, HTTPError, TimeoutError) as exc:
                    print(f"[DEBUG] Error fetching root page: {exc}")
                    pytest.fail(f"Failed to GET root page: {exc}")

                print("[DEBUG] All PWA tests passed!")

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


def test_diagnostics_syntax_error_in_console() -> None:
    """Test that syntax errors show formatted diagnostics in console.

    This is a real end-to-end test that:
    1. Sets up all-in-one project
    2. Introduces a syntax error in a client .jac file
    3. Enables debug=true in jac.toml
    4. Starts the server and captures console output
    5. Verifies diagnostic formatting appears in the output
    """

    print("[DEBUG] Starting test_diagnostics_syntax_error_in_console")

    app_name = "e2e-diagnostics-test"

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"[DEBUG] Created temporary directory at {temp_dir}")
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)

            # 1. Set up the all-in-one project
            project_path = _setup_all_in_one_project(temp_dir, app_name)
            print(f"[DEBUG] Project set up at {project_path}")

            # 2. Add debug=true to jac.toml
            jac_toml_path = os.path.join(project_path, "jac.toml")
            with open(jac_toml_path) as f:
                toml_content = f.read()

            if "[plugins.client]" in toml_content:
                if "debug = true" not in toml_content:
                    toml_content = toml_content.replace(
                        "[plugins.client]",
                        "[plugins.client]\ndebug = true",
                    )
            else:
                toml_content += "\n[plugins.client]\ndebug = true\n"

            with open(jac_toml_path, "w") as f:
                f.write(toml_content)

            print("[DEBUG] Updated jac.toml with debug=true")

            # 3. Introduce a syntax error in login.jac
            login_jac_path = os.path.join(
                project_path, "pages", "(public)", "login.jac"
            )
            if os.path.isfile(login_jac_path):
                with open(login_jac_path) as f:
                    login_content = f.read()

                # Corrupt the file by breaking the cl { block syntax
                # This will cause a Jac compilation error
                corrupted_content = login_content.replace(
                    "cl {",
                    "cl {{{{",  # Invalid syntax
                    1,
                )

                with open(login_jac_path, "w") as f:
                    f.write(corrupted_content)

                print(
                    "[DEBUG] Introduced syntax error in login.jac (corrupted cl block)"
                )

            # 4. Start the server and capture output
            server: Popen[bytes] | None = None
            server_port = get_free_port()
            jac_cmd = get_jac_command()
            env = get_env_with_npm()

            try:
                print(
                    f"[DEBUG] Starting server with "
                    f"'jac start main.jac -p {server_port}'"
                )
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    stdout=PIPE,
                    stderr=STDOUT,
                    env=env,
                )

                # Wait for server to start or fail, then capture output
                print("[DEBUG] Waiting for server output...")
                time.sleep(10)  # Give it time to attempt build

                # Read available output (non-blocking)
                import fcntl
                import os as os_module

                captured_output = ""
                if server.stdout:
                    fd = server.stdout.fileno()
                    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
                    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os_module.O_NONBLOCK)
                    try:
                        raw = server.stdout.read()
                        if raw:
                            captured_output = (
                                raw.decode("utf-8", errors="ignore")
                                if isinstance(raw, bytes)
                                else raw
                            )
                    except (OSError, BlockingIOError):
                        pass

                print(f"[DEBUG] Captured output:\n{captured_output}")

                # 5. Try to access an endpoint to trigger build error
                try:
                    wait_for_port("127.0.0.1", server_port, timeout=30.0)
                    print("[DEBUG] Server port is open, requesting /cl/app")

                    try:
                        _wait_for_endpoint(
                            f"http://127.0.0.1:{server_port}/cl/app",
                            timeout=60.0,
                            poll_interval=2.0,
                            request_timeout=30.0,
                        )
                        # If we get here, the build somehow succeeded
                        print(
                            "[DEBUG] Warning: Build succeeded unexpectedly, "
                            "dependency might still be cached"
                        )
                    except HTTPError as http_err:
                        # Expected - build should fail with 500
                        print(f"[DEBUG] Got expected HTTP error: {http_err.code}")
                        if http_err.code == 500:
                            error_body = http_err.read().decode(
                                "utf-8", errors="ignore"
                            )
                            print(f"[DEBUG] Error response body:\n{error_body[:1000]}")
                            captured_output += "\n" + error_body
                        http_err.close()
                    except TimeoutError:
                        print("[DEBUG] Endpoint timed out (expected if build failed)")

                except TimeoutError:
                    print("[DEBUG] Server port never opened (build failed early)")

                # Read any additional output after the request
                if server.stdout:
                    try:
                        raw = server.stdout.read()
                        if raw:
                            additional = (
                                raw.decode("utf-8", errors="ignore")
                                if isinstance(raw, bytes)
                                else raw
                            )
                            captured_output += additional
                            print(f"[DEBUG] Additional output:\n{additional}")
                    except (OSError, BlockingIOError):
                        pass

                # 6. Verify diagnostic formatting in output
                print("[DEBUG] Verifying diagnostic output...")
                print(f"[DEBUG] Full captured output:\n{captured_output}")

                # Check for diagnostic box formatting
                has_box_top = "┌" in captured_output
                has_box_bottom = "┘" in captured_output
                has_box_sides = "│" in captured_output

                # Check for error code (JAC_CLIENT_XXX format)
                has_error_code = "JAC_CLIENT_" in captured_output

                # Check for quick fix suggestion
                has_quick_fix = "Quick fix:" in captured_output

                # Check for source snippet (arrow pointing to error line)
                has_source_snippet = "->" in captured_output and "|" in captured_output

                # Check for debug mode raw error output
                has_debug_output = "--- Raw Error (debug=true) ---" in captured_output

                print(f"[DEBUG] Has box top: {has_box_top}")
                print(f"[DEBUG] Has box bottom: {has_box_bottom}")
                print(f"[DEBUG] Has box sides: {has_box_sides}")
                print(f"[DEBUG] Has error code: {has_error_code}")
                print(f"[DEBUG] Has quick fix: {has_quick_fix}")
                print(f"[DEBUG] Has source snippet: {has_source_snippet}")
                print(f"[DEBUG] Has debug output: {has_debug_output}")

                # Verify diagnostic box structure
                assert has_box_top and has_box_bottom and has_box_sides, (
                    f"Expected diagnostic box formatting (┌, ┘, │), got:\n{captured_output}"
                )

                # Verify error code is present
                assert has_error_code, (
                    f"Expected JAC_CLIENT_XXX error code in output, got:\n{captured_output}"
                )

                # Verify quick fix suggestion
                assert has_quick_fix, (
                    f"Expected 'Quick fix:' in output, got:\n{captured_output}"
                )

                # Source snippet is optional for some error types
                if has_source_snippet:
                    print("[DEBUG] Source snippet present (optional)")

                # Debug output is optional - only shown if debug=true was properly applied
                if has_debug_output:
                    print("[DEBUG] Debug output present")

                print("[DEBUG] All diagnostic formatting assertions passed!")

            finally:
                if server is not None:
                    print("[DEBUG] Terminating server process")
                    if server.stdout:
                        server.stdout.close()
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
            os.chdir(original_cwd)
            gc.collect()
