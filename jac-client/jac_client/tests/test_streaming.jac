"""Tests for jacSpawnStream / jacCallFunctionStream / useJacStream.

Three levels of coverage:
  1. Server-side SSE emission: jac-scale wraps generator returns as
     text/event-stream with correct frame format. (Python, no browser)
  2. Client bundle compilation: compiled JS contains the new symbols.
  3. End-to-end browser: useJacStream drives a real streaming walker
     and streamed events appear in the DOM. (Playwright + Chromium)
"""

import gc;
import json;
import os;
import shutil;
import tempfile;
import time;
import pytest;
import httpx;
import from pathlib { Path }
import from subprocess { PIPE, STDOUT, Popen, run }

import from playwright.sync_api { sync_playwright }

import from .test_helpers {
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port
}


glob _STREAM_APP_JAC: str = """\"\"\"Streaming test app: server + client.\"\"\"

def _events(up_to: int) -> Any {
    for i in range(up_to) {
        yield {"index": i, "value": f"item-{i}"};
    }
}

def _error_events -> Any {
    yield {"index": 0};
    yield {"index": 1};
    raise Exception("deliberate stream error");
}

walker:pub count_up {
    has up_to: int = 3;
    can run with Root entry {
        report _events(self.up_to);
    }
}

walker:pub count_error {
    can run with Root entry {
        report _error_events();
    }
}

walker:pub plain_report {
    can run with Root entry {
        report {"hello": "world"};
    }
}

def:pub stream_func(n: int = 3) -> Any {
    for i in range(n) {
        yield {"fn_index": i};
    }
}

cl {
    def:pub app -> JsxElement {
        stream = useJacStream("count_up");

        return
            <div id="app">
                <button
                    id="start-btn"
                    onClick={lambda { stream.start({"up_to": 4}); }}
                >
                    Start
                </button>
                <p id="status">
                    {("streaming" if stream.isStreaming else "idle")}
                </p>
                <ul id="events">
                    {[
                        <li key={i} className="event-item">
                            {String(e.index)}
                        </li>
                        for (i, e) in enumerate(stream.events)
                    ]}
                </ul>
                {(<p id="error">{stream.error}</p>
                    if stream.error
                    else None)}
            </div>;
    }
}
""",
     _TOKEN_APP_JAC: str = """\"\"\"Token and structured event streaming app.\"\"\"

def _tokens -> Any {
    for word in ["The", " quick", " brown", " fox"] {
        yield {"token": word};
    }
}

walker:pub token_stream {
    can run with Root entry {
        report _tokens();
    }
}

def _steps -> Any {
    yield {"type": "thinking",  "detail": "reading files"};
    yield {"type": "tool_call", "detail": "read main.jac"};
    yield {"type": "tool_done", "detail": "read main.jac", "duration_ms": 42};
    yield {"type": "done",      "detail": "task complete"};
}

walker:pub event_stream {
    can run with Root entry {
        report _steps();
    }
}
""",
     _TOKEN_E2E_APP_JAC: str = """\"\"\"Token accumulation E2E app.\"\"\"

def _tokens -> Any {
    for word in ["The", " quick", " brown", " fox"] {
        yield {"token": word};
    }
}

walker:pub token_stream {
    can run with Root entry {
        report _tokens();
    }
}

cl {
    def:pub app -> JsxElement {
        stream = useJacStream("token_stream");
        text = [e.token for e in stream.events].join("");
        return
            <div id="app">
                <button id="go-btn" onClick={lambda { stream.start({}); }}>Go</button>
                <p id="output">{text}</p>
                <p id="status">{("streaming" if stream.isStreaming else "idle")}</p>
            </div>;
    }
}
""";


"""Write main.jac + jac.toml to tmpdir, start jac server, return (proc, port, base_url, tmpdir)."""
def _start_server(app_src: str, project_name: str = "stream-test") -> tuple {
    tmpdir = tempfile.mkdtemp();
    with open(os.path.join(tmpdir, "main.jac"), "w") as f {
        f.write(app_src);
    }
    with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
        f.write(
            f'[project]\nname = "{project_name}"\nversion = "0.1.0"\n'
            'entry-point = "main.jac"\n'
            '\n[serve]\nbase_route_app = "app"\n'
            '\n[plugins.client]\n'
        );
    }
    port = get_free_port();
    jac_cmd = get_jac_command();
    env = get_env_with_npm();
    proc = Popen(
        [*jac_cmd, "start", "main.jac", "-p", str(port)],
        cwd=tmpdir,
        stdout=PIPE,
        stderr=STDOUT,
        env=env,
    );
    wait_for_port("127.0.0.1", port, timeout=90.0);
    time.sleep(1.0);
    return (proc, port, f"http://127.0.0.1:{port}", tmpdir);
}

"""Terminate server process and remove temp dir."""
def _stop_server(proc: Any, tmpdir: str) {
    try {
        proc.terminate();
        proc.wait(timeout=10);
    } except Exception {
        proc.kill();
    }
    time.sleep(0.5);
    gc.collect();
    shutil.rmtree(tmpdir, ignore_errors=True);
}

