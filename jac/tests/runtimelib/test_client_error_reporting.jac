"""Tests for client-side error reporting endpoint.

The /cl/__error__ endpoint allows client-side JavaScript to report
errors back to the server for logging and observability.
"""

import io;
import json;
import logging;
import uuid;
import from contextlib { AbstractContextManager }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.testing.testing { JacTestClient }

def _as_any(v: any) -> any {
    return v;
}

glob FIXTURES = str(Path(__file__).parent / "fixtures");

def fixture_abs_path(filename: str) -> str {
    return str((Path(FIXTURES) / filename).resolve());
}

def make_client(base_path: str) -> JacTestClient {
    return JacTestClient.from_file(
        fixture_abs_path("serve_api.jac"), base_path=base_path
    );
}

"""Attach a StringIO handler to logger and return (buf, handler, old_level)."""
def capture_log_start(
    logger: logging.Logger, level: int = logging.DEBUG
) -> tuple[any, ...] {
    buf = io.StringIO();
    handler = logging.StreamHandler(buf);
    handler.setLevel(level);
    logger.addHandler(handler);
    old_level = logger.level;
    logger.setLevel(level);
    return (buf, handler, old_level);
}

"""Remove handler and restore logger level."""
def capture_log_stop(
    logger: logging.Logger, handler: logging.StreamHandler, old_level: int
) {
    logger.removeHandler(handler);
    logger.setLevel(old_level);
}

# =============================================================================
# Client Error Reporting Tests
# =============================================================================
test "client error endpoint exists and accepts error reports" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.post(
            "/cl/__error__",
            json={
                "message": "Cannot use 'in' operator to search for '@' in undefined",
                "stack": "TypeError: Cannot use 'in' operator\n    at LoginPage (login.jac:42)",
                "url": "http://localhost:8001/",
                "source": "window.onerror",
                "timestamp": "2026-03-14T12:00:00Z"
            }
        );
        assert response.status_code == 200;
        client.close();
    }
}

test "client error is logged to server console" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        logger = logging.getLogger("jaclang.client_errors");
        (buf, handler, old_level) = capture_log_start(logger);
        try {
            # Use unique message to avoid rate limiter dedup across test runs
            error_msg = f"Test error {uuid.uuid4().hex}";
            client.post(
                "/cl/__error__",
                json={
                    "message": error_msg,
                    "stack": "TypeError: test\n    at TestFunc (test.jac:1)",
                    "url": "http://localhost:8001/",
                    "source": "window.onerror",
                    "timestamp": "2026-03-14T12:00:00Z"
                }
            );
            log_output = buf.getvalue();
            assert error_msg in log_output , f"Expected client error in log output, got: {log_output}";
        } finally {
            capture_log_stop(logger, handler, old_level);
        }
        client.close();
    }
}

test "client error componentStack is logged when provided" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        logger = logging.getLogger("jaclang.client_errors");
        (buf, handler, old_level) = capture_log_start(logger);
        try {
            error_msg = f"Render error {uuid.uuid4().hex}";
            comp_stack = "    in Toolbar\n    in App\n    in JacClientErrorBoundary";
            client.post(
                "/cl/__error__",
                json={
                    "message": error_msg,
                    "stack": "TypeError: d is not a function\n    at hs (/static/client.js:1:100)",
                    "componentStack": comp_stack,
                    "url": "http://localhost:8001/",
                    "source": "ErrorBoundary"
                }
            );
            log_output = buf.getvalue();
            assert error_msg in log_output;
            assert "Component stack:" in log_output , f"Expected component stack section in log, got: {log_output}";
            assert "in Toolbar" in log_output;
            assert "in App" in log_output;
        } finally {
            capture_log_stop(logger, handler, old_level);
        }
        client.close();
    }
}

test "client error endpoint handles missing fields gracefully" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        # Minimal payload - just a message
        response = client.post("/cl/__error__", json={"message": "Something broke"});
        assert response.status_code == 200;
        client.close();
    }
}

