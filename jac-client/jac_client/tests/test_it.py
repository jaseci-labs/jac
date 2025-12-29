"""End-to-end tests for `jac serve` HTTP endpoints."""

from __future__ import annotations

import gc
import json
import os
import shutil
import socket
import tempfile
import time
from http.client import RemoteDisconnected
from subprocess import PIPE, Popen, run
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pytest

from jaclang.pycore.runtime import JacRuntime as Jac


@pytest.fixture(autouse=True)
def reset_jac_machine():
    """Reset Jac machine before and after each test."""
    Jac.reset_machine()
    yield
    Jac.reset_machine()


def _wait_for_port(
    host: str,
    port: int,
    timeout: float = 60.0,
    poll_interval: float = 0.5,
) -> None:
    """Block until a TCP port is accepting connections or timeout.

    Raises:
        TimeoutError: if the port is not accepting connections within timeout.
    """
    deadline = time.time() + timeout
    last_err: Exception | None = None

    while time.time() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(poll_interval)
            try:
                sock.connect((host, port))
                return
            except OSError as exc:  # Connection refused / timeout
                last_err = exc
                time.sleep(poll_interval)

    raise TimeoutError(
        f"Timed out waiting for {host}:{port} to become available. Last error: {last_err}"
    )


def _wait_for_endpoint(
    url: str,
    timeout: float = 120.0,
    poll_interval: float = 2.0,
    request_timeout: float = 30.0,
) -> bytes:
    """Block until an HTTP endpoint returns a successful response or timeout.

    Retries on 503 Service Unavailable and connection errors.

    Returns:
        The response body as bytes.

    Raises:
        TimeoutError: if the endpoint does not return success within timeout.
        HTTPError: if the endpoint returns a non-retryable error.
    """
    deadline = time.time() + timeout
    last_err: Exception | None = None

    while time.time() < deadline:
        try:
            with urlopen(url, timeout=request_timeout) as resp:
                return resp.read()
        except HTTPError as exc:
            if exc.code == 503:
                # Service Unavailable - retry
                # Close the underlying response to release the socket
                exc.close()
                last_err = exc
                print(f"[DEBUG] Endpoint {url} returned 503, retrying...")
                time.sleep(poll_interval)
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
        "[DEBUG] Starting test_all_in_one_app_endpoints using jac create --cl + @all-in-one"
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
            print(f"[DEBUG] Running 'jac create --cl {app_name}'")
            process = Popen(
                ["jac", "create", "--cl", app_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            returncode = process.returncode

            print(
                "[DEBUG] 'jac create --cl' completed "
                f"returncode={returncode}\n"
                f"STDOUT:\n{stdout}\n"
                f"STDERR:\n{stderr}\n"
            )

            # If the currently installed `jac` CLI does not support `create --cl`,
            # fail the test instead of skipping it.
            if returncode != 0 and "unrecognized arguments: --cl" in stderr:
                pytest.fail(
                    "Test failed: installed `jac` CLI does not support `create --cl`."
                )

            assert returncode == 0, (
                f"jac create --cl failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
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

            # 3. Install packages from jac.toml using `jac add --cl`
            # This reads packages from jac.toml, generates package.json, and runs npm install
            print("[DEBUG] Running 'jac add --cl' to install packages from jac.toml")
            jac_add_result = run(
                ["jac", "add", "--cl"],
                cwd=project_path,
                capture_output=True,
                text=True,
            )
            print(
                "[DEBUG] 'jac add --cl' completed "
                f"returncode={jac_add_result.returncode}\n"
                f"STDOUT (truncated to 2000 chars):\n{jac_add_result.stdout[:2000]}\n"
                f"STDERR (truncated to 2000 chars):\n{jac_add_result.stderr[:2000]}\n"
            )

            if jac_add_result.returncode != 0:
                pytest.fail(
                    f"Test failed: jac add --cl failed or npm is not available in PATH.\n"
                    f"STDOUT:\n{jac_add_result.stdout}\n"
                    f"STDERR:\n{jac_add_result.stderr}\n"
                )

            app_jac_path = os.path.join(project_path, "src", "app.jac")
            assert os.path.isfile(app_jac_path), "all-in-one src/app.jac file missing"

            # 4. Start the server: `jac serve src/app.jac`
            # NOTE: We don't use text mode here, so `Popen` defaults to bytes.
            # Use `Popen[bytes]` in the type annotation to keep mypy happy.
            server: Popen[bytes] | None = None
            try:
                print("[DEBUG] Starting server with 'jac serve src/app.jac'")
                server = Popen(
                    ["jac", "serve", "src/app.jac"],
                    cwd=project_path,
                )

                # Wait for localhost:8000 to become available
                print("[DEBUG] Waiting for server to be available on 127.0.0.1:8000")
                _wait_for_port("127.0.0.1", 8000, timeout=90.0)
                print("[DEBUG] Server is now accepting connections on 127.0.0.1:8000")

                # "/" – server up
                try:
                    print("[DEBUG] Sending GET request to root endpoint /")
                    with urlopen(
                        "http://127.0.0.1:8000",
                        timeout=10,
                    ) as resp_root:
                        root_body = resp_root.read().decode("utf-8", errors="ignore")
                        print(
                            "[DEBUG] Received response from root endpoint /\n"
                            f"Status: {resp_root.status}\n"
                            f"Body (truncated to 500 chars):\n{root_body[:500]}"
                        )
                        assert resp_root.status == 200
                        assert '"Jac API Server"' in root_body
                        assert '"endpoints"' in root_body
                except (URLError, HTTPError) as exc:
                    print(f"[DEBUG] Error while requesting root endpoint: {exc}")
                    pytest.fail(f"Failed to GET root endpoint: {exc}")

                # "/page/app" – main page is loading
                # Note: This endpoint may return 503 while the page is being compiled,
                # so we use _wait_for_endpoint to retry until it's ready.
                try:
                    print(
                        "[DEBUG] Sending GET request to /page/app endpoint (with retry)"
                    )
                    page_bytes = _wait_for_endpoint(
                        "http://127.0.0.1:8000/page/app",
                        timeout=120.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    )
                    page_body = page_bytes.decode("utf-8", errors="ignore")
                    print(
                        "[DEBUG] Received response from /page/app endpoint\n"
                        f"Body (truncated to 500 chars):\n{page_body[:500]}"
                    )
                    assert "<html" in page_body.lower()
                except (URLError, HTTPError, TimeoutError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /page/app endpoint: {exc}")
                    pytest.fail(f"Failed to GET /page/app endpoint: {exc}")

                # "/page/app#/nested" – relative paths / nested route
                # (hash fragment is client-side only but server should still serve the app shell)
                try:
                    print("[DEBUG] Sending GET request to /page/app#/nested endpoint")
                    with urlopen(
                        "http://127.0.0.1:8000/page/app#/nested",
                        timeout=200,
                    ) as resp_nested:
                        nested_body = resp_nested.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /page/app#/nested endpoint\n"
                            f"Status: {resp_nested.status}\n"
                            f"Body (truncated to 500 chars):\n{nested_body[:500]}"
                        )
                        assert resp_nested.status == 200
                        assert "<html" in nested_body.lower()
                except (URLError, HTTPError) as exc:
                    print(
                        f"[DEBUG] Error while requesting /page/app#/nested endpoint: {exc}"
                    )
                    pytest.fail("Failed to GET /page/app#/nested endpoint")

                # "/static/main.css" – CSS compiled and serving
                # Note: CSS may be compiled asynchronously, so we retry if it's not ready
                try:
                    print(
                        "[DEBUG] Sending GET request to /static/main.css (with retry)"
                    )
                    css_bytes = _wait_for_endpoint(
                        "http://127.0.0.1:8000/static/main.css",
                        timeout=60.0,
                        poll_interval=2.0,
                        request_timeout=20.0,
                    )
                    css_body = css_bytes.decode("utf-8", errors="ignore")
                    print(
                        "[DEBUG] Received response from /static/main.css\n"
                        f"Body (truncated to 500 chars):\n{css_body[:500]}"
                    )
                    assert len(css_body.strip()) > 0, "CSS file should not be empty"
                except (URLError, HTTPError, TimeoutError, RemoteDisconnected) as exc:
                    print(f"[DEBUG] Error while requesting /static/main.css: {exc}")
                    pytest.fail(f"Failed to GET /static/main.css after retries: {exc}")

                # "/static/assets/burger.png" – static files are loading
                try:
                    print("[DEBUG] Sending GET request to /static/assets/burger.png")
                    with urlopen(
                        "http://127.0.0.1:8000/static/assets/burger.png",
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

                # "/walker/get_server_message" – walkers are integrated and up and running
                try:
                    print("[DEBUG] Sending GET request to /walker/get_server_message")
                    with urlopen(
                        "http://127.0.0.1:8000/walker/get_server_message",
                        timeout=20,
                    ) as resp_walker:
                        walker_body = resp_walker.read().decode(
                            "utf-8", errors="ignore"
                        )
                        print(
                            "[DEBUG] Received response from /walker/get_server_message\n"
                            f"Status: {resp_walker.status}\n"
                            f"Body (truncated to 500 chars):\n{walker_body[:500]}"
                        )
                        assert resp_walker.status == 200
                        assert "get_server_message" in walker_body
                except (URLError, HTTPError) as exc:
                    print(
                        f"[DEBUG] Error while requesting /walker/get_server_message: {exc}"
                    )
                    pytest.fail("Failed to GET /walker/get_server_message")

                # POST /walker/create_todo – create a Todo via walker HTTP API
                try:
                    print(
                        "[DEBUG] Sending POST request to /walker/create_todo endpoint"
                    )
                    payload = {
                        "text": "Sample todo from all-in-one app",
                    }
                    req = Request(
                        "http://127.0.0.1:8000/walker/create_todo",
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
                except (URLError, HTTPError) as exc:
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
                        "http://127.0.0.1:8000/user/register",
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
                        register_data = json.loads(register_body)
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
                except (URLError, HTTPError) as exc:
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
                        "http://127.0.0.1:8000/user/login",
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
                        login_data = json.loads(login_body)
                        assert "token" in login_data
                        assert len(login_data["token"]) > 0
                        print(
                            f"[DEBUG] Successfully logged in user: {test_username}\n"
                            f"Token: {login_data['token'][:20]}..."
                        )
                except (URLError, HTTPError) as exc:
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
                        "http://127.0.0.1:8000/user/login",
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
                except URLError as exc:
                    print(
                        f"[DEBUG] Unexpected error while testing invalid login: {exc}"
                    )
                    pytest.fail("Unexpected error testing invalid login")

                # Verify TypeScript component is working - check that page loads with TS component
                # The /page/app endpoint should serve the app which includes the TypeScript Card component
                try:
                    print("[DEBUG] Verifying TypeScript component integration")
                    # The page should load successfully (already tested above)
                    # TypeScript components are compiled and included in the bundle
                    # We verify this by checking the page loads without errors
                    assert "<html" in page_body.lower(), "Page should contain HTML"
                except Exception as exc:
                    print(f"[DEBUG] Error verifying TypeScript component: {exc}")
                    pytest.fail("Failed to verify TypeScript component integration")

                # Verify nested folder imports are working - /page/app#/nested route
                # This route uses nested folder imports (components.button and button)
                try:
                    print(
                        "[DEBUG] Verifying nested folder imports via /page/app#/nested"
                    )
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
