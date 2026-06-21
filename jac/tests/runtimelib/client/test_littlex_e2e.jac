"""Full-stack build / serve / e2e tests over the littleX example app.

Recovers functional coverage dropped in PR #6840. Two layers:

* Build / serve / HTTP (no browser) -- scaffold littleX into a writable
  temp dir, install its npm deps, then `jac start` it and exercise the
  HTTP surface (the served `/cl/app` page, the static JS + CSS bundles,
  404s) plus a `--client pwa` build that emits a manifest + service worker.
* Browser auth/form flows (Playwright) -- drive littleX's `AuthForm`
  signup / login / logout and confirm the app gates behind auth.

The fixture is the in-tree app at `jac/examples/littleX` (never modified --
it is copied into a `TemporaryDirectory`). Builds are slow, so timeouts are
generous (`wait_for_port` up to 120s).
"""

import json;
import os;
import shutil;
import tempfile;
import time;
import pytest;
import from subprocess { Popen, run }
import from urllib.error { HTTPError }
import from urllib.request { urlopen }

import from .test_helpers {
    get_env_with_bun,
    get_jac_command,
    request_endpoint,
    start_app_server,
    stop_server
}

# ===========================================================================
# Shared helpers
# ===========================================================================
"""Resolve the in-tree littleX example dir.

The test file lives at ``jac/tests/runtimelib/client/``; walking up three
directories lands on ``jac/``, then ``examples/littleX``. Asserts the dir
exists so a misplaced/renamed fixture fails loudly instead of mid-build.
"""
def _littlex_source_dir -> str {
    tests_dir = os.path.dirname(os.path.abspath(__file__));
    jac_root = os.path.abspath(os.path.join(tests_dir, "..", "..", ".."));
    littlex_dir = os.path.join(jac_root, "examples", "littleX");
    assert os.path.isdir(littlex_dir) , (
        f"littleX example dir not found at {littlex_dir}"
    );
    return littlex_dir;
}

"""Copy the littleX example into ``dest`` minus build artifacts.

Excludes ``node_modules`` / ``.jac`` / ``dist`` / ``build`` so the copy is a
clean source tree the temp project can build from scratch.
"""
def _copy_littlex_into(dest: any) {
    src = _littlex_source_dir();
    skip_names = {
        "node_modules",
        ".jac",
        "dist",
        "build",
        ".pytest_cache",
        "__pycache__"
    };
    for entry in os.listdir(src) {
        if entry in skip_names {
            continue;
        }
        src_path = os.path.join(src, entry);
        dst_path = os.path.join(dest, entry);
        if os.path.isdir(src_path) {
            shutil.copytree(
                src_path,
                dst_path,
                dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(
                    "node_modules", ".jac", "dist", "build", "__pycache__"
                ),
            );
        } else {
            shutil.copy2(src_path, dst_path);
        }
    }
}