test "client error endpoint rejects empty payload" {
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        response = client.post("/cl/__error__", json={});
        assert response.status_code == 400;
        client.close();
    }
}

# =============================================================================
# Prod page error handler setup
# =============================================================================
"""Render a prod page for a stub client module and return its HTML."""
def render_stub_page -> str {
    import types;
    import from jaclang.client.serving { JacClient }
    module = types.ModuleType('stub');
    module.__file__ = __file__;
    introspector = types.SimpleNamespace(
        _client_manifest={'exports': ['app'], 'endpoint_effects': {}},
        _bundle=None,
        _module=module,
        module_name='stub',
        load=lambda { None; },
        get_client_functions=lambda { {'app': None}; },
        ensure_bundle=lambda { 'abc123'; }
    );
    result = JacClient.render_page(_as_any(introspector), 'app', {}, 'guest');
    return result['html'];
}

test "prod render_page injects early error handler before module bundle script" {
    html = render_stub_page();
    assert 'window.__jacErrorHandlersInstalled' in html;
    assert '/cl/__error__' in html;
    # Handler script must appear before the bundle so it catches errors during evaluation
    assert html.index('window.__jacErrorHandlersInstalled') < html.index('client.js');
}

# =============================================================================
# Client-side report budget
# =============================================================================
"""Run the budget harness in `mode` against `targets` and return its results."""
def run_error_budget_harness(mode: str, targets: list[Path]) -> dict[str, any] {
    import subprocess;
    result = subprocess.run(
        ["node", fixture_abs_path("client_error_budget_harness.mjs"), mode]
            + [str(t) for t in targets],
        capture_output=True,
        text=True,
        timeout=120
    );
    assert result.returncode == 0 , f"harness failed:\n{result.stdout}\n{result.stderr}";
    return json.loads(result.stdout.strip().splitlines()[-1]);
}

"""Compile one runtime core into `work` beside the modules it imports, with its
npm imports stubbed, and return the path node should load."""
def write_runtime_core(work: Path, core_name: str) -> Path {
    import from jaclang.client.runtime_source { resolve_client_runtime_cl_path }
    import from .react_jsdom_harness {
        compile_react,
        wire_jac_runtime,
        write_runtime_support
    }
    runtime_path = resolve_client_runtime_cl_path("react");
    write_runtime_support(work, runtime_path);
    js = wire_jac_runtime(
        compile_react(str(Path(runtime_path).parent / f"{core_name}.jac"))
    );
    for npm_module in ["react", "react-hook-form", "@hookform/resolvers/zod"] {
        js = js.replace(f'"{npm_module}"', '"./npm_stub.js"');
    }
    (work / "jac_runtime.js").write_text(
        "export function __jacJsx() { return null; }\n", encoding="utf-8"
    );
    (work / "npm_stub.js").write_text(
        "export const useForm = () => null;\nexport const zodResolver = () => null;\n",
        encoding="utf-8"
    );
    (work / "package.json").write_text('{"type": "module"}', encoding="utf-8");
    core = work / f"{core_name}.js";
    core.write_text(js, encoding="utf-8");
    return core;
}

"""Write the early error handler a served page inlines to `work` and return its path."""
def write_early_handler(work: Path) -> Path {
    import re;
    scripts = re.findall(r"<script>(.*?)</script>", render_stub_page(), re.S);
    handlers = [
        s
        for s in scripts
        if "/cl/__error__" in s
    ];
    assert len(handlers) == 1 , scripts;
    script = work / "early_error_handler.js";
    script.write_text(handlers[0], encoding="utf-8");
    return script;
}

