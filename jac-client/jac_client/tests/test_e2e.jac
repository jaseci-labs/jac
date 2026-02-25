"""Browser-level E2E tests for jac-client authentication flows."""

import gc;
import os;
import tempfile;
import time;
import pytest;
import from subprocess { Popen, run }

import from playwright.sync_api { Browser, Page, sync_playwright }

import from .test_helpers {
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port
}

# ---- Helper functions (replacing fixtures) ----
def _fill_auth_form(
    page: Page, username: str, password: str
) -> None {
    """Fill username and password fields."""
    page.locator('input[type="text"], input[placeholder="Username" i]').first.fill(
        username
    );
    page.locator('input[type="password"]').first.fill(password);
}

def _submit_form(page: Page) -> None {
    """Click submit button and wait for navigation."""
    page.locator('button[type="submit"]').first.click();
    page.wait_for_timeout(2000);
}

def _signup(page: Page, base_url: str, username: str, password: str) -> None {
    """Navigate to signup, fill form, and submit."""
    page.goto(f"{base_url}/signup", wait_until="networkidle", timeout=60000);
    page.wait_for_selector('input[type="text"]', timeout=30000);
    _fill_auth_form(page, username, password);
    _submit_form(page);
}

def _login(page: Page, base_url: str, username: str, password: str) -> None {
    """Navigate to login, fill form, and submit."""
    page.goto(f"{base_url}/login", wait_until="networkidle", timeout=30000);
    page.wait_for_selector('input[type="text"]', timeout=30000);
    _fill_auth_form(page, username, password);
    _submit_form(page);
}

def _logout(page: Page) -> None {
    """Click logout button if visible."""
    logout_btn = page.locator('button:has-text("Logout")').first;
    if logout_btn.is_visible() {
        logout_btn.click();
        page.wait_for_timeout(1000);
    }
}

def _start_running_server -> tuple {
    """Start the all-in-one jac server and return (process, port, url, temp_dir, original_cwd)."""
    tests_dir = os.path.dirname(__file__);
    jac_client_root = os.path.dirname(tests_dir);
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one");

    if not os.path.isdir(all_in_one_path) {
        pytest.skip("all-in-one example directory not found");
    }

    app_name = "e2e-browser-test-app";
    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    temp_dir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(temp_dir);

    # Create jacpack file from all-in-one example
    jacpack_path = os.path.join(temp_dir, "all-in-one.jacpack");
    pack_result = run(
        [*jac_cmd, "jacpack", "pack", all_in_one_path, "-o", jacpack_path],
        capture_output=True,
        text=True,
        env=env,
    );
    if pack_result.returncode != 0 {
        pytest.fail(f"jac jacpack pack failed: {pack_result.stderr}");
    }

    # Create project from jacpack file
    create_result = run(
        [*jac_cmd, "create", app_name, "--use", jacpack_path],
        capture_output=True,
        text=True,
        env=env,
    );
    if create_result.returncode != 0 {
        pytest.fail(f"jac create --use jacpack failed: {create_result.stderr}");
    }

    project_path = os.path.join(temp_dir, app_name);

    server_port = get_free_port();
    server = Popen(
        [*jac_cmd, "start", "-p", str(server_port)], cwd=project_path, env=env,
    );

    wait_for_port("127.0.0.1", server_port, timeout=90.0);
    time.sleep(5);
    return (
        server,
        server_port,
        f"http://127.0.0.1:{server_port}",
        temp_dir,
        original_cwd
    );
}

def _stop_running_server(server: Popen, temp_dir: str, original_cwd: str) -> None {
    """Stop the running server and clean up."""
    server.terminate();
    try {
        server.wait(timeout=15);
    } except Exception {
        server.kill();
        server.wait(timeout=5);
    }
    time.sleep(1);
    gc.collect();
    os.chdir(original_cwd);
    gc.collect();
}