"""Read all SSE frames from an httpx streaming response.

Returns list of (event_name, data_dict) tuples.
Stops on `event: end`. Raises RuntimeError on `event: error`.
"""
def _read_sse_frames(resp: Any) -> list {
    frames = [];
    buffer = "";
    for chunk in resp.iter_bytes() {
        buffer = buffer + chunk.decode("utf-8", errors="replace");
        while "\n\n" in buffer {
            raw = buffer[:buffer.index("\n\n")];
            buffer = buffer[buffer.index("\n\n") + 2:];
            if not raw.strip() {
                continue;
            }
            event_name = "message";
            data_lines = [];
            for line in raw.split("\n") {
                if line.startswith("event:") {
                    event_name = line[6:].strip();
                } elif line.startswith("data:") {
                    data_lines.append(line[5:].strip());
                }
            }
            data_text = "\n".join(data_lines);
            if event_name == "end" {
                return frames;
            }
            if event_name == "error" {
                try {
                    err = json.loads(data_text);
                    msg = err.get("message", data_text);
                } except Exception {
                    msg = data_text;
                }
                raise RuntimeError(f"SSE error frame: {msg}");
            }
            if data_text {
                try {
                    frames.append((event_name, json.loads(data_text)));
                } except Exception {
                    frames.append((event_name, data_text));
                }
            }
        }
    }
    return frames;
}


test "walker streaming: content-type is text/event-stream" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/count_up",
                json={"up_to": 2},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                ct = resp.headers.get("content-type", "");
                assert "text/event-stream" in ct , f"Expected SSE, got: {ct}";
            }
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "walker streaming: correct number of data frames" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/count_up",
                json={"up_to": 4},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                frames = _read_sse_frames(resp);
            }
        }
        assert len(frames) == 4 , f"Expected 4 frames, got {len(frames)}: {frames}";
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "walker streaming: frame data matches yielded dicts" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/count_up",
                json={"up_to": 3},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                frames = _read_sse_frames(resp);
            }
        }
        assert len(frames) == 3;
        for i in range(3) {
            (_, data) = frames[i];
            assert data["index"] == i , f"Frame {i}: {data}";
            assert data["value"] == f"item-{i}" , f"Frame {i}: {data}";
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "walker streaming: error mid-stream raises from error frame" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    raised = False;
    err_msg = "";
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/count_error",
                json={},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                try {
                    _ = _read_sse_frames(resp);
                } except RuntimeError as e {
                    raised = True;
                    err_msg = str(e);
                }
            }
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
    assert raised , "Expected RuntimeError from SSE error frame";
    assert "deliberate stream error" in err_msg , f"Unexpected message: {err_msg}";
}

test "plain walker: non-streaming walker returns JSON" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    try {
        with httpx.Client(timeout=30.0) as client {
            resp = client.post(
                f"{base_url}/walker/plain_report",
                json={},
                headers={"Accept": "application/json"}
            );
        }
        assert resp.status_code == 200 , f"Expected 200, got {resp.status_code}";
        ct = resp.headers.get("content-type", "");
        assert "application/json" in ct , f"Expected JSON, got: {ct}";
        body = resp.json();
        reports = body.get("data", {}).get("reports", []);
        assert len(reports) > 0 , f"Expected reports, got: {body}";
        assert reports[0].get("hello") == "world" , f"Unexpected: {reports[0]}";
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "def:pub function streaming: generator return served as SSE" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC);
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/function/stream_func",
                json={"n": 3},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                ct = resp.headers.get("content-type", "");
                assert "text/event-stream" in ct , f"Expected SSE, got: {ct}";
                frames = _read_sse_frames(resp);
            }
        }
        assert len(frames) == 3 , f"Expected 3, got {len(frames)}";
        for i in range(3) {
            (_, data) = frames[i];
            assert data["fn_index"] == i , f"Frame {i}: {data}";
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
}


test "client bundle: jacSpawnStream and useJacStream compile into bundle" {
    tmpdir = tempfile.mkdtemp();
    try {
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(_STREAM_APP_JAC);
        }
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write(
                '[project]\nname = "bundle-test"\nversion = "0.1.0"\n'
                'entry-point = "main.jac"\n'
                '\n[serve]\nbase_route_app = "app"\n'
                '\n[plugins.client]\n'
            );
        }
        jac_cmd = get_jac_command();
        env = get_env_with_npm();
        result = run(
            [*jac_cmd, "build", "main.jac"],
            cwd=tmpdir,
            capture_output=True,
            text=True,
            env=env,
            timeout=120,
        );
        assert result.returncode == 0 , (
            f"jac build failed.\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        );
        # Check the pre-minification compiled file: Vite may tree-shake or mangle
        # string literals in the final dist bundle, but the intermediate
        # .jac/client/compiled/client_runtime.js is unminified and authoritative.
        compiled_dir = Path(tmpdir) / ".jac" / "client" / "compiled";
        runtime_js = compiled_dir / "client_runtime.js";
        assert runtime_js.exists() , f"Compiled runtime not found at {runtime_js}";
        js_text = runtime_js.read_text(encoding="utf-8");
        assert "text/event-stream" in js_text , "SSE Accept header missing from compiled runtime";
        assert "useJacStream" in js_text , "useJacStream missing from compiled runtime";
        assert "jacSpawnStream" in js_text , "jacSpawnStream missing from compiled runtime";
        assert "getReader" in js_text , "ReadableStream.getReader() missing from compiled runtime";
        assert "jacCallFunctionStream" in js_text , "jacCallFunctionStream missing from compiled runtime";
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
        gc.collect();
    }
}


