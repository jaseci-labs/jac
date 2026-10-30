"""Browser (Playwright) tests for client runtime behaviors.

Recovers interaction coverage dropped when PR #6840 merged jac-client into
core (the deleted `test_e2e.jac` / `test_form.jac`). Drives the unified
`fixtures/fullstack` app:

* `/`     auto-cache (a reader is de-duplicated, a write invalidates it) and
          undefined-JSX render safety
* `/auth` jacSignup / jacLogin in both old (string) and new (credential) forms
* `/form` JacForm validation errors + submit-enabled / onSubmit wiring

Each test scaffolds the fixture into a temp dir, `jac run --serve`s it, and drives a
headless Chromium. Skips cleanly when Playwright/Chromium is unavailable.
"""

import asyncio;
import faulthandler;
import json;
import os;
import time;
import from pathlib { Path }
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
        testskip("playwright not installed");
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
    page: any, requests: list[any], target: int, timeout: float = 15.0
) -> int {
    deadline = time.time() + timeout;
    while len(requests) < target and time.time() < deadline {
        page.wait_for_timeout(250);
    }
    return len(requests);
}

"""A first HMR connection catches an edit published after its document loaded."""
test "initial HMR connection catches up an edit made before it subscribes" {
    sync_playwright = _require_playwright();
    with TemporaryDirectory() as temp_dir {
        project_path = copy_fixture("fullstack", temp_dir);
        source = Path(project_path) / "main.jac";
        initial_marker = "hmr-before-subscription";
        updated_marker = "hmr-after-subscription";
        initial_source = (
            'def:pub app() -> JsxElement {\n'
            '    return <main>{"hmr-before-subscription"}</main>;\n'
            '}\n'
        );
        source.write_text(initial_source, encoding="utf-8");
        server: Popen | None = None;
        hang_trace: any = None;
        try {
            (server, port) = start_app_server(project_path, extra_args=["--dev"]);
            base = f"http://127.0.0.1:{port}";
            # A dispatcher deadlock also stops Playwright's own timeouts.
            # The runner captures stderr, so keep the fatal trace outside it.
            trace_path = Path(os.environ.get("RUNNER_TEMP") or temp_dir)
                / "jac-hmr-startup-hang.log";
            hang_trace = trace_path.open("w");
            faulthandler.dump_traceback_later(300, file=hang_trace, `exit=True);
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                try {
                    witness = browser.new_context().new_page();
                    witness_frames: list[any] = [];
                    witness_changes: list[any] = [];
                    completed_builds: list[any] = [];
                    witness_faults: list[str] = [];
                    witness.on(
                        "close",
                        lambda { witness_faults.append("observer page closed"); }
                    );
                    browser.on(
                        "disconnected",
                        lambda { witness_faults.append("browser disconnected"); }
                    );
                    def observe_socket(socket: any) {
                        try {
                            upstream = socket.connect_to_server();
                        } except Exception as exc {
                            witness_faults.append("connect:" + type(exc).__name__);
                            return;
                        }
                        def forward_close(peer: any, code: any, reason: any) {
                            witness_faults.append("observer socket closed");
                            try {
                                peer.close(code=code, reason=reason);
                            } except Exception as exc {
                                witness_faults.append("close:" + type(exc).__name__);
                            }
                        }
                        def observe_message(payload: any) {
                            try {
                                message = json.loads(payload);
                                witness_frames.append(message);
                                if message.get("type") == "error" {
                                    witness_faults.append("server error frame");
                                }
                                if message.get("type") in ("update", "full-reload") {
                                    witness_changes.append(message);
                                    if message.get("type") == "full-reload"
                                        and message.get("jacTriggered") is True {
                                        completed_builds.append(message);
                                    }
                                } else {
                                    socket.send(payload);
                                }
                            } except Exception as exc {
                                witness_faults.append("frame:" + type(exc).__name__);
                            }
                        }
                        # Keep this real connection alive across the edit; the
                        # witness observes changes without applying or reloading.
                        upstream.on_message(observe_message);
                        socket.on_close(
                            lambda (code: any, reason: any) { forward_close(
                                upstream, code, reason
                            ); }
                        );
                        upstream.on_close(
                            lambda (code: any, reason: any) { forward_close(
                                socket, code, reason
                            ); }
                        );
                    }
                    witness.route_web_socket("**/*", observe_socket);
                    try {
                        _goto(witness, base, "/");
                        witness.get_by_text(initial_marker, exact=True).wait_for();
                        _wait_for_count(witness, witness_frames, 1);
                    } finally {
                        assert not witness_faults , f"invalid HMR witness: {witness_faults}";
                    }
                    assert `any(f.get("type") == "connected" for f in witness_frames) , (
                        "the witness must receive the real HMR connection handshake"
                    );

                    page = browser.new_context().new_page();
                    gate: dict[str, any] = {
                        "held": False,
                        "released": False,
                        "premature_connections": 0,
                        "release": None,
                        "forwarded_frames": [],
                        "broadcasts_before_join": 0
                    };
                    async def hold_first_connection(socket: any) {
                        if gate["released"] {
                            socket.connect_to_server();
                            return;
                        }
                        if gate["held"] {
                            gate["premature_connections"] += 1;
                        } else {
                            gate["held"] = True;
                            gate["release"] = asyncio.get_running_loop().create_future();
                        }
                        # WS route handlers run on Playwright's dispatcher, not
                        # an event greenlet: sync Playwright waits deadlock here.
                        await gate["release"];
                        # Returning before release would open a mock socket.
                        upstream = socket.connect_to_server();
                        def forward_message(payload: any) {
                            kind = "other";
                            try {
                                kind = str(json.loads(payload).get("type", "other"));
                            } except (ValueError, TypeError, AttributeError) {}
                            socket.send(payload);
                            gate["forwarded_frames"].append(kind);
                        }
                        upstream.on_message(forward_message);
                    }
                    page.route_web_socket("**/*", hold_first_connection);
                    try {
                        _goto(page, base, "/");
                        page.get_by_text(initial_marker, exact=True).wait_for();
                        assert gate["held"] , "the HMR join was not held";
                        print(
                            "HMR catch-up: old DOM loaded with first connection held",
                            flush=True
                        );
                        # Observe the actual completed-build broadcast elsewhere;
                        # a compiled file alone does not prove it preceded the join.
                        source.write_text(
                            initial_source.replace(initial_marker, updated_marker),
                            encoding="utf-8"
                        );
                        deadline = time.monotonic() + 60.0;
                        while not completed_builds
                            and not witness_faults
                            and not gate["premature_connections"]
                            and time.monotonic() < deadline {
                            witness.wait_for_timeout(250);
                        }
                        assert completed_builds , (
                            "the witness must receive the completed-build reload before the join"
                        );
                        compiled = Path(project_path)
                            / ".jac"
                            / "client"
                            / "compiled"
                            / "main.js";
                        assert updated_marker in compiled.read_text(encoding="utf-8") , (
                            "the completed build must contain the edited marker"
                        );
                        gate["broadcasts_before_join"] = len(witness_changes);
                        print(
                            "HMR catch-up: compiled edit and real reload broadcast preceded the first connection",
                            flush=True
                        );
                    } finally {
                        gate["released"] = True;
                        release = gate["release"];
                        if release is not None and not release.done() {
                            release.set_result(None);
                        }
                    }
                    assert not gate["premature_connections"] , (
                        "invalid initial-join scenario: another connection attempted to bypass the hold"
                    );
                    assert not witness_faults , f"invalid HMR witness: {witness_faults}";
                    try {
                        deadline = time.monotonic() + 30.0;
                        while "connected" not in gate["forwarded_frames"]
                            and not witness_faults
                            and time.monotonic() < deadline {
                            page.wait_for_timeout(100);
                        }
                        # This proves server acceptance and forwarding was
                        # requested, not delivery to the browser's JS client.
                        assert "connected" in gate["forwarded_frames"] , (
                            "invalid initial-join scenario: the held target never received and forwarded the real HMR handshake"
                        );
                        assert not witness_faults , f"invalid HMR witness: {witness_faults}";
                        page.get_by_text(updated_marker, exact=True).wait_for(
                            timeout=30000
                        );
                        assert page.get_by_text(initial_marker, exact=True).count()
                            == 0;
                    } finally {
                        # Bounded observation, not proof against arbitrarily late events.
                        try {
                            witness.wait_for_timeout(1000);
                        } except Exception as exc {
                            witness_faults.append("drain:" + type(exc).__name__);
                        }
                        assert not witness_faults , f"invalid HMR witness: {witness_faults}";
                        assert len(witness_changes) == gate["broadcasts_before_join"] , (
                            "a later shared HMR broadcast invalidated the isolated initial-join scenario"
                        );
                    }
                } finally {
                    browser.close();
                }
            }
        } finally {
            try {
                stop_server(server);
            } finally {
                faulthandler.cancel_dump_traceback_later();
                if hang_trace is not None {
                    hang_trace.close();
                }
            }
        }
    }
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
                    ping_requests: list[any] = [];
                    page.on(
                        "request",
                        lambda (req: any) { "/walker/ping_server" in req.url
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
                    )
                        == "signup_old_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(page, user_old, password, "login-old")
                        == "login_old_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(
                        page, user_new, password, "signup-new"
                    )
                        == "signup_new_ok";

                    page.locator('[data-testid="logout-btn"]').click();
                    page.wait_for_timeout(500);
                    assert _click_and_wait_status(page, user_new, password, "login-new")
                        == "login_new_ok";
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