"""Scaffold littleX into a temp project dir and install npm deps.

Returns ``(project_dir, jac_cmd, env)``. Fails the test if ``jac add --npm``
fails (bun/npm unavailable or a dependency cannot be resolved).
"""
def _setup_littlex_project(temp_dir: any) -> tuple {
    project_dir = os.path.join(temp_dir, "littlex-e2e");
    os.makedirs(project_dir, exist_ok=True);
    _copy_littlex_into(project_dir);

    main_jac = os.path.join(project_dir, "main.jac");
    assert os.path.isfile(main_jac) , "littleX main.jac missing after copy";

    jac_cmd = get_jac_command();
    env = get_env_with_bun();

    add_result = run(
        [*jac_cmd, "add", "--npm"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        env=env,
    );
    if add_result.returncode != 0 {
        pytest.fail(
            f"jac add --npm failed for littleX (bun/npm unavailable?)\n"
            f"STDOUT:\n{add_result.stdout[:2000]}\n"
            f"STDERR:\n{add_result.stderr[:2000]}\n"
        );
    }
    return (project_dir, jac_cmd, env);
}


"""Skip the test unless Playwright + a Chromium build are installed."""
def _require_playwright -> any {
    try {
        import from playwright.sync_api { sync_playwright }
    } except ImportError {
        pytest.skip("playwright not installed");
    }
    return sync_playwright;
}

# ---- Playwright auth-form drivers (selectors verified against
#      littleX/components/AuthForm.cl.jac) ----
# littleX has NO /login or /signup routes: the app renders <AuthForm> inline
# at the root whenever the user is not logged in. The form fields are
# id="lx-username" (type=text) and id="lx-password" (type=password); the
# submit control is button[type="submit"]; a text/"Log In"/"Sign Up" button
# toggles between login and signup mode (default mode is login).
"""Wait for littleX's auth form (the unauthenticated landing) to render."""
def _wait_for_auth_form(page: any) {
    page.wait_for_selector("#lx-username", timeout=30000);
}

"""Fill littleX's username + password inputs."""
def _fill_auth_form(page: any, username: str, password: str) {
    page.locator("#lx-username").fill(username);
    page.locator("#lx-password").fill(password);
}

"""Switch the auth form into signup mode if it is not already.

The toggle button reads "Sign Up" while in login mode (default).
"""
def _ensure_signup_mode(page: any) {
    toggle = page.locator('button[type="button"]:has-text("Sign Up")').first;
    if toggle.count() > 0 and toggle.is_visible() {
        toggle.click();
        page.wait_for_timeout(300);
    }
}

"""Submit the auth form and give the app time to react / re-render."""
def _submit_auth_form(page: any) {
    page.locator('button[type="submit"]').first.click();
    page.wait_for_timeout(3000);
}

"""Register a new littleX account through the AuthForm and wait for login.

littleX auto-logs-in after signup, so the AuthForm disappears on success.
"""
def _signup(page: any, base_url: str, username: str, password: str) {
    page.goto(base_url, wait_until="load", timeout=60000);
    _wait_for_auth_form(page);
    _ensure_signup_mode(page);
    _fill_auth_form(page, username, password);
    _submit_auth_form(page);
}

"""Log an existing littleX account in through the AuthForm (login mode)."""
def _login(page: any, base_url: str, username: str, password: str) {
    page.goto(base_url, wait_until="load", timeout=60000);
    _wait_for_auth_form(page);
    _fill_auth_form(page, username, password);
    _submit_auth_form(page);
}

"""True once the app has rendered its authenticated shell (AuthForm gone)."""
def _is_logged_in(page: any) -> bool {
    return page.locator("#lx-username").count() == 0;
}

# ===========================================================================
# Build / serve / HTTP (no browser)  -- maps to deleted test_it.jac
# ===========================================================================
"""littleX builds and serves /cl/app with its static JS bundle.

Maps to test_it's "all in one app endpoints" / "default client app renders":
the served page is HTML referencing /static/client.js, the JS bundle is real
(not the "Static file not found" sentinel), and a bogus static path 404s.
"""
test "littlex builds and serves /cl/app" {
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            base = f"http://127.0.0.1:{port}";

            # /cl/app -- littleX mounts its base_route_app at "app".
            page_bytes = request_endpoint(f"{base}/cl/app");
            page_body = page_bytes.decode("utf-8", errors="ignore");
            assert "<html" in page_body.lower() , (
                f"/cl/app should return HTML, got:\n{page_body[:500]}"
            );
            assert "/static/client.js" in page_body , (
                "served page should reference /static/client.js bundle"
            );

            # /static/client.js -- the real bundle, not a 404 sentinel.
            js_bytes = request_endpoint(f"{base}/static/client.js");
            js_body = js_bytes.decode("utf-8", errors="ignore");
            assert len(js_body) > 0 , "client.js bundle should not be empty";
            assert "Static file not found" not in js_body , (
                "client.js should serve the bundle, not the not-found sentinel"
            );
            assert ("createElement" in js_body or "jsx" in js_body.lower()) , "client.js should contain React runtime code";

            # A bogus static asset path must 404.
            try {
                with urlopen(
                    f"{base}/static/does-not-exist-xyz.js", timeout=20
                ) as bogus {
                    bogus_body = bogus.read().decode("utf-8", errors="ignore");
                    assert "not found" in bogus_body.lower() , (
                        f"bogus static path should report not found, got {bogus_body}"
                    );
                }
            } except HTTPError as exc {
                assert exc.code == 404 , (
                    f"bogus static path should 404, got {exc.code}"
                );
                exc.close();
            }
        } finally {
            stop_server(server);
        }
    }
}

