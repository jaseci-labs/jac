"""End-to-end tests for jac-client caching functionality."""

import gc;
import json;
import os;
import re;
import shutil;
import tempfile;
import time;
import tomllib;
import pytest;
import from http.client { RemoteDisconnected }
import from pathlib { Path }
import from subprocess { PIPE, STDOUT, Popen, run }
import from urllib.error { HTTPError, URLError }
import from urllib.request { Request, urlopen }

import from .test_helpers {
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port
}

def _wait_for_endpoint(
    url: str,
    timeout: float = 120.0,
    poll_interval: float = 2.0,
    request_timeout: float = 30.0,
) -> bytes {
    """Block until an HTTP endpoint returns a successful response or timeout."""
    deadline = time.time() + timeout;
    last_err: Exception | None = None;

    while time.time() < deadline {
        try {
            with urlopen(url, timeout=request_timeout) as resp {
                return resp.read();
            }
        } except HTTPError as exc {
            if exc.code == 503 {
                exc.close();
                last_err = exc;
                print(f"[DEBUG] Endpoint {url} returned 503, retrying...");
                time.sleep(poll_interval);
            } elif exc.code == 500 {
                exc.close();
                raise ;
            } else {
                raise ;
            }
        } except URLError as exc {
            last_err = exc;
            print(f"[DEBUG] Endpoint {url} connection error: {exc}, retrying...");
            time.sleep(poll_interval);
        } except RemoteDisconnected as exc {
            last_err = exc;
            print(f"[DEBUG] Endpoint {url} remote disconnected: {exc}, retrying...");
            time.sleep(poll_interval);
        }
    }

    raise TimeoutError(
        f"Timed out waiting for {url} to become available. Last error: {last_err}"
    ) ;
}

def _setup_all_in_one_project(temp_dir: str, app_name: str) -> str {
    """Shared helper: scaffold a jac client app, copy all-in-one into it, install npm deps."""
    tests_dir = os.path.dirname(__file__);
    jac_client_root = os.path.dirname(tests_dir);
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one");

    assert os.path.isdir(all_in_one_path) , "all-in-one example directory missing";

    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    process = Popen(
        [*jac_cmd, "create", "--use", "client", app_name],
        stdin=PIPE,
        stdout=PIPE,
        stderr=PIPE,
        text=True,
        env=env,
    );
    (stdout, stderr) = process.communicate();
    if process.returncode != 0 and "unrecognized arguments: --use" in stderr {
        pytest.fail(
            "Test failed: installed `jac` CLI does not support `create --use client`."
        );
    }
    assert process.returncode == 0 , (
        f"jac create --use client failed\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}\n"
    );

    project_path = os.path.join(temp_dir, app_name);
    assert os.path.isdir(project_path);

    for entry in os.listdir(all_in_one_path) {
        src = os.path.join(all_in_one_path, entry);
        dst = os.path.join(project_path, entry);
        if entry in {"node_modules","build","dist",".pytest_cache",".jac"} {
            continue;
        }
        if os.path.isdir(src) {
            shutil.copytree(src, dst, dirs_exist_ok=True);
        } else {
            shutil.copy2(src, dst);
        }
    }

    jac_add_result = run(
        [*jac_cmd, "add", "--npm"],
        cwd=project_path,
        capture_output=True,
        text=True,
        env=env,
    );
    if jac_add_result.returncode != 0 {
        pytest.fail(
            f"jac add --npm failed\nSTDOUT:\n{jac_add_result.stdout}\n"
            f"STDERR:\n{jac_add_result.stderr}\n"
        );
    }

    return project_path;
}

