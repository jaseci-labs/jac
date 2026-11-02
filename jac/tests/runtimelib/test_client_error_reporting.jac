"""Tests for client-side error reporting endpoint.

The /cl/__error__ endpoint allows client-side JavaScript to report
errors back to the server for logging and observability.
"""

import io;
import json;
import logging;
import uuid;
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