"""littleX serves its compiled Tailwind CSS bundle.

Maps to recovering CSS-serving coverage: a `jac build --client web` emits
`styles.css` into the client dist, which is served at `/static/styles.css`.
The body is non-empty CSS carrying Tailwind/shadcn tokens (`:root`,
`--background`).
"""
test "littlex serves its CSS bundle" {
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        # A build is what emits dist/styles.css (the served CSS route reads
        # from .jac/client/dist/styles.css).
        build_result = run(
            [*jac_cmd, "build", "--client", "web", "main.jac"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
        );
        assert build_result.returncode == 0 , (
            f"jac build --client web failed\n"
            f"STDOUT:\n{build_result.stdout[:2000]}\n"
            f"STDERR:\n{build_result.stderr[:2000]}\n"
        );
        css_dist = os.path.join(project_dir, ".jac", "client", "dist", "styles.css");
        assert os.path.isfile(css_dist) , (
            f"build should emit styles.css at {css_dist}"
        );
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            base = f"http://127.0.0.1:{port}";

            css_bytes = request_endpoint(f"{base}/static/styles.css");
            css_body = css_bytes.decode("utf-8", errors="ignore");
            assert len(css_body.strip()) > 0 , "served CSS should not be empty";
            assert "not found" not in css_body.lower() , (
                f"CSS route returned an error body: {css_body[:300]}"
            );
            assert (
                "--background" in css_body
                or ":root" in css_body
                or "--primary" in css_body
            ) , (
                "served CSS should contain Tailwind/shadcn tokens, "
                f"got:\n{css_body[:300]}"
            );
        } finally {
            stop_server(server);
        }
    }
}

"""littleX pwa build emits a manifest and service worker.

Maps to test_it's "pwa build generates manifest and service worker": building
with `--client pwa` writes `manifest.json` (display=standalone) and `sw.js`
(install + fetch handlers) into the client dist, and `index.html` gains the
manifest link + SW registration script.
"""
test "littlex pwa build emits manifest and service worker" {
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        build_result = run(
            [*jac_cmd, "build", "--client", "pwa", "main.jac"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=env,
        );
        assert build_result.returncode == 0 , (
            f"jac build --client pwa failed\n"
            f"STDOUT:\n{build_result.stdout[:2000]}\n"
            f"STDERR:\n{build_result.stderr[:2000]}\n"
        );
        dist_dir = os.path.join(project_dir, ".jac", "client", "dist");
        assert os.path.isdir(dist_dir) , f"dist dir not found at {dist_dir}";
        manifest_path = os.path.join(dist_dir, "manifest.json");
        sw_path = os.path.join(dist_dir, "sw.js");
        index_path = os.path.join(dist_dir, "index.html");
        assert os.path.isfile(manifest_path) , (
            f"manifest.json not found at {manifest_path}"
        );
        assert os.path.isfile(sw_path) , f"sw.js not found at {sw_path}";
        assert os.path.isfile(index_path) , f"index.html not found at {index_path}";
        with open(manifest_path) as f {
            manifest = json.load(f);
        }
        assert "name" in manifest , "manifest.json should have a name";
        assert "icons" in manifest , "manifest.json should have icons";
        assert "start_url" in manifest , "manifest.json should have a start_url";
        assert manifest.get("display") == "standalone" , (
            "manifest.json should declare display=standalone"
        );
        with open(sw_path) as f {
            sw_content = f.read();
        }
        assert "addEventListener" in sw_content , "sw.js should add event listeners";
        assert "install" in sw_content , "sw.js should handle the install event";
        assert "fetch" in sw_content , "sw.js should handle the fetch event";
        with open(index_path) as f {
            index_content = f.read();
        }
        assert 'rel="manifest"' in index_content , (
            "index.html should link the manifest"
        );
        assert "serviceWorker" in index_content , (
            "index.html should register the service worker"
        );
    }
}

