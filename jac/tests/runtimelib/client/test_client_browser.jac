"""Browser (Playwright) tests for client runtime behaviors.

Recovers interaction coverage dropped when PR #6840 merged jac-client into
core (the deleted `test_e2e.jac` / `test_form.jac`). Drives the unified
`fixtures/fullstack` app:

* `/`     auto-cache (a reader is de-duplicated, a write invalidates it) and
          undefined-JSX render safety
* `/auth` jacSignup / jacLogin in both old (string) and new (credential) forms
* `/form` JacForm validation errors + submit-enabled / onSubmit wiring

Each test scaffolds the fixture into a temp dir, `jac start`s it, and drives a
headless Chromium. Skips cleanly when Playwright/Chromium is unavailable.
"""

import time;
import pytest;
import from subprocess { Popen }
import from tempfile { TemporaryDirectory }

import from .test_helpers {
    copy_fixture,
    request_endpoint,
    start_app_server,
    stop_server
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

"""Navigate to a route and wait for the document to load."""
def _goto(page: any, base: str, path: str) {
    page.goto(f"{base}{path}", wait_until="load", timeout=60000);
}

"""Fill the auth inputs, click a button, and return the resulting status text."""
def _click_and_wait_status(
    page: any, username: str, password: str, button_testid: str
) -> str {
    page.locator('[data-testid="username-input"]').fill(username);
    page.locator('[data-testid="password-input"]').fill(password);
    page.locator(f'[data-testid="{button_testid}"]').click();
    page.wait_for_function(
        "() => { const el = document.querySelector('[data-testid=\"status\"]');"
        " return el && /_(ok|fail|exc)/.test(el.textContent || ''); }",
        timeout=20000,
    );
    return page.locator('[data-testid="status"]').inner_text();
}

"""Poll until a recorded request list reaches ``target`` (or times out).

Returns the final count. Polling absorbs CI-vs-local timing variance: a slow
fetch is waited out, while a genuinely-missing request still fails the caller's
equality assertion after the deadline.
"""
def _wait_for_count(
    page: any, requests: list, target: int, timeout: float = 15.0
) -> int {
    deadline = time.time() + timeout;
    while len(requests) < target and time.time() < deadline {
        page.wait_for_timeout(250);
    }
    return len(requests);
}

"""A reader is fetched once then served from cache; a write invalidates it."""
test "auto cache dedupes reader and invalidates on write" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            # Make sure the bundle is ready before the browser loads it.
            request_endpoint(f"{base}/cl/app");
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    page = browser.new_context().new_page();
                    ping_requests: list = [];
                    page.on(
                        "request",
                        lambda req: any { "/walker/ping_server" in req.url
                        and ping_requests.append(req.url); },
                    );
                    _goto(page, base, "/");
                    ping_btn = page.locator('[data-testid="ping-btn"]');
                    ping_btn.wait_for(state="visible", timeout=30000);

                    # First ping: a single network fetch.
                    ping_btn.click();
                    _wait_for_count(page, ping_requests, 1);
                    assert len(ping_requests) == 1 , (
                        f"first ping should hit the server once, got {len(
                            ping_requests
                        )}"
                    );

                    # Second ping: served from cache -- no new request. Give it
                    # ample time to (not) fire before asserting it stayed put.
                    ping_btn.click();
                    page.wait_for_timeout(3000);
                    assert len(ping_requests) == 1 , (
                        f"second ping should be served from cache, got {len(
                            ping_requests
                        )}"
                    );

                    # A write must invalidate the reader cache. Wait for the
                    # write to actually complete (its marker mounts once the
                    # walker response is processed) so invalidation propagates.
                    page.locator('[data-testid="create-btn"]').click();
                    page.wait_for_selector('[data-testid="last-item"]', timeout=15000);
                    page.wait_for_timeout(500);

                    # Third ping: cache was invalidated, so it refetches.
                    ping_btn.click();
                    _wait_for_count(page, ping_requests, 2);
                    assert len(ping_requests) == 2 , (
                        f"ping after a write should refetch, got {len(ping_requests)}"
                    );
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""An undefined JSX child renders harmlessly (its sibling marker still mounts)."""
test "undefined jsx child does not crash render" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            request_endpoint(f"{base}/cl/app");
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    page = browser.new_context().new_page();
                    _goto(page, base, "/");
                    page.wait_for_selector(
                        '[data-testid="undef-child-probe-ok"]',
                        state="attached",
                        timeout=30000,
                    );
                    marker = page.locator(
                        '[data-testid="undef-child-probe-ok"]'
                    ).first.text_content();
                    assert marker == "ok" , f"expected probe marker 'ok', got {marker!r}";
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""jacSignup/jacLogin round trip works in both old and new calling forms."""
test "auth round trip in old and new calling forms" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            request_endpoint(f"{base}/cl/app");
            ts = int(time.time());
            user_old = f"old_{ts}";
            user_new = f"new_{ts}";
            password = "roundtrip_pass_123";
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    page = browser.new_context().new_page();
                    _goto(page, base, "/auth");
                    page.wait_for_selector(
                        '[data-testid="username-input"]', timeout=30000
                    );

                    assert _click_and_wait_status(
                        page, user_old, password, "signup-old"
                    ) == "signup_old_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(
                        page, user_old, password, "login-old"
                    ) == "login_old_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(
                        page, user_new, password, "signup-new"
                    ) == "signup_new_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(
                        page, user_new, password, "login-new"
                    ) == "login_new_ok";
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""JacForm shows a validation error on bad input and clears it when fixed."""
test "form shows validation error then clears it" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            request_endpoint(f"{base}/cl/app");
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    page = browser.new_context().new_page();
                    _goto(page, base, "/form");
                    email = page.locator('input[name="emailField"]');
                    email.wait_for(state="visible", timeout=30000);

                    email.fill("not-an-email");
                    email.blur();
                    err = page.locator("p:has-text('Invalid email')").first;
                    err.wait_for(state="visible", timeout=5000);
                    assert "Invalid email" in err.text_content();

                    email.fill("user@example.com");
                    email.blur();
                    page.locator("p:has-text('Invalid email')").first.wait_for(
                        state="hidden", timeout=5000
                    );
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}

"""The submit button enables once the form is valid and onSubmit fires."""
test "form submit enables when valid and onSubmit fires" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = start_app_server(project_path);
            base = f"http://127.0.0.1:{port}";
            request_endpoint(f"{base}/cl/app");
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    page = browser.new_context().new_page();
                    _goto(page, base, "/form");
                    submit = page.locator('button[type="submit"]');
                    submit.wait_for(state="visible", timeout=30000);
                    assert page.evaluate(
                        "() => document.querySelector('button[type=\"submit\"]').disabled"
                    ) , "submit should start disabled (form untouched)";

                    page.locator('input[name="emailField"]').fill("user@example.com");
                    page.locator('input[name="passwordField"]').fill("Abcdef12");
                    page.locator('input[name="passwordField"]').blur();
                    page.wait_for_function(
                        "() => { const b = document.querySelector('button[type=\"submit\"]');"
                        " return b && !b.disabled; }",
                        timeout=10000,
                    );

                    page.evaluate("() => { window.__submitFired = false; }");
                    submit.click();
                    page.wait_for_function(
                        "() => window.__submitFired === true", timeout=10000
                    );
                    assert page.evaluate("() => window.__submitFired") , (
                        "onSubmit handler should have fired"
                    );
                } finally {
                    browser.close();
                }
            }
        } finally {
            stop_server(server);
        }
    }
}