"""The budget every reporter holds a page to."""
def assert_page_budget(results: dict[str, any]) {
    for name in [
        "extensionRejections",
        "firefoxExtensionRejections",
        "safariExtensionRejections",
        "extensionStackWithEngineFrames",
        "safariExtensionStackWithNativeFrame",
        "extensionStackWithUrlMessage"
    ] {
        assert results[name]["sent"] == 0 , (name, results[name]);
    }
    # One report per distinct error, however often it is thrown.
    assert results["identicalAppErrors"]["sent"] == 1 , results;
    # A stack that passes through app code is ours to see, wherever that code
    # was loaded from.
    for name in [
        "mixedStack",
        "mixedStackWithBlobFrame",
        "firefoxMixedStackWithBlobFrame"
    ] {
        assert results[name]["sent"] == 1 , (name, results[name]);
    }
    # At most 10 reports a minute, and the budget refills the next minute...
    assert results["distinctAppErrors"]["sent"] == 10 , results;
    assert results["distinctAppErrorsOverTwoMinutes"]["sent"] == 20 , results;
    # The minute trails each report, so no burst straddles a window edge...
    assert results["burstAcrossMinuteBoundary"]["sent"] == 11 , results;
    # ...up to 200 for the page, after which nothing new or repeated is sent.
    assert results["distinctAppErrorsOverHalfAnHour"]["sent"] == 200 , results;
}

test "runtime reporter drops extension errors and caps reports per page" {
    import from jaclang.testing.requires { require_tool }
    require_tool("node");
    with TemporaryDirectory() as tmp {
        core = write_runtime_core(Path(tmp), "client_runtime_core");
        results = run_error_budget_harness("runtime", [core]);
    }
    assert_page_budget(results);
    assert results["extensionScriptWithoutStack"]["sent"] == 0 , results;
    assert results["appWindowError"]["sent"] == 1 , results;
    first = results["identicalAppErrors"]["first"];
    assert first["endpoint"] == "/cl/__error__";
    assert first["message"] == "boom";
    assert first["source"] == "unhandledrejection";
}

test "native runtime reporter holds the same per-page budget" {
    import from jaclang.testing.requires { require_tool }
    require_tool("node");
    with TemporaryDirectory() as tmp {
        core = write_runtime_core(Path(tmp), "client_react_core");
        results = run_error_budget_harness("native", [core]);
    }
    assert_page_budget(results);
    assert results["identicalAppErrors"]["first"]["source"] == "ErrorUtils";
}

test "prod early error handler holds the same per-page budget" {
    import from jaclang.testing.requires { require_tool }
    require_tool("node");
    with TemporaryDirectory() as tmp {
        results = run_error_budget_harness("inline", [write_early_handler(Path(tmp))]);
    }
    assert_page_budget(results);
    assert results["extensionScriptWithoutStack"]["sent"] == 0 , results;
    assert results["appWindowError"]["sent"] == 1 , results;
    # Once the runtime has installed its own handlers, the early one stands down.
    assert results["afterRuntimeHandlersInstalled"]["sent"] == 0 , results;
}

test "early handler and runtime share one budget across the handoff" {
    import from jaclang.testing.requires { require_tool }
    require_tool("node");
    with TemporaryDirectory() as tmp {
        work = Path(tmp);
        core = write_runtime_core(work, "client_runtime_core");
        results = run_error_budget_harness(
            "handoff", [core, write_early_handler(work)]
        );
    }
    # The early handler spends the first minute's 10 reports; the runtime takes
    # over the same budget, so it sends nothing more until the next minute and
    # never repeats an error the early handler already sent.
    assert results["early"] == 10 , results;
    assert results["sameMinute"] == 0 , results;
    assert results["nextMinute"] == 10 , results;
}

# =============================================================================
# Server-side limits on /cl/__error__ (#10411)
# =============================================================================
# The stack the jachammer flood carried (jacBuilder#2354), as in the harness.
glob EXTENSION_STACK: str = "TypeError: Cannot read properties of undefined (reading 'M_ID')\n    at Y (chrome-extension://eppiocemhmnlbhjplcgkofciiegomcon/executors/200.js:1:761)\n    at E (chrome-extension://eppiocemhmnlbhjplcgkofciiegomcon/executors/200.js:1:1442)",
     FIREFOX_EXTENSION_STACK: str = "Y@moz-extension://0a1b2c3d/content.js:1:761\nE@moz-extension://0a1b2c3d/content.js:1:1442",
     MIXED_STACK: str = "TypeError: boom\n    at hook (chrome-extension://abc/inject.js:1:5)\n    at render (https://app.test/static/client.js:1:200)",
     APP_STACK: str = "TypeError: boom\n    at render (https://app.test/static/client.js:1:200)";