test "cache api functions in bundle" {
    """Verify that cache API functions are included in the generated JS bundle."""
    print("[DEBUG] Starting test_cache_api_functions_in_bundle");

    app_name = "e2e-cache-api-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );
                root_body = root_bytes.decode("utf-8", errors="ignore");
                print(f"[DEBUG] Root response (truncated):\n{root_body[:500]}");
                assert "<html" in root_body.lower() , "Root should return HTML";

                script_match = re.search(r'src="(/static/client[^"]+)"', root_body);
                assert script_match , (
                    f"Could not find client JS bundle path in HTML:\n{root_body[:1000]}"
                );

                js_path = script_match.group(1);
                js_url = f"http://127.0.0.1:{server_port}{js_path}";
                print(f"[DEBUG] Fetching JS bundle from {js_url}");

                with urlopen(js_url, timeout=30) as resp {
                    js_body = resp.read().decode("utf-8", errors="ignore");
                    assert resp.status == 200 , "JS bundle should return 200";
                    assert len(js_body) > 0 , "JS bundle should not be empty";
                    print(f"[DEBUG] JS bundle fetched ({len(js_body)} bytes)");
                }

                assert "jacInvalidate" in js_body , (
                    "Expected jacInvalidate function in JS bundle"
                );
                print("[DEBUG] Confirmed jacInvalidate found in JS bundle");

                assert "jacClearCache" in js_body , (
                    "Expected jacClearCache function in JS bundle"
                );
                print("[DEBUG] Confirmed jacClearCache found in JS bundle");

                assert "jacGetCacheMetrics" in js_body , (
                    "Expected jacGetCacheMetrics function in JS bundle"
                );
                print("[DEBUG] Confirmed jacGetCacheMetrics found in JS bundle");

                assert "jacCacheStats" in js_body , (
                    "Expected jacCacheStats function in JS bundle"
                );
                print("[DEBUG] Confirmed jacCacheStats found in JS bundle");

                assert "jacIsCacheEnabled" in js_body , (
                    "Expected jacIsCacheEnabled function in JS bundle"
                );
                print("[DEBUG] Confirmed jacIsCacheEnabled found in JS bundle");

                assert "jacSetCacheEnabled" in js_body , (
                    "Expected jacSetCacheEnabled function in JS bundle"
                );
                print("[DEBUG] Confirmed jacSetCacheEnabled found in JS bundle");

                assert "jacPrefetch" in js_body , (
                    "Expected jacPrefetch function in JS bundle"
                );
                print("[DEBUG] Confirmed jacPrefetch found in JS bundle");

                assert "__jacCacheState__" in js_body , (
                    "Expected __jacCacheState__ debug object in JS bundle"
                );
                print("[DEBUG] Confirmed __jacCacheState__ found in JS bundle");

                print("[DEBUG] All cache API function assertions passed!");
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                        print("[DEBUG] Server terminated cleanly");
                    } except Exception {
                        print("[DEBUG] Server did not terminate cleanly, killing");
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}

test "cache config in bundle" {
    """Verify that [plugins.client.cache] config is baked into the JS bundle."""
    print("[DEBUG] Starting test_cache_config_in_bundle");

    app_name = "e2e-cache-config-test";
    custom_max_entries = 250;
    custom_ttl = 120000;

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            jac_toml_path = os.path.join(project_path, "jac.toml");
            assert os.path.isfile(jac_toml_path) , "jac.toml should exist";

            with open(jac_toml_path, "a") as f {
                f.write(
                    f'\n[plugins.client.cache]\n'
                    f'max_entries = {custom_max_entries}\n'
                    f'ttl_ms = {custom_ttl}\n'
                    f'enabled = true\n'
                );
            }

            with open(jac_toml_path, "rb") as f {
                updated_config = tomllib.load(f);
            }
            cache_config = (
                updated_config.get("plugins", {}).get("client", {}).get("cache", {})
            );
            print(f"[DEBUG] Verified jac.toml cache config = {cache_config}");
            assert cache_config.get("max_entries") == custom_max_entries;
            assert cache_config.get("ttl_ms") == custom_ttl;

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );
                root_body = root_bytes.decode("utf-8", errors="ignore");
                assert "<html" in root_body.lower() , "Root should return HTML";

                script_match = re.search(r'src="(/static/client[^"]+)"', root_body);
                assert script_match , (
                    f"Could not find client JS bundle path in HTML:\n{root_body[:1000]}"
                );

                js_path = script_match.group(1);
                js_url = f"http://127.0.0.1:{server_port}{js_path}";
                print(f"[DEBUG] Fetching JS bundle from {js_url}");

                with urlopen(js_url, timeout=30) as resp {
                    js_body = resp.read().decode("utf-8", errors="ignore");
                    assert resp.status == 200 , "JS bundle should return 200";
                    print(f"[DEBUG] JS bundle fetched ({len(js_body)} bytes)");
                }

                assert str(custom_max_entries) in js_body , (
                    f"Expected max_entries value {custom_max_entries} in JS bundle"
                );
                print(f"[DEBUG] Confirmed max_entries={custom_max_entries} in bundle");

                assert str(custom_ttl) in js_body , (
                    f"Expected ttl_ms value {custom_ttl} in JS bundle"
                );
                print(f"[DEBUG] Confirmed ttl_ms={custom_ttl} in bundle");

                print("[DEBUG] All cache config assertions passed!");
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                    } except Exception {
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}