test "token streaming: each frame carries a token field" {
    (proc, port, base_url, tmpdir) = _start_server(_TOKEN_APP_JAC, "token-test");
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/token_stream",
                json={},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                frames = _read_sse_frames(resp);
            }
        }
        assert len(frames) == 4 , f"Expected 4 token frames, got {len(frames)}";
        for (_, data) in frames {
            assert "token" in data , f"Frame missing 'token' key: {data}";
        }
        joined = "".join([data["token"] for (_, data) in frames]);
        assert joined == "The quick brown fox" , f"Unexpected joined text: {joined!r}";
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "structured events: event type and detail fields are preserved" {
    (proc, port, base_url, tmpdir) = _start_server(_TOKEN_APP_JAC, "events-test");
    try {
        with httpx.Client(timeout=30.0) as client {
            with client.stream(
                "POST",
                f"{base_url}/walker/event_stream",
                json={},
                headers={"Accept": "text/event-stream"}
            ) as resp {
                frames = _read_sse_frames(resp);
            }
        }
        assert len(frames) == 4 , f"Expected 4 event frames, got {len(frames)}";
        types = [data["type"] for (_, data) in frames];
        assert types == ["thinking", "tool_call", "tool_done", "done"] , f"Unexpected types: {types}";
        tool_done = frames[2][1];
        assert tool_done["duration_ms"] == 42 , f"Field not preserved: {tool_done}";
    } finally {
        _stop_server(proc, tmpdir);
    }
}


test "e2e: useJacStream streams events into DOM via browser" {
    (proc, port, base_url, tmpdir) = _start_server(_STREAM_APP_JAC, "e2e-stream-test");
    try {
        with sync_playwright() as pw {
            browser = pw.chromium.launch(headless=True);
            page = browser.new_page();
            console_errors: list = [];
            page.on(
                "console",
                lambda msg: Any { if msg.type == "error" {
                    console_errors.append(msg.text);
                }}
            );
            page.goto(base_url, wait_until="load", timeout=30000);
            page.wait_for_selector("#app", timeout=20000);
            page.wait_for_selector("#start-btn", timeout=10000);
            status = page.locator("#status").inner_text();
            assert status == "idle" , f"Expected 'idle' before start, got: {status!r}";
            page.click("#start-btn");
            # Status may flash through 'streaming' → 'idle' faster than Playwright
            # can poll, so wait for items first, then assert idle.
            page.wait_for_function(
                "() => document.querySelectorAll('.event-item').length >= 4",
                timeout=15000
            );
            page.wait_for_function(
                "() => document.getElementById('status')?.textContent === 'idle'",
                timeout=5000
            );
            items = page.locator(".event-item").all();
            assert len(items) == 4 , f"Expected 4 event items, got {len(items)}";
            for i in range(4) {
                text = items[i].inner_text().strip();
                assert text == str(i) , f"Event item {i}: expected '{i}', got '{text!r}'";
            }
            error_el = page.locator("#error");
            assert not error_el.is_visible() , "Unexpected error element visible";
            assert len(console_errors) == 0 , f"Browser console errors: {console_errors}";
            browser.close();
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
}

test "e2e: token accumulation: joined text renders in DOM" {
    (proc, port, base_url, tmpdir) = _start_server(_TOKEN_E2E_APP_JAC, "token-e2e");
    try {
        with sync_playwright() as pw {
            browser = pw.chromium.launch(headless=True);
            page = browser.new_page();
            errors: list = [];
            page.on("pageerror", lambda e: Any { errors.append(str(e));});
            page.goto(base_url, timeout=20000);
            page.wait_for_selector("#app", timeout=10000);
            page.click("#go-btn");
            page.wait_for_function(
                "() => document.getElementById('status')?.textContent === 'idle'"
                "   && document.getElementById('output')?.textContent.length > 0",
                timeout=12000
            );
            output = page.locator("#output").inner_text();
            assert output == "The quick brown fox" , f"Expected joined text, got: {output!r}";
            assert len(errors) == 0 , f"Browser errors: {errors}";
            browser.close();
        }
    } finally {
        _stop_server(proc, tmpdir);
    }
}