def error_report(message: str, stack: str = APP_STACK) -> dict[str, any] {
    return {"message": message, "stack": stack, "source": "window.onerror"};
}

"""Statuses, Retry-After values, the first 429 body and how many accepted
reports were dropped as repeats, for reports posted round-robin across
`clients`, each standing in for one worker."""
def post_reports(
    clients: list[JacTestClient], messages: list[str]
) -> tuple[list[int], list[any], dict[str, dict[str, str]] | None, int] {
    statuses: list[int] = [];
    retry_after: list[any] = [];
    refused: dict[str, dict[str, str]] | None = None;
    repeats = 0;
    for (i, message) in enumerate(messages) {
        resp = clients[i % len(clients)].post(
            "/cl/__error__", json=error_report(message)
        );
        statuses.append(resp.status_code);
        if resp.status_code == 429 {
            retry_after.append(resp.headers.get("Retry-After"));
            refused = refused or resp.json();
        } elif resp.json().get("throttled") {
            repeats += 1;
        }
    }
    return (statuses, retry_after, refused, repeats);
}

"""Count the JSON bodies the server parses while the block runs."""
def count_body_parses -> tuple[AbstractContextManager[object], list[int]] {
    import from unittest.mock { patch }
    import from jaclang.server.serving.datatypes { Request }
    parses: list[int] = [0];
    original = Request.json_sync;
    def counted(request: Request) -> object {
        parses[0] += 1;
        return original(request);
    }
    return (patch.object(Request, "json_sync", counted), parses);
}

def assert_backs_off(label: str, statuses: list[int], retry_after: list[any]) {
    assert 429 in statuses , f"{label}: a flood of error reports never got a 429: {statuses}";
    assert statuses.count(200) <= 20 , f"{label}: more than one budget was accepted: {statuses}";
    first_refusal = statuses.index(429);
    assert set(statuses[first_refusal:]) == {429} , (
        f"{label}: a report got through after the client was refused: {statuses}"
    );
    for value in retry_after {
        assert value is not None and 1 <= int(value) <= 60 , (
            f"{label}: a 429 without a usable Retry-After: {retry_after}"
        );
    }
}

def assert_rate_limited_body(label: str, body: dict[str, dict[str, str]] | None) {
    assert body and body["error"]["code"] == "RATE_LIMITED" , (label, body);
    assert body["error"]["message"].startswith("Too many attempts") , (label, body);
}

test "a client past its error-report budget gets 429 with Retry-After, across workers" {
    import from unittest.mock { patch }
    import from jaclang.client.source_mapping { ClientErrorLimiter }
    import from jaclang.server.identity.rate_limit { consume_limit }
    tag = uuid.uuid4().hex;
    rows = [
        (
            "distinct reports",
            [f"distinct {tag} {i}" for i in range(40)],
            1,
            True,
            False
        ),
        ("the same report in a loop", [f"looping {tag}"] * 40, 1, True, True),
        (
            "distinct reports across two workers",
            [f"spread {tag} {i}" for i in range(40)],
            2,
            True,
            False
        ),
        (
            "no shared store, so each worker counts",
            [f"local {tag} {i}" for i in range(40)],
            1,
            False,
            False
        ),
        (
            "the same report in a loop, no shared store",
            [f"local looping {tag}"] * 40,
            1,
            False,
            True
        )
    ];
    for (label, messages, workers, shared, looping) in rows {
        (counting, parses) = count_body_parses();
        with TemporaryDirectory() as tmpdir {
            clients = [make_client(tmpdir) for _ in range(workers)];
            try {
                with counting {
                    if shared {
                        (statuses, retry_after, refused, repeats) = post_reports(
                            clients, messages
                        );
                    } else {
                        with patch(
                            consume_limit.__module__ + ".shared_store",
                            return_value=None
                        ) {
                            (statuses, retry_after, refused, repeats) = post_reports(
                                clients, messages
                            );
                        }
                    }
                }
            } finally {
                for client in clients {
                    client.close();
                }
            }
        }
        assert_backs_off(label, statuses, retry_after);
        assert_rate_limited_body(label, refused);
        accepted = statuses.count(200);
        assert repeats == (accepted - 1 if looping else 0) , (
            f"{label}: {repeats} of {accepted} accepted reports were dropped as repeats"
        );
        assert parses[0] == accepted , (
            f"{label}: {parses[0]} bodies parsed for {accepted} accepted reports"
        );
    }

    limiter = ClientErrorLimiter();
    big = "x" * 60000;
    with patch(consume_limit.__module__ + ".shared_store", return_value=None) {
        assert limiter.admit("203.0.113.30") == 0;
    }
    assert not limiter.is_repeat("203.0.113.30", big);
    assert limiter.is_repeat("203.0.113.30", big);
    seen = limiter._clients["203.0.113.30"].seen;
    assert all(len(key) <= 32 for key in seen) , (
        f"the dedup map holds {[len(key) for key in seen]} bytes per report"
    );
}