test "navigate without auth redirects to login" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                page.goto(f"{url}/nested", wait_until="networkidle", timeout=60000);
                page.wait_for_timeout(2000);
                assert "/login" in page.url.lower();
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "signup form submission" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                _signup(page, url, f"e2e_signup_{int(time.time())}", "test_pass_123",);
                assert "/signup" not in page.url.lower();
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "login with valid credentials" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                username = f"e2e_login_{int(time.time())}";
                password = "valid_pass_123";
                _signup(page, url, username, password);
                _logout(page);
                _login(page, url, username, password);
                assert "/login" not in page.url.lower()
                and "/signup" not in page.url.lower();
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "login with invalid credentials" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                _login(page, url, "nonexistent_999", "wrong_pass");
                assert "/login" in page.url.lower();
                assert page.locator("text=/Invalid credentials/i").first.is_visible();
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "logout functionality" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                _signup(page, url, f"e2e_logout_{int(time.time())}", "logout_pass_123");
                logout_btn = page.locator('button:has-text("Logout")').first;
                logout_btn.click();
                page.wait_for_timeout(1500);
                assert "/login" in page.url.lower()
                and not logout_btn.is_visible(timeout=5000);
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "complete auth flow" {
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                username = f"e2e_complete_{int(time.time())}";
                password = "complete_pass_123";

                _signup(page, url, username, password);
                assert "/signup" not in page.url.lower();

                _logout(page);
                _login(page, url, username, password);
                assert "/login" not in page.url.lower();

                page.goto(f"{url}/nested", wait_until="networkidle", timeout=30000);
                assert "/nested" in page.url.lower();
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "auto cache prevents duplicate reader requests and invalidates on write" {
    """Verifies the full auto-caching pipeline end-to-end in a real browser.

    The compiler classifies walkers as readers or writers, injects endpoint
    metadata into the served HTML, and the client JS runtime uses it to:
    1. Cache reader responses (skip network on repeat calls)
    2. Auto-invalidate reader caches after a writer executes

    This test observes actual HTTP traffic via Playwright to confirm the
    cache prevents redundant server calls and correctly invalidates.
    """;
    (server, port, url, temp_dir, original_cwd) = _start_running_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            context = browser.new_context();
            page = context.new_page();
            try {
                # Sign up to get authenticated and land on the home page
                _signup(page, url, f"cache_e2e_{int(time.time())}", "cache_pass_123");
                page.wait_for_load_state("networkidle");
                page.wait_for_timeout(3000);

                # ---- Track walker HTTP requests ----
                walker_requests: list = [];

                def _track_request(request: any) -> None {
                    if "/walker/" in request.url {
                        walker_requests.append(request.url);
                    }
                }

                page.on("request", _track_request);

                # ---- Debug: Check __jac_init__ and endpointEffects ----
                init_data = page.evaluate(
                    """() => {
                    const el = document.getElementById('__jac_init__');
                    if (!el) return {error: 'no __jac_init__ element'};
                    try {
                        const data = JSON.parse(el.textContent);
                        return {keys: Object.keys(data), effects: data.endpointEffects || null};
                    } catch(e) { return {error: e.message}; }
                }"""
                );
                print(f"[CACHE DEBUG] __jac_init__ data: {init_data}");

                effects_in_browser = page.evaluate(
                    """() => {
                    return globalThis.__jacEndpointEffects__ || 'not set';
                }"""
                );
                print(
                    f"[CACHE DEBUG] globalThis.__jacEndpointEffects__: {effects_in_browser}"
                );

                # ---- Step 1: First click on "Ping Backend" (cache MISS) ----
                ping_btn = page.locator('button:has-text("Ping Backend")').first;
                ping_btn.click();
                page.wait_for_timeout(2000);

                ping_hits_after_first = len(
                    [
                        r
                        for r in walker_requests
                        if "ping_server" in r
                    ]
                );
                assert ping_hits_after_first == 1 , (
                    f"First ping should produce exactly 1 HTTP request, "
                    f"got {ping_hits_after_first}"
                );

                # ---- Step 2: Second click on "Ping Backend" (cache HIT) ----
                ping_btn.click();
                page.wait_for_timeout(2000);

                ping_hits_after_second = len(
                    [
                        r
                        for r in walker_requests
                        if "ping_server" in r
                    ]
                );
                assert ping_hits_after_second == 1 , (
                    "Second ping should be served from cache (no new HTTP "
                    f"request), but total ping requests grew to "
                    f"{ping_hits_after_second}"
                );

                # ---- Step 3: Click "Create Sample Todo" (WRITER) ----
                # create_todo is classified as a writer because it uses ++>.
                # It should auto-invalidate reader caches that share node
                # types (both ping_server and create_todo touch Root).
                todo_btn = page.locator('button:has-text("Create Sample Todo")').first;
                todo_btn.click();
                page.wait_for_timeout(2000);

                # ---- Step 4: Third click on "Ping Backend" (cache was INVALIDATED) ----
                ping_btn.click();
                page.wait_for_timeout(2000);

                ping_hits_after_invalidation = len(
                    [
                        r
                        for r in walker_requests
                        if "ping_server" in r
                    ]
                );
                assert ping_hits_after_invalidation == 2 , (
                    "After writer invalidation, ping should make a new HTTP "
                    f"request (expected 2 total), got "
                    f"{ping_hits_after_invalidation}"
                );
            } finally {
                context.close();
                browser.close();
            }
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}