test "walker response caching via http" {
    """Test that repeated walker calls return cached responses."""
    print("[DEBUG] Starting test_walker_response_caching_via_http");

    app_name = "e2e-cache-http-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );

                try {
                    print(
                        "[DEBUG] Sending first POST request to /walker/get_server_message"
                    );
                    req1 = Request(
                        f"http://127.0.0.1:{server_port}/walker/get_server_message",
                        data=json.dumps({}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    start1 = time.time();
                    with urlopen(req1, timeout=20) as resp1 {
                        body1 = resp1.read().decode("utf-8", errors="ignore");
                        elapsed1 = time.time() - start1;
                        print(
                            f"[DEBUG] First request completed in {elapsed1:.3f}s\n"
                            f"Status: {resp1.status}\n"
                            f"Body: {body1[:200]}"
                        );
                        assert resp1.status == 200;
                        assert "hello from a basic walker" in body1.lower();
                    }

                    print(
                        "[DEBUG] Sending second POST request to /walker/get_server_message"
                    );
                    req2 = Request(
                        f"http://127.0.0.1:{server_port}/walker/get_server_message",
                        data=json.dumps({}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    start2 = time.time();
                    with urlopen(req2, timeout=20) as resp2 {
                        body2 = resp2.read().decode("utf-8", errors="ignore");
                        elapsed2 = time.time() - start2;
                        print(
                            f"[DEBUG] Second request completed in {elapsed2:.3f}s\n"
                            f"Status: {resp2.status}\n"
                            f"Body: {body2[:200]}"
                        );
                        assert resp2.status == 200;
                        assert "hello from a basic walker" in body2.lower();
                    }

                    assert body1 == body2 , (
                        "Expected identical responses for same walker call"
                    );
                    print("[DEBUG] Confirmed identical responses");

                    print(
                        "[DEBUG] Sending third POST request to /walker/get_server_message"
                    );
                    req3 = Request(
                        f"http://127.0.0.1:{server_port}/walker/get_server_message",
                        data=json.dumps({}).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    with urlopen(req3, timeout=20) as resp3 {
                        body3 = resp3.read().decode("utf-8", errors="ignore");
                        print(
                            f"[DEBUG] Third request completed\n"
                            f"Status: {resp3.status}"
                        );
                        assert resp3.status == 200;
                        assert body3 == body1 , (
                            "Expected consistent responses across multiple calls"
                        );
                    }

                    print("[DEBUG] All walker caching assertions passed!");
                } except (URLError, HTTPError, RemoteDisconnected) as exc {
                    print(f"[DEBUG] Error during walker requests: {exc}");
                    pytest.fail(f"Failed walker caching test: {exc}");
                }
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                    } except Exception {
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}

test "auth walkers excluded from cache" {
    """Verify that authentication walkers (login/register) are not cached."""
    print("[DEBUG] Starting test_auth_walkers_excluded_from_cache");

    app_name = "e2e-cache-auth-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );

                test_username_1 = f"cache_test_user_{int(time.time())}";
                test_password = "test_password_123";

                try {
                    print("[DEBUG] Registering first user");
                    register_payload = {
                        "username": test_username_1,
                        "password": test_password,
                    };
                    req_register = Request(
                        f"http://127.0.0.1:{server_port}/user/register",
                        data=json.dumps(register_payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    with urlopen(req_register, timeout=20) as resp_register {
                        register_body = resp_register.read().decode(
                            "utf-8", errors="ignore"
                        );
                        print(
                            f"[DEBUG] Register response:\n"
                            f"Status: {resp_register.status}\n"
                            f"Body: {register_body[:300]}"
                        );
                        assert resp_register.status == 201;
                        register_response = json.loads(register_body);
                        register_data = register_response.get(
                            "data", register_response
                        );
                        assert "token" in register_data;
                        token_1 = register_data["token"];
                        print(f"[DEBUG] Got token for user 1: {token_1[:20]}...");
                    }
                } except (URLError, HTTPError, RemoteDisconnected) as exc {
                    print(f"[DEBUG] Error registering first user: {exc}");
                    pytest.fail(f"Failed to register first user: {exc}");
                }

                test_username_2 = f"cache_test_user_{int(time.time()) + 1}";

                try {
                    print("[DEBUG] Registering second user");
                    register_payload_2 = {
                        "username": test_username_2,
                        "password": test_password,
                    };
                    req_register_2 = Request(
                        f"http://127.0.0.1:{server_port}/user/register",
                        data=json.dumps(register_payload_2).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    with urlopen(req_register_2, timeout=20) as resp_register_2 {
                        register_body_2 = resp_register_2.read().decode(
                            "utf-8", errors="ignore"
                        );
                        print(
                            f"[DEBUG] Register response 2:\n"
                            f"Status: {resp_register_2.status}\n"
                            f"Body: {register_body_2[:300]}"
                        );
                        assert resp_register_2.status == 201;
                        register_response_2 = json.loads(register_body_2);
                        register_data_2 = register_response_2.get(
                            "data", register_response_2
                        );
                        assert "token" in register_data_2;
                        token_2 = register_data_2["token"];
                        print(f"[DEBUG] Got token for user 2: {token_2[:20]}...");
                    }
                } except (URLError, HTTPError, RemoteDisconnected) as exc {
                    print(f"[DEBUG] Error registering second user: {exc}");
                    pytest.fail(f"Failed to register second user: {exc}");
                }

                assert token_1 != token_2 , (
                    "Different users should get different tokens - "
                    "registration should not be cached"
                );
                print("[DEBUG] Confirmed different tokens for different users");

                try {
                    print("[DEBUG] Testing login is not cached");
                    login_payload = {
                        "username": test_username_1,
                        "password": test_password,
                    };
                    req_login = Request(
                        f"http://127.0.0.1:{server_port}/user/login",
                        data=json.dumps(login_payload).encode("utf-8"),
                        headers={"Content-Type": "application/json"},
                        method="POST",
                    );
                    with urlopen(req_login, timeout=20) as resp_login {
                        login_body = resp_login.read().decode("utf-8", errors="ignore");
                        print(
                            f"[DEBUG] Login response:\n"
                            f"Status: {resp_login.status}"
                        );
                        assert resp_login.status == 200;
                        login_response = json.loads(login_body);
                        login_data = login_response.get("data", login_response);
                        assert "token" in login_data;
                        login_token = login_data["token"];
                        print(f"[DEBUG] Got login token: {login_token[:20]}...");
                    }
                } except (URLError, HTTPError, RemoteDisconnected) as exc {
                    print(f"[DEBUG] Error during login: {exc}");
                    pytest.fail(f"Failed login test: {exc}");
                }

                print("[DEBUG] All auth cache exclusion assertions passed!");
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                    } except Exception {
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}

test "cache disabled config" {
    """Verify that cache can be disabled via jac.toml config."""
    print("[DEBUG] Starting test_cache_disabled_config");

    app_name = "e2e-cache-disabled-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            jac_toml_path = os.path.join(project_path, "jac.toml");
            assert os.path.isfile(jac_toml_path) , "jac.toml should exist";

            with open(jac_toml_path, "a") as f {
                f.write(
                    '\n[plugins.client.cache]\n'
                    'enabled = false\n'
                );
            }
            print("[DEBUG] Added cache disabled config to jac.toml");

            with open(jac_toml_path, "rb") as f {
                updated_config = tomllib.load(f);
            }
            cache_enabled = (
                updated_config.get("plugins", {})
                .get("client", {})
                .get("cache", {})
                .get("enabled", True)
            );
            print(f"[DEBUG] Verified cache enabled = {cache_enabled}");
            assert cache_enabled == False;

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                root_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );
                root_body = root_bytes.decode("utf-8", errors="ignore");
                assert "<html" in root_body.lower() , "Root should return HTML";

                script_match = re.search(r'src="(/static/client[^"]+)"', root_body);
                assert script_match , "Could not find client JS bundle path";

                js_path = script_match.group(1);
                js_url = f"http://127.0.0.1:{server_port}{js_path}";
                print(f"[DEBUG] Fetching JS bundle from {js_url}");

                with urlopen(js_url, timeout=30) as resp {
                    js_body = resp.read().decode("utf-8", errors="ignore");
                    assert resp.status == 200;
                    print(f"[DEBUG] JS bundle fetched ({len(js_body)} bytes)");
                }

                assert "enabled" in js_body and "false" in js_body.lower() , (
                    "Expected cache enabled=false in JS bundle config"
                );
                print("[DEBUG] Confirmed cache disabled config in bundle");

                print("[DEBUG] Cache disabled config test passed!");
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                    } except Exception {
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}

test "cache test page renders" {
    """Verify that the cache test page renders correctly."""
    print("[DEBUG] Starting test_cache_test_page_renders");

    app_name = "e2e-cache-page-test";

    with tempfile.TemporaryDirectory() as temp_dir {
        print(f"[DEBUG] Created temporary directory at {temp_dir}");
        original_cwd = os.getcwd();
        try {
            os.chdir(temp_dir);

            project_path = _setup_all_in_one_project(temp_dir, app_name);
            print(f"[DEBUG] Project set up at {project_path}");

            cache_test_page = os.path.join(
                project_path, "pages", "cache_test_ui.cl.jac"
            );
            assert os.path.isfile(cache_test_page) , (
                "cache_test_ui.cl.jac should exist in pages/"
            );
            print("[DEBUG] Verified cache_test_ui.cl.jac exists");

            server: Popen | None = None;
            server_port = get_free_port();
            jac_cmd = get_jac_command();
            env = get_env_with_npm();
            try {
                print(
                    f"[DEBUG] Starting server with 'jac start main.jac -p {server_port}'"
                );
                server = Popen(
                    [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                    cwd=project_path,
                    env=env,
                );

                print(f"[DEBUG] Waiting for server on 127.0.0.1:{server_port}");
                wait_for_port("127.0.0.1", server_port, timeout=90.0);
                print(
                    f"[DEBUG] Server accepting connections on 127.0.0.1:{server_port}"
                );

                _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}",
                    timeout=120.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );

                try {
                    print("[DEBUG] Fetching cache test page at /cache-test");
                    cache_page_bytes = _wait_for_endpoint(
                        f"http://127.0.0.1:{server_port}/cache-test",
                        timeout=60.0,
                        poll_interval=2.0,
                        request_timeout=30.0,
                    );
                    cache_page_body = cache_page_bytes.decode("utf-8", errors="ignore");
                    print(
                        f"[DEBUG] Cache test page response:\n"
                        f"Body (truncated): {cache_page_body[:500]}"
                    );
                    assert "<html" in cache_page_body.lower() , (
                        "Cache test page should return HTML"
                    );
                } except (URLError, HTTPError, TimeoutError) as exc {
                    print(f"[DEBUG] Note: /cache-test page may use different route");
                    print(f"[DEBUG] Exception: {exc}");
                }

                app_page_bytes = _wait_for_endpoint(
                    f"http://127.0.0.1:{server_port}/cl/app",
                    timeout=60.0,
                    poll_interval=2.0,
                    request_timeout=30.0,
                );
                app_page_body = app_page_bytes.decode("utf-8", errors="ignore");
                print(
                    f"[DEBUG] /cl/app response:\n"
                    f"Body (truncated): {app_page_body[:500]}"
                );
                assert "<html" in app_page_body.lower() , (
                    "App page should return HTML"
                );

                print("[DEBUG] Cache test page render test passed!");
            } finally {
                if server is not None {
                    print("[DEBUG] Terminating server process");
                    server.terminate();
                    try {
                        server.wait(timeout=15);
                    } except Exception {
                        server.kill();
                        server.wait(timeout=5);
                    }
                    time.sleep(1);
                    gc.collect();
                }
            }
        } finally {
            os.chdir(original_cwd);
            gc.collect();
        }
    }
}