"""POST `payload` to 127.0.0.1:`port` as if forwarded for `client_ip`."""
def post_as(port: int, client_ip: str, payload: dict[str, any]) -> int {
    import http.client;
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10);
    try {
        conn.request(
            "POST",
            "/cl/__error__",
            body=json.dumps(payload),
            headers={"Content-Type": "application/json", "X-Forwarded-For": client_ip}
        );
        resp = conn.getresponse();
        resp.read();
        return resp.status;
    } finally {
        conn.close();
    }
}

test "one client's flood does not mute another client's report" {
    import logging.handlers;
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.server.settings { ProxySettings, ServeSettings }
    tag = uuid.uuid4().hex;
    logger = logging.getLogger("jaclang.client_errors");
    records = logging.handlers.BufferingHandler(100000);
    old_level = logger.level;
    logger.setLevel(logging.ERROR);
    logger.addHandler(records);
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        settings = ServeSettings(proxy=ProxySettings(trusted=["127.0.0.1/32"]));
        app = client.server.app;
        assert app is not None , "the test client built no app";
        server = ServingServer(app=app, settings=settings, host="127.0.0.1", port=0);
        stop = server.serve_background();
        try {
            noisy = [
                post_as(
                    server.bound_port, "203.0.113.10", error_report(f"noisy {tag} {i}")
                ) for i in range(40)
            ];
            quiet = post_as(
                server.bound_port, "203.0.113.20", error_report(f"quiet {tag}")
            );
        } finally {
            stop();
            client.close();
            logger.removeHandler(records);
            logger.setLevel(old_level);
        }
    }
    assert 429 in noisy , f"the noisy client was never refused: {noisy}";
    assert quiet == 200 , f"the quiet client's report was refused: {quiet}";
    logged = [r.getMessage() for r in records.buffer];
    assert any(f"quiet {tag}" in m for m in logged) , (
        "the quiet client's real error was not logged after another client's flood"
    );
}

test "an oversized error report is refused with 413" {
    (counting, parses) = count_body_parses();
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            with counting {
                normal = client.post(
                    "/cl/__error__", json=error_report("normal " + "x" * 8000)
                );
                oversized = client.post(
                    "/cl/__error__", json=error_report("oversized " + "x" * 200000)
                );
            }
        } finally {
            client.close();
        }
    }
    assert parses[0] == 1 , f"{parses[
        0
    ]} bodies parsed; the oversized one should not be";
    assert normal.status_code == 200 , normal.status_code;
    assert oversized.status_code == 413 , (
        f"a 200 KB report was accepted: {oversized.status_code} {oversized.text[:80]}"
    );
}

