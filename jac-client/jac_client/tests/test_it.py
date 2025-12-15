"""End-to-end tests for `jac serve` HTTP endpoints."""

from __future__ import annotations

import json
import os
import shutil
import socket
import tempfile
import time
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


def test_all_in_one_app_endpoints() -> None:
    """Create a Jac app, copy @all-in-one into it, run npm install, then verify endpoints."""
    print(
        "[DEBUG] Starting test_all_in_one_app_endpoints using jac create_jac_app + @all-in-one"
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
            # Note: We provide "n\n" for TypeScript support since all-in-one already has TS configured
            print(f"[DEBUG] Running 'jac create_jac_app {app_name}'")
            process = Popen(
                ["jac", "create_jac_app", app_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
            )
            stdout, stderr = process.communicate(input="n\n")
            returncode = process.returncode

            print(
                "[DEBUG] 'jac create_jac_app' completed "
                f"returncode={returncode}\n"
                f"STDOUT:\n{stdout}\n"
                f"STDERR:\n{stderr}\n"
            )

            # If the currently installed `jac` CLI does not support `create_jac_app`,
            # skip this integration test instead of failing the whole suite.
            if returncode != 0 and "invalid choice: 'create_jac_app'" in stderr:
                pytest.skip(
                    "Skipping: installed `jac` CLI does not support `create_jac_app`."
                )

            assert returncode == 0, (
                f"jac create_jac_app failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
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

            # 3. Run `npm install` inside the project directory so the frontend can build.
            print("[DEBUG] Running 'npm install' in created Jac app")
            npm_result = run(
                ["npm", "install"],
                cwd=project_path,
                capture_output=True,
                text=True,
            )
            print(
                "[DEBUG] 'npm install' completed "
                f"returncode={npm_result.returncode}\n"
                f"STDOUT (truncated to 2000 chars):\n{npm_result.stdout[:2000]}\n"
                f"STDERR (truncated to 2000 chars):\n{npm_result.stderr[:2000]}\n"
            )

            if npm_result.returncode != 0:
                pytest.skip(
                    "Skipping: npm install failed or npm is not available in PATH."
                )

            app_jac_path = os.path.join(project_path, "app.jac")
            assert os.path.isfile(app_jac_path), "all-in-one app.jac file missing"

            # 4. Start the server: `jac serve app.jac`
            # NOTE: We don't use text mode here, so `Popen` defaults to bytes.
            # Use `Popen[bytes]` in the type annotation to keep mypy happy.
            server: Popen[bytes] | None = None
            try:
                print("[DEBUG] Starting server with 'jac serve app.jac'")
                server = Popen(
                    ["jac", "serve", "app.jac"],
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
                try:
                    print("[DEBUG] Sending GET request to /page/app endpoint")
                    with urlopen(
                        "http://127.0.0.1:8000/page/app",
                        timeout=200,
                    ) as resp_page:
                        page_body = resp_page.read().decode("utf-8", errors="ignore")
                        print(
                            "[DEBUG] Received response from /page/app endpoint\n"
                            f"Status: {resp_page.status}\n"
                            f"Body (truncated to 500 chars):\n{page_body[:500]}"
                        )
                        assert resp_page.status == 200
                        assert "<html" in page_body.lower()
                except (URLError, HTTPError) as exc:
                    print(f"[DEBUG] Error while requesting /page/app endpoint: {exc}")
                    pytest.fail("Failed to GET /page/app endpoint")

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
                try:
                    print("[DEBUG] Sending GET request to /static/main.css")
                    with urlopen(
                        "http://127.0.0.1:8000/static/main.css",
                        timeout=20,
                    ) as resp_css:
                        css_body = resp_css.read().decode("utf-8", errors="ignore")
                        print(
                            "[DEBUG] Received response from /static/main.css\n"
                            f"Status: {resp_css.status}\n"
                            f"Body (truncated to 500 chars):\n{css_body[:500]}"
                        )
                        assert resp_css.status == 200
                        assert len(css_body.strip()) > 0
                except (URLError, HTTPError) as exc:
                    print(f"[DEBUG] Error while requesting /static/main.css: {exc}")
                    pytest.fail("Failed to GET /static/main.css")

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
                test_email = "test_user@example.com"
                test_password = "test_password_123"
                try:
                    print("[DEBUG] Sending POST request to /user/register endpoint")
                    register_payload = {
                        "email": test_email,
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
                        assert "email" in register_data
                        assert "token" in register_data
                        assert "root_id" in register_data
                        assert register_data["email"] == test_email
                        assert len(register_data["token"]) > 0
                        assert len(register_data["root_id"]) > 0
                        print(
                            f"[DEBUG] Successfully registered user: {test_email}\n"
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
                        "email": test_email,
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
                            f"[DEBUG] Successfully logged in user: {test_email}\n"
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
                        "email": "nonexistent@example.com",
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
                        assert http_err.code in (400, 401, 403), (
                            f"Expected 400/401/403 for invalid login, got {http_err.code}"
                        )
                except URLError as exc:
                    print(
                        f"[DEBUG] Unexpected error while testing invalid login: {exc}"
                    )
                    pytest.fail("Unexpected error testing invalid login")

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
        finally:
            print(f"[DEBUG] Restoring original working directory to {original_cwd}")
            os.chdir(original_cwd)