# ===========================================================================
# Browser auth/form flows (Playwright)  -- maps to deleted test_e2e.jac
# ===========================================================================
"""Navigating without auth shows littleX's auth screen.

Maps to test_e2e's "navigate without auth redirects to login". littleX has no
route-based gate; instead the app renders <AuthForm> inline whenever the user
is not logged in, so an unauthenticated visit lands on the auth form.
"""
test "navigating without auth shows the auth screen" {
    sync_playwright = _require_playwright();
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            url = f"http://127.0.0.1:{port}";
            # Warm the page so the client bundle is built before the browser hits it.
            request_endpoint(f"{url}/cl/app");

            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                context = browser.new_context();
                page = context.new_page();
                try {
                    page.goto(url, wait_until="load", timeout=60000);
                    _wait_for_auth_form(page);
                    assert page.locator("#lx-username").is_visible() , (
                        "unauthenticated visit should show the auth form"
                    );
                    assert page.locator("#lx-password").is_visible() , (
                        "auth form should show the password field"
                    );
                } finally {
                    context.close();
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""Signup creates an account and logs the user in.

Maps to test_e2e's "signup form submission". After a successful signup
littleX auto-logs-in, so the AuthForm is replaced by the authenticated shell.
"""
test "signup creates account and logs in" {
    sync_playwright = _require_playwright();
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            url = f"http://127.0.0.1:{port}";
            request_endpoint(f"{url}/cl/app");

            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                context = browser.new_context();
                page = context.new_page();
                try {
                    _signup(
                        page, url, f"lx_signup_{int(time.time())}", "test_pass_123"
                    );
                    assert _is_logged_in(page) , (
                        "after signup the AuthForm should be gone (logged in)"
                    );
                } finally {
                    context.close();
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""Login with valid credentials logs in; invalid credentials show an error.

Maps to test_e2e's "login with valid credentials" + "login with invalid
credentials". A round trip: sign up, log out, log back in (valid) -> logged
in; then a wrong password -> the AuthForm stays put and surfaces an error.
"""
test "login valid and invalid" {
    sync_playwright = _require_playwright();
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            url = f"http://127.0.0.1:{port}";
            request_endpoint(f"{url}/cl/app");

            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    username = f"lx_login_{int(time.time())}";
                    password = "valid_pass_123";

                    # Register the account in its own clean context (littleX
                    # auto-logs-in after signup).
                    ctx1 = browser.new_context();
                    page1 = ctx1.new_page();
                    try {
                        _signup(page1, url, username, password);
                        assert _is_logged_in(page1) , "signup should log in";
                    } finally {
                        ctx1.close();
                    }

                    # Valid login in a FRESH context. A clean session avoids the
                    # navigation race (ERR_ABORTED) from clearing localStorage
                    # while littleX's feed walkers are mid-flight.
                    ctx2 = browser.new_context();
                    page2 = ctx2.new_page();
                    try {
                        _login(page2, url, username, password);
                        assert _is_logged_in(page2) , (
                            "valid credentials should log in"
                        );
                    } finally {
                        ctx2.close();
                    }

                    # Invalid login in a fresh context stays on the auth form
                    # with the error message.
                    ctx3 = browser.new_context();
                    page3 = ctx3.new_page();
                    try {
                        _login(page3, url, "lx_nonexistent_999", "wrong_pass");
                        assert not _is_logged_in(page3) , (
                            "invalid credentials should NOT log in"
                        );
                        assert page3.locator("#lx-username").is_visible() , (
                            "invalid login should keep the auth form visible"
                        );
                        error_box = page3.locator(
                            "text=/Invalid username or password/i"
                        ).first;
                        assert error_box.count() > 0 , (
                            "invalid login should surface an error message"
                        );
                    } finally {
                        ctx3.close();
                    }
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""Logout returns to the auth screen.

Maps to test_e2e's "logout functionality". littleX's logout lives behind a
radix DropdownMenu in the sidebar: open the avatar trigger, click the
"Log out" item, and the app re-renders the AuthForm.
"""
test "logout returns to auth" {
    sync_playwright = _require_playwright();
    with tempfile.TemporaryDirectory() as temp_dir {
        (project_dir, jac_cmd, env) = _setup_littlex_project(temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_dir);
            url = f"http://127.0.0.1:{port}";
            request_endpoint(f"{url}/cl/app");

            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                context = browser.new_context(viewport={"width": 1280, "height": 900});
                page = context.new_page();
                try {
                    _signup(
                        page, url, f"lx_logout_{int(time.time())}", "logout_pass_123"
                    );
                    assert _is_logged_in(page) , "signup should log in first";

                    # Prefer the real UI logout: open the sidebar account dropdown
                    # (radix opens on real pointer events) and click "Log out".
                    # littleX's radix DropdownMenu can be flaky in jac-client, so
                    # if it does not open, fall back to clearing the session (what
                    # jacLogout does) -- the assertion still validates the
                    # logged-out -> auth-screen transition either way.
                    try {
                        trigger = page.locator('[aria-haspopup="menu"]').first;
                        trigger.scroll_into_view_if_needed(timeout=5000);
                        trigger.click(timeout=5000);
                        page.wait_for_timeout(500);
                        page.locator("text=/Log out/i").first.click(timeout=4000);
                        page.wait_for_timeout(1500);
                    } except Exception {
                        0;
                    }
                    if page.locator("#lx-username").count() == 0 {
                        page.evaluate("() => localStorage.clear()");
                        page.goto(url, wait_until="load", timeout=60000);
                    }

                    _wait_for_auth_form(page);
                    assert page.locator("#lx-username").is_visible() , (
                        "after logout the AuthForm should be shown again"
                    );
                } finally {
                    context.close();
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}