test "a browser extension's error is tagged and logged below ERROR" {
    import logging.handlers;
    tag = uuid.uuid4().hex;
    logger = logging.getLogger("jaclang");
    records = logging.handlers.BufferingHandler(100000);
    old_level = logger.level;
    logger.setLevel(logging.DEBUG);
    logger.addHandler(records);
    reports = {
        "chrome": EXTENSION_STACK,
        "firefox": FIREFOX_EXTENSION_STACK,
        "mixed": MIXED_STACK
    };
    statuses: dict[str, int] = {};
    with TemporaryDirectory() as tmpdir {
        client = make_client(tmpdir);
        try {
            for (name, stack) in reports.items() {
                statuses[name] = client.post(
                    "/cl/__error__", json=error_report(f"{name} {tag}", stack)
                ).status_code;
            }
        } finally {
            client.close();
            logger.removeHandler(records);
            logger.setLevel(old_level);
        }
    }
    assert statuses == {"chrome": 200, "firefox": 200, "mixed": 200} , statuses;

    def levels_for(name: str) -> list[int] {
        return [
            r.levelno
            for r in records.buffer
            if f"{name} {tag}" in r.getMessage()
        ];
    }
    for name in ["chrome", "firefox"] {
        levels = levels_for(name);
        assert levels , f"the {name} extension error was not logged at all";
        assert max(levels) < logging.ERROR , (
            f"the {name} extension error was logged at {levels}"
        );
        tagged = [
            r.getMessage()
            for r in records.buffer
            if f"{name} {tag}" in r.getMessage()
        ];
        assert any("browser extension" in m for m in tagged) , tagged;
    }
    assert max(levels_for("mixed")) >= logging.ERROR , (
        "an error whose stack passes through the app was not logged at ERROR"
    );
}

"""A service that answers every POST with 200 and counts what reached it."""
def serve_counting_upstream -> tuple[any, ...] {
    import http.server;
    import threading;
    hits: list[str] = [];
    body = b'{"ok": true}';
    def _do_post(handler: any) {
        handler.rfile.read(int(handler.headers.get("Content-Length") or 0));
        hits.append(handler.path);
        handler.send_response(200);
        handler.send_header("Content-Type", "application/json");
        handler.send_header("Content-Length", str(len(body)));
        handler.end_headers();
        handler.wfile.write(body);
    }
    def _quiet(handler: any, fmt: str, *args: any) {}
    handler_cls = type(
        "_CountingHandler",
        (http.server.BaseHTTPRequestHandler, ),
        {"do_POST": _do_post, "log_message": _quiet}
    );
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_cls);
    threading.Thread(target=srv.serve_forever, daemon=True).start();
    return (srv, srv.server_address[1], hits);
}

test "[scale.gateway.rate_limit] client_error_rpm sets or turns off the gateway's report limit" {
    import from jaclang.scale.config.config_loader { normalize_gateway_config }
    import from jaclang.scale.config.validation { validate_scale_config }
    import from jaclang.scale.runtime.middleware.rate_limit {
        build_client_error_limit_middleware
    }
    assert normalize_gateway_config({})["rate_limit"]["client_error_rpm"] == 20;
    tuned = normalize_gateway_config({"rate_limit": {"client_error_rpm": 5}});
    assert tuned["rate_limit"]["client_error_rpm"] == 5 , tuned["rate_limit"];
    assert validate_scale_config({"gateway": {"rate_limit": {"client_error_rpm": 5}}})
        == [];
    assert build_client_error_limit_middleware({"client_error_rpm": 0}) is None;
    assert build_client_error_limit_middleware({"client_error_rpm": 5}) is not None;
}

test "the gateway refuses an error-report flood only when it can tell clients apart" {
    import os;
    import from unittest.mock { patch }
    import from jaclang.scale.runtime.gateway.microservice_gateway {
        MicroserviceGateway
    }
    import from jaclang.scale.runtime.gateway.service_registry {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    import asyncio;
    import from jaclang.scale.runtime.middleware.rate_limit {
        StateBackendRateLimiter,
        client_error_limit_skipped
    }
    import from jaclang.scale.state.factory { _backend_holder }
    import from jaclang.testing.testkit { ServingTestClient }
    limit = {"client_error_rpm": 20};
    skipped = client_error_limit_skipped(limit, [], True);
    assert "[serve.proxy] trusted" in skipped and "ingress" in skipped , skipped;
    assert "Each service still limits" in skipped , skipped;
    assert client_error_limit_skipped(limit, ["10.0.0.0/8"], True) == "";
    assert client_error_limit_skipped(limit, [], False) == "";
    assert client_error_limit_skipped({"client_error_rpm": 0}, [], True) == "";

    gateway_logger = logging.getLogger("jaclang.scale.runtime");
    original_consume = StateBackendRateLimiter.consume;
    rows = [
        ("outside a cluster", "", "", True, False),
        ("in a cluster, the ingress trusted", "10.96.0.1", "10.0.0.0/8", True, False),
        ("in a cluster, nothing trusted", "10.96.0.1", "", False, False),
        ("the limit's storage is down", "", "", False, True)
    ];
    for (label, cluster_host, trusted, should_limit, store_down) in rows {
        on_event_loop: list[bool] = [];
        def consume(limiter: StateBackendRateLimiter, key: str) -> tuple[bool, float] {
            try {
                asyncio.get_running_loop();
                on_event_loop.append(True);
            } except RuntimeError {
                on_event_loop.append(False);
            }
            if store_down {
                raise RuntimeError("the database went away");
            }
            return original_consume(limiter, key);
        }
        _backend_holder.clear();
        (srv, port, hits) = serve_counting_upstream();
        registry = ServiceRegistry();
        registry.register(
            ServiceEntry(
                name="web",
                file="web.jac",
                prefix="/web",
                port=port,
                url=f"http://127.0.0.1:{port}",
                status=ServiceStatus.HEALTHY
            )
        );
        env = {
            "KUBERNETES_SERVICE_HOST": cluster_host,
            "JAC_SERVE_PROXY_TRUSTED": trusted
        };
        statuses: list[int] = [];
        retry_after: list[any] = [];
        refused: dict[str, dict[str, str]] | None = None;
        with TemporaryDirectory() as tmp {
            (buf, handler, old_level) = capture_log_start(gateway_logger, logging.INFO);
            try {
                with patch.dict(os.environ, env), patch.object(
                    StateBackendRateLimiter, "consume", consume
                ) {
                    gateway = MicroserviceGateway(registry=registry, base_path=tmp);
                    gateway.setup();
                    client = ServingTestClient(gateway.app);
                    for i in range(60) {
                        resp = client.post(
                            "/cl/__error__", json=error_report(f"flood {i}")
                        );
                        statuses.append(resp.status_code);
                        if resp.status_code == 429 {
                            retry_after.append(resp.headers.get("Retry-After"));
                            refused = refused or resp.json();
                        }
                    }
                }
            } finally {
                capture_log_stop(gateway_logger, handler, old_level);
                srv.shutdown();
                _backend_holder.clear();
            }
        }
        if should_limit {
            assert 429 in statuses , f"{label}: the gateway forwarded every report: {statuses}";
            assert len(hits) < 30 , f"{label}: {len(
                hits
            )} of 60 reports reached the service";
            assert all(
                v is not None and int(v) >= 1 for v in retry_after
            ) , retry_after;
            assert_rate_limited_body(label, refused);
        } else {
            assert 429 not in statuses , (
                f"{label}: the gateway limited every browser as one client: {statuses}"
            );
            assert len(hits) == 60 , f"{label}: {len(
                hits
            )} of 60 reports reached the service";
        }
        assert not any(on_event_loop) , f"{label}: the limit was counted on the event loop";
        failures = buf.getvalue().count("Error-report limit storage failed");
        assert failures == (1 if store_down else 0) , (
            f"{label}: storage failure logged {failures} times"
        );
        noted = "client_error_rpm is not applied" in buf.getvalue();
        assert noted == (not should_limit and not store_down) , (
            f"{label}: expected the gateway to say it skips the limit: {not should_limit}; got {buf.getvalue()!r}"
        );
    }
}
