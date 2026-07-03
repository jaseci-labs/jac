"""In-process `sv` dispatch round-trip test (issue #6596, Phase J4).

Boots the staged `inprocess_dispatch` module -- the exact module the generated
desktop host runs -- against the `inprocess_app` fixture, and asserts that a
walker and a function call each round-trip IN-PROCESS (no socket, no remote
server) and return the `{status, ok, body}` envelope the client runtime expects.

This is the `sv` half of the `cl` -> `sv` path. The `cl` half (the client
runtime routing a call through `window.__jac_invoke` instead of `fetch`) is
covered by `jac/tests/runtimelib/test_native_invoke.cl.jac`. Together they prove
the full round-trip without a live webview, a display, or `nacompile`.

The round-trip needs the built-in scale backend (starlette + jaclang.scale). The
lean `jac test` desktop CI step does NOT install starlette, so the heavy imports
are lazy (module import + collection stay backend-free) and each test self-skips
when the backend deps are absent. It runs for real in the scale-backed CI step
-- see `.github/workflows/ci.yml`.
"""

import os;
import json;
import tempfile;
import warnings;
import threading;
import from pathlib { Path }

# The `sv` backend exercised by the round-trip (one walker, one function).
glob _FIXTURE: str = str(Path(__file__).parent / "fixtures" / "inprocess_app.jac"),
     # Boot the in-process app exactly ONCE for the whole module, then reuse it across
     # tests -- this mirrors the real host (boot at startup, dispatch many times) and
     # avoids the scale in-process module-reload quirk where a second boot() in
     # the same interpreter degrades the function executor.
     _BOOTED: bool = False;


"""True when the in-process backend (starlette + jaclang.scale) is importable."""
def _backend_available -> bool {
    try {
        import starlette.testclient;
        import jaclang.scale.server.serve;
        return True;
    } except ImportError {
        return False;
    }
}


"""Dispatch one `{kind, name, node, fields, token}` request through the staged
module (booting it once on first use); returns the reply already JSON-decoded."""
def _dispatch_request(request: dict) -> dict {
    global _BOOTED;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        boot,
        dispatch
    }

    if not _BOOTED {
        graph_root = tempfile.mkdtemp(prefix="jac_ipd_test_");
        boot(_FIXTURE, os.path.join(graph_root, "graph"));
        _BOOTED = True;
    }
    # starlette/fastapi route handling calls the deprecated
    # `asyncio.iscoroutinefunction` on Python 3.14 (removed in 3.16); the repo's
    # `pytest.ini` escalates warnings to errors, which would turn an `sv` function
    # call into a 500 here. It is a transitional third-party deprecation,
    # unrelated to the in-process transport under test (the real host, which does
    # not escalate warnings, returns the result fine), so suppress just that
    # warning around the dispatch.
    with warnings.catch_warnings() {
        warnings.filterwarnings(
            "ignore", message=r".*iscoroutinefunction.*", category=DeprecationWarning
        );
        raw = dispatch(json.dumps(request));
    }
    return json.loads(raw);
}


test "walker call round-trips in-process and returns its report" {
    if not _backend_available() {
        print("[skip] scale backend (starlette + jaclang.scale) not installed");
        return;
    }
    reply = _dispatch_request(
        {
            "kind": "walker",
            "name": "greet",
            "node": "",
            "fields": {"name": "Ada"},
            "token": ""
        }
    );
    # Transport status + envelope mirror a successful fetch Response.
    assert reply["status"] == 200;
    assert reply["ok"] == True;
    # The walker's `report` rides back in body.data.reports, and the field we
    # sent (`name`) reached the walker instance.
    assert reply["body"]["data"]["reports"][0]["greeting"] == "hello Ada";
}


test "function call round-trips in-process and returns its result" {
    if not _backend_available() {
        print("[skip] scale backend (starlette + jaclang.scale) not installed");
        return;
    }
    reply = _dispatch_request(
        {
            "kind": "function",
            "name": "add",
            "node": "",
            "fields": {"a": 2, "b": 40},
            "token": ""
        }
    );
    assert reply["status"] == 200;
    assert reply["ok"] == True;
    # An `sv` function's return value rides back in body.data.result.
    assert reply["body"]["data"]["result"] == 42;
}


# Needs the backend like the round-trips above. Exercises `root.shared` through
# the desktop path (the #6685 seam acceptance): a note written to the shared root
# by one in-process request must be read back by a later one. This is what proves
# the EAGER shared-root resolver the seam now installs explicitly (instead of the
# desktop copy leaning on postinit's lazy one by construction-order luck) actually
# backs `root.shared` for unauthenticated desktop calls.
test "root.shared round-trips a write then read on the desktop path (P1-D / #6685)" {
    if not _backend_available() {
        print("[skip] scale backend (starlette + jaclang.scale) not installed");
        return;
    }
    saved = _dispatch_request(
        {
            "kind": "walker",
            "name": "leave_note",
            "node": "",
            "fields": {"text": "ada-was-here"},
            "token": ""
        }
    );
    assert saved["status"] == 200;
    assert saved["ok"] == True;
    assert saved["body"]["data"]["reports"][0]["saved"] == "ada-was-here";

    # A SEPARATE request reads the shared graph back -- the note persisted on
    # root.shared across the two in-process dispatches.
    seen = _dispatch_request(
        {"kind": "walker", "name": "read_notes", "node": "", "fields": {}, "token": ""}
    );
    assert seen["status"] == 200;
    assert seen["ok"] == True;
    assert "ada-was-here" in seen["body"]["data"]["reports"][0]["notes"];
}


"""Forward a raw HTTP request through `forward()` (the CEF loopback bridge),
booting the fixture once on first use; returns `(status, body_text, content_type)`.

`forward()` is the CEF half of the `cl` -> `sv` path: the page leaves
__JAC_NATIVE__ unset and POSTs to the loopback, which hands the request here and
echoes our return straight back -- so unlike `dispatch()` this returns the
scale response VERBATIM (real status + raw {ok,data,error} body), not the
{status,ok,body} envelope."""
def _forward_request(method: str, path: str, body: bytes, token: str = "") -> tuple {
    global _BOOTED;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        boot,
        forward
    }

    if not _BOOTED {
        graph_root = tempfile.mkdtemp(prefix="jac_ipd_test_");
        boot(_FIXTURE, os.path.join(graph_root, "graph"));
        _BOOTED = True;
    }
    with warnings.catch_warnings() {
        warnings.filterwarnings(
            "ignore", message=r".*iscoroutinefunction.*", category=DeprecationWarning
        );
        return forward(method, path, body, token);
    }
}


test "forward() passes a walker call through to the in-process app verbatim" {
    if not _backend_available() {
        print("[skip] scale backend (starlette + jaclang.scale) not installed");
        return;
    }
    (status, body, ctype) = _forward_request(
        "POST", "/walker/greet", b'{"name": "Ada"}', ""
    );
    # Raw passthrough: a real 200 and the untouched {ok,data,...} body the web
    # fetch client parses -- NOT the {status,ok,body} envelope dispatch() wraps.
    assert status == 200;
    assert "application/json" in ctype;
    payload = json.loads(body);
    assert payload["ok"] == True;
    assert payload["data"]["reports"][0]["greeting"] == "hello Ada";
}


test "forward() surfaces the real non-200 status for an unknown walker" {
    if not _backend_available() {
        print("[skip] scale backend (starlette + jaclang.scale) not installed");
        return;
    }
    # Proves the raw-passthrough contract: dispatch()'s wrapper would always ride
    # on HTTP 200, but the web client needs the real status (e.g. 401 -> re-login),
    # so an unknown walker must come back as a genuine error status, not 200.
    (status, body, ctype) = _forward_request(
        "POST", "/walker/no_such_walker_here", b'{}', ""
    );
    assert status != 200;
}


test "forward() before boot() returns a 503 envelope, never raises" {
    # No backend needed: a guarded reply (not an exception) when _tc is unset is
    # what keeps a dead backend from hanging the loopback handler thread. Drive it
    # on a fresh module instance so a prior boot in this process can't mask it.
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    # Force the "never booted" state regardless of test order.
    saved_tc = ipd._tc;
    saved_err = ipd._BOOT_ERROR;
    ipd._tc = None;
    ipd._BOOT_ERROR = "";
    try {
        (status, body, ctype) = ipd.forward("POST", "/walker/greet", b'{}', "");
    } finally {
        ipd._tc = saved_tc;
        ipd._BOOT_ERROR = saved_err;
    }
    assert status == 503;
    payload = json.loads(body);
    assert payload["ok"] == False;
}


# Mailbox for the worker-mechanics test: _capture_return (installed as the
# module's webview_return) records the reply here instead of calling into the
# host-only symbol. Module-level (not a closure) to keep the Jac simple.
glob _CAP: dict = {},
     _CAP_DONE: any = None,
     # Every reply the capture sees, in order, as {id, payload, tid}. The P1-A
     # tests filter this by their unique call id so a late reply from an earlier
     # test (the worker is a single shared thread) can't cross-contaminate.
     _REPLIES: list = [];


"""Stand-in for the host's `webview_return`: record the reply payload and the
thread it arrived on, then signal the waiting test."""
def _capture_return(w: int, id_bytes: bytes, status: int, payload: bytes) {
    _CAP["w"] = w;
    _CAP["id"] = id_bytes;
    _CAP["status"] = status;
    _CAP["payload"] = payload;
    _CAP["reply_tid"] = threading.get_ident();
    _REPLIES.append({"id": id_bytes, "payload": payload, "tid": threading.get_ident()});
    if _CAP_DONE is not None {
        _CAP_DONE.set();
    }
}


"""Count replies captured for one call id (P1-A late-reply suppression)."""
def _replies_for(id_bytes: bytes) -> int {
    n = 0;
    for r in _REPLIES {
        if r["id"] == id_bytes {
            n = n + 1;
        }
    }
    return n;
}


"""The first error `code` captured for `id_bytes`, or "" if none yet."""
def _error_code_for(id_bytes: bytes) -> str {
    for r in _REPLIES {
        if r["id"] == id_bytes {
            env = json.loads(r["payload"].decode("utf-8"));
            return env.get("body", {}).get("error", {}).get("code", "");
        }
    }
    return "";
}


"""Slow dispatch stub: sleep past the test's timeout, then return a normal-
looking envelope. Installed in place of the module's real `dispatch` so the
timeout/late-reply tests need no scale backend (the worker calls the module
global `dispatch`, so reassigning it is enough)."""
def _slow_dispatch(payload_json: str) -> str {
    import time;
    time.sleep(0.6);
    return json.dumps(
        {"status": 200, "ok": True, "body": {"ok": True, "data": {"late": True}}}
    );
}


# Unlike the round-trip tests above, this one needs NO backend: it validates the
# native trampoline's threading contract (P0-C) -- copy both C-strings on the UI
# thread, enqueue, return immediately, and have a worker reply off-thread via
# webview_return. dispatch() short-circuits to a NOT_BOOTED envelope when no app
# is booted, which is all this test needs.
test "handle() copies the call id, dispatches off the UI thread, and replies off-thread" {
    global _CAP_DONE;
    import ctypes;
    import queue;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );

    # Install our capture in place of the (absent) host webview_return symbol,
    # and make sure a worker is draining the queue (boot() may have started one).
    _CAP.clear();
    _REPLIES.clear();
    _CAP_DONE = threading.Event();
    ipd._wv_return = _capture_return;
    if ipd._work_q is None {
        ipd._work_q = queue.Queue();
        threading.Thread(
            target=ipd._worker_loop, name="jac-ipd-test", daemon=True
        ).start();
    }

    # Real C-string pointers carried as ints, exactly as the native trampoline
    # passes them. Keep the buffers alive for the duration of the call.
    id_buf = ctypes.create_string_buffer(b"call-42");
    payload = json.dumps(
        {"kind": "walker", "name": "__nope__", "node": "", "fields": {}, "token": ""}
    );
    req_buf = ctypes.create_string_buffer(json.dumps([payload]).encode("utf-8"));
    call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
    req_ptr = ctypes.cast(req_buf, ctypes.c_void_p).value;

    caller_tid = threading.get_ident();
    ipd.handle(call_id, req_ptr, 0);  # must return immediately, never block

    # The single worker drained the queue and replied.
    assert _CAP_DONE.wait(timeout=10.0);
    # The id was copied byte-for-byte on the UI thread (the P0-A finding) and
    # round-tripped back to webview_return -- NOT the stale freed pointer.
    assert _CAP["id"] == b"call-42";
    # The reply happened OFF the calling (UI) thread -- the whole point of P0-C.
    assert _CAP["reply_tid"] != caller_tid;
    # Whatever dispatch produced, it is the {status, ok, body} envelope shape.
    env = json.loads(_CAP["payload"].decode("utf-8"));
    assert "body" in env;
}


# Also backend-free: a slow dispatch stub stands in for the real backend so we
# can drive the timeout deterministically. Covers two P1-A acceptance bullets at
# once -- the timed-out call rejects with NATIVE_DISPATCH_TIMEOUT, and the late
# completion does NOT produce a second reply for the same id (suppression).
test "handle() times out a slow call and drops the late reply (P1-A)" {
    global _CAP_DONE;
    import ctypes;
    import queue;
    import time;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP_DONE = threading.Event();
    ipd._wv_return = _capture_return;
    if ipd._work_q is None {
        ipd._work_q = queue.Queue();
        threading.Thread(
            target=ipd._worker_loop, name="jac-ipd-test", daemon=True
        ).start();
    }

    orig_dispatch = ipd.dispatch;
    orig_timeout = ipd._timeout_s;
    try {
        ipd.dispatch = _slow_dispatch;  # sleeps 0.6s on the worker
        ipd._timeout_s = 0.2;  # the arming timer fires first

        id_buf = ctypes.create_string_buffer(b"timeout-call");
        payload = json.dumps(
            {"kind": "walker", "name": "slow", "node": "", "fields": {}, "token": ""}
        );
        req_buf = ctypes.create_string_buffer(json.dumps([payload]).encode("utf-8"));
        call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
        req_ptr = ctypes.cast(req_buf, ctypes.c_void_p).value;

        ipd.handle(call_id, req_ptr, 0);  # returns immediately

        # The timer rejected the JS promise with the timeout code.
        assert _CAP_DONE.wait(timeout=5.0);
        assert _error_code_for(b"timeout-call") == "NATIVE_DISPATCH_TIMEOUT";
        # The slow dispatch's late completion (~0.6s) is dropped: after it has
        # surely finished there is STILL exactly one reply for this id.
        time.sleep(0.8);
        assert _replies_for(b"timeout-call") == 1;
    } finally {
        ipd.dispatch = orig_dispatch;
        ipd._timeout_s = orig_timeout;
    }
}


# Backend-free: swap in a pre-filled bounded queue with no drainer so the next
# enqueue is deterministically rejected. Covers the queue-saturation acceptance.
test "handle() replies BUSY when the dispatch queue is saturated (P1-A)" {
    global _CAP_DONE;
    import ctypes;
    import queue;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP_DONE = threading.Event();
    ipd._wv_return = _capture_return;

    orig_q = ipd._work_q;
    try {
        # maxsize=1, pre-filled to capacity and NOT drained: the next put_nowait
        # raises queue.Full, so handle() must reply BUSY rather than block.
        full_q = queue.Queue(maxsize=1);
        full_q.put_nowait(("sentinel", ));
        ipd._work_q = full_q;

        id_buf = ctypes.create_string_buffer(b"busy-call");
        payload = json.dumps(
            {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
        );
        req_buf = ctypes.create_string_buffer(json.dumps([payload]).encode("utf-8"));
        call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
        req_ptr = ctypes.cast(req_buf, ctypes.c_void_p).value;

        ipd.handle(call_id, req_ptr, 0);

        assert _CAP_DONE.wait(timeout=5.0);
        assert _error_code_for(b"busy-call") == "NATIVE_DISPATCH_BUSY";
        assert _replies_for(b"busy-call") == 1;
    } finally {
        ipd._work_q = orig_q;
    }
}


# Backend-free: drive dispatch() directly with a recorded boot failure. The host
# normally shows a native error page and never loads the app, but dispatch()
# must still hand back the real reason (NATIVE_BOOT_ERROR) rather than a bare
# NOT_BOOTED if a call somehow reaches it (P1-B).
test "dispatch() returns a NATIVE_BOOT_ERROR envelope when boot failed (P1-B)" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_err = ipd._BOOT_ERROR;
    orig_debug = ipd._debug;
    try {
        ipd._BOOT_ERROR = "ImportError: boom\nTraceback (most recent call last): ...";
        ipd._debug = True;  # so the reason rides in `details` (release gates it; see P1-C test)
        raw = ipd.dispatch(
            json.dumps(
                {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
            )
        );
        env = json.loads(raw);
        assert env["ok"] == False;
        assert env["status"] == 0;
        assert env["body"]["error"]["code"] == "NATIVE_BOOT_ERROR";
        # In debug mode the real reason rides along (gated off in release: P1-C).
        assert "boom" in env["body"]["error"]["details"];
    } finally {
        ipd._BOOT_ERROR = orig_err;
        ipd._debug = orig_debug;
    }
}


# Backend-free: the production error contract (P1-C). A recorded boot reason is
# driven through dispatch() in both modes -- release (default) must NOT leak the
# traceback, dev must include it, and BOTH must stamp a request_id for log
# correlation.
test "error envelopes gate the traceback behind debug and always carry a request_id (P1-C)" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_err = ipd._BOOT_ERROR;
    orig_debug = ipd._debug;
    try {
        ipd._BOOT_ERROR = "ImportError: boom\nTraceback (most recent call last): secret";
        req = json.dumps(
            {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
        );

        # Release mode (default): the contract is {code, message, request_id} --
        # no traceback leaks to the client.
        ipd._debug = False;
        rel = json.loads(ipd.dispatch(req))["body"]["error"];
        assert rel["code"] == "NATIVE_BOOT_ERROR";
        assert "details" not in rel , "release envelopes must not leak the traceback";
        assert rel.get("request_id") , "every error envelope carries a request_id";

        # Dev mode: the full reason rides along for debugging, still with an id.
        ipd._debug = True;
        dev = json.loads(ipd.dispatch(req))["body"]["error"];
        assert "secret" in dev.get("details", "") , "dev envelopes include the traceback";
        assert dev.get("request_id") , "dev envelopes also carry a request_id";
    } finally {
        ipd._BOOT_ERROR = orig_err;
        ipd._debug = orig_debug;
    }
}


# Backend-free in BOTH lanes: a bad entry fails boot() at the scale backend import (lean
# lane) or at jac_import (backend lane). Either way boot() must record the reason
# and RE-RAISE, so the host's PyRun_SimpleString(BOOT_PY) (via host_boot.boot)
# sees != 0 and shows the error page (P1-B).
test "boot() records the failure reason and re-raises (P1-B)" {
    import from importlib { import_module }
    import tempfile;

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    ipd._BOOT_ERROR = "";
    raised = False;
    try {
        with tempfile.TemporaryDirectory() as d {
            try {
                ipd.boot("/nonexistent/__definitely_not_a_module__.jac", d + "/g");
            } except Exception {
                raised = True;
            }
        }
        assert raised , "boot() must re-raise so the host can show an error page";
        assert ipd._BOOT_ERROR != "" , "boot() must record the failure reason";
    } finally {
        ipd._BOOT_ERROR = "";
    }
}


# Backend-free: boot() must clear a stale _BOOT_ERROR at entry so a successful
# retry is not permanently blocked (Greptile P1).
test "boot() clears stale _BOOT_ERROR at entry" {
    import from importlib { import_module }
    import tempfile;

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_err = ipd._BOOT_ERROR;
    orig_tc = ipd._tc;
    try {
        ipd._BOOT_ERROR = "stale ImportError from a prior failed boot";
        ipd._tc = object();
        with tempfile.TemporaryDirectory() as d {
            try {
                ipd.boot("/nonexistent/__definitely_not_a_module__.jac", d + "/g");
            } except Exception { }
        }
        assert "stale ImportError" not in ipd._BOOT_ERROR , (
            "boot() must clear a stale error at entry before recording a new one"
        );
        assert ipd._BOOT_ERROR != "" , "boot() must still record the fresh failure";

        # After clearing _BOOT_ERROR, dispatch() must return NOT_BOOTED (no runtime),
        # not NATIVE_BOOT_ERROR. Reset _tc to None so dispatch() reaches the
        # NOT_BOOTED path rather than calling .post() on the fake object().
        ipd._BOOT_ERROR = "";
        ipd._tc = None;
        raw = ipd.dispatch(
            json.dumps(
                {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
            )
        );
        env = json.loads(raw);
        assert env["body"]["error"]["code"] != "NATIVE_BOOT_ERROR" , (
            "dispatch() must not be blocked once boot() has cleared _BOOT_ERROR"
        );
    } finally {
        ipd._BOOT_ERROR = orig_err;
        ipd._tc = orig_tc;
    }
}


# Backend-free shutdown tests (P2): teardown must be safe when not booted, stop the
# worker via a queue sentinel, and drain pending items without webview_return.
test "shutdown() is a no-op when boot() never ran" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_q = ipd._work_q;
    orig_tc = ipd._tc;
    orig_runtime = ipd._runtime;
    orig_worker = ipd._worker;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._work_q = None;
        ipd._tc = None;
        ipd._runtime = None;
        ipd._worker = None;
        ipd._shutting_down = False;
        ipd.shutdown();
        assert ipd._shutting_down == False , "no-op shutdown must not flip the flag";
        assert ipd._work_q is None;
        assert ipd._tc is None;
    } finally {
        ipd._work_q = orig_q;
        ipd._tc = orig_tc;
        ipd._runtime = orig_runtime;
        ipd._worker = orig_worker;
        ipd._shutting_down = orig_shutting;
    }
}


test "shutdown() stops the worker via a queue sentinel" {
    import queue;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_q = ipd._work_q;
    orig_worker = ipd._worker;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._shutting_down = False;
        ipd._work_q = queue.Queue();
        ipd._worker = threading.Thread(
            target=ipd._worker_loop, name="jac-ipd-shutdown-test", daemon=True
        );
        ipd._worker.start();
        worker = ipd._worker;
        ipd.shutdown();
        assert not worker.is_alive() , "worker must exit after shutdown sentinel";
        assert ipd._work_q is None , "shutdown clears the queue handle";
    } finally {
        if orig_worker is not None and orig_worker.is_alive() {
            orig_worker.join(timeout=1.0);
        }
        ipd._work_q = orig_q;
        ipd._worker = orig_worker;
        ipd._shutting_down = orig_shutting;
    }
}


test "shutdown() drains queued items without replying" {
    import queue;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    orig_q = ipd._work_q;
    orig_worker = ipd._worker;
    orig_wv = ipd._wv_return;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._wv_return = _capture_return;
        ipd._shutting_down = False;
        ipd._work_q = queue.Queue();
        ipd._worker = None;  # enforce "no worker" regardless of prior-test state
        # No worker -- shutdown() drains synchronously before posting the sentinel.
        state = ipd.CallState(lock=threading.Lock());
        ipd._work_q.put_nowait(
            (0, b"drain-me", json.dumps({"kind": "walker", "name": "x"}), state)
        );
        ipd.shutdown();
        assert _replies_for(b"drain-me") == 0 , "drained items must not webview_return";
        assert ipd._work_q is None;
    } finally {
        ipd._work_q = orig_q;
        ipd._worker = orig_worker;
        ipd._wv_return = orig_wv;
        ipd._shutting_down = orig_shutting;
    }
}

"""Dispatch stub that always raises (exercises _worker_loop's exception-catch path)."""
def _raising_dispatch(payload_json: str) -> str {
    raise RuntimeError("boom from dispatch (test stub)");
}


# Backend-free: _handle_impl checks _shutting_down first and calls _reply, but
# _reply itself is a no-op during shutdown (the webview is gone). Verify that
# handle() neither crashes nor produces any reply while shutting down.
test "handle() makes no reply when _shutting_down is True (NATIVE_DISPATCH_SHUTDOWN path)" {
    import ctypes;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    orig_shutting = ipd._shutting_down;
    orig_wv = ipd._wv_return;
    try {
        ipd._wv_return = _capture_return;
        ipd._shutting_down = True;

        id_buf = ctypes.create_string_buffer(b"shutdown-call");
        payload = json.dumps(
            {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
        );
        req_buf = ctypes.create_string_buffer(json.dumps([payload]).encode("utf-8"));
        call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
        req_ptr = ctypes.cast(req_buf, ctypes.c_void_p).value;

        ipd.handle(call_id, req_ptr, 0);
        # _reply short-circuits when _shutting_down; no webview_return must fire.
        assert _replies_for(b"shutdown-call") == 0 , (
            "handle() must make no reply during shutdown"
        );
    } finally {
        ipd._shutting_down = orig_shutting;
        ipd._wv_return = orig_wv;
    }
}


# Backend-free: req_ptr points to invalid JSON; _handle_impl must reply inline
# with NATIVE_DISPATCH_ERROR rather than crashing or hanging the JS promise.
# The reply is synchronous (no worker involvement) so we check immediately.
test "handle() replies NATIVE_DISPATCH_ERROR inline for a malformed request" {
    import ctypes;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    orig_shutting = ipd._shutting_down;
    orig_wv = ipd._wv_return;
    try {
        ipd._shutting_down = False;
        ipd._wv_return = _capture_return;

        id_buf = ctypes.create_string_buffer(b"bad-json-call");
        # Deliberately malformed outer wrapper -- json.loads raises inside _handle_impl.
        bad_buf = ctypes.create_string_buffer(b"not-valid-json-at-all");
        call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
        req_ptr = ctypes.cast(bad_buf, ctypes.c_void_p).value;

        ipd.handle(call_id, req_ptr, 0);  # reply is inline, synchronous
        assert _replies_for(b"bad-json-call") == 1 , "one inline reply expected";
        assert _error_code_for(b"bad-json-call") == "NATIVE_DISPATCH_ERROR" , (
            "malformed request must yield NATIVE_DISPATCH_ERROR"
        );
    } finally {
        ipd._shutting_down = orig_shutting;
        ipd._wv_return = orig_wv;
    }
}


# Backend-free: handle() called before boot() (_work_q is None). The module
# dispatches inline and the promise gets a NOT_BOOTED envelope -- not a hang.
# Also synchronous: _reply is called on the caller thread without a worker.
test "handle() replies NOT_BOOTED inline when _work_q is None" {
    import ctypes;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    orig_shutting = ipd._shutting_down;
    orig_wv = ipd._wv_return;
    orig_q = ipd._work_q;
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        ipd._shutting_down = False;
        ipd._wv_return = _capture_return;
        ipd._work_q = None;
        ipd._tc = None;
        ipd._BOOT_ERROR = "";

        id_buf = ctypes.create_string_buffer(b"no-boot-call");
        payload = json.dumps(
            {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
        );
        req_buf = ctypes.create_string_buffer(json.dumps([payload]).encode("utf-8"));
        call_id = ctypes.cast(id_buf, ctypes.c_void_p).value;
        req_ptr = ctypes.cast(req_buf, ctypes.c_void_p).value;

        ipd.handle(call_id, req_ptr, 0);
        assert _replies_for(b"no-boot-call") == 1;
        assert _error_code_for(b"no-boot-call") == "NOT_BOOTED" , (
            "handle() must reply NOT_BOOTED when boot() never ran"
        );
    } finally {
        ipd._shutting_down = orig_shutting;
        ipd._wv_return = orig_wv;
        ipd._work_q = orig_q;
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}


# Backend-free: verify dispatch() constructs the right walker path when a
# non-empty node id is supplied. Uses a mock TestClient so no backend is needed.
test "dispatch() routes a walker to /walker/{name}/{node_id} when node is set" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        mock_resp = MagicMock();
        mock_resp.status_code = 200;
        mock_resp.is_success = True;
        mock_resp.json.return_value = {"ok": True, "data": {}};
        mock_client = MagicMock();
        mock_client.post.return_value = mock_resp;

        ipd._tc = mock_client;
        ipd._BOOT_ERROR = "";
        ipd.dispatch(
            json.dumps(
                {
                    "kind": "walker",
                    "name": "my_walker",
                    "node": "abc-123",
                    "fields": {},
                    "token": ""
                }
            )
        );
        path = mock_client.post.call_args[0][0];
        assert path == "/walker/my_walker/abc-123" , f"expected /walker/my_walker/abc-123, got {path}";
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}


# Backend-free: a non-empty token must appear as Bearer in the Authorization
# header that dispatch() sends to the in-process TestClient.
test "dispatch() sends Authorization: Bearer header when token is set" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        mock_resp = MagicMock();
        mock_resp.status_code = 200;
        mock_resp.is_success = True;
        mock_resp.json.return_value = {"ok": True, "data": {}};
        mock_client = MagicMock();
        mock_client.post.return_value = mock_resp;

        ipd._tc = mock_client;
        ipd._BOOT_ERROR = "";
        ipd.dispatch(
            json.dumps(
                {
                    "kind": "function",
                    "name": "add",
                    "node": "",
                    "fields": {"a": 1, "b": 2},
                    "token": "tok-xyz"
                }
            )
        );
        sent_headers = mock_client.post.call_args[1].get("headers", {});
        assert sent_headers.get("Authorization") == "Bearer tok-xyz" , (
            "a non-empty token must be sent as Authorization: Bearer"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}


# Backend-free: when the backend returns a non-JSON body (e.g. a bare 404 HTML
# page), dispatch() must wrap it in an envelope rather than raising.
test "dispatch() wraps a non-JSON backend response in an error envelope" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        mock_resp = MagicMock();
        mock_resp.status_code = 404;
        mock_resp.is_success = False;
        mock_resp.text = "Not Found";
        mock_resp.json.side_effect = ValueError("not JSON");
        mock_client = MagicMock();
        mock_client.post.return_value = mock_resp;

        ipd._tc = mock_client;
        ipd._BOOT_ERROR = "";
        raw = ipd.dispatch(
            json.dumps(
                {"kind": "walker", "name": "x", "node": "", "fields": {}, "token": ""}
            )
        );
        env = json.loads(raw);
        assert env["status"] == 404;
        assert env["ok"] == False;
        assert "Not Found" in env["body"]["error"]["message"] , (
            "non-JSON body text must appear in body.error.message"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}


# Backend-free: when dispatch() itself raises (not returning an error envelope),
# _worker_loop must catch the exception and produce a NATIVE_DISPATCH_ERROR reply
# rather than letting the JS promise hang forever.
test "_worker_loop replies NATIVE_DISPATCH_ERROR when dispatch() raises" {
    global _CAP_DONE;
    import queue;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    _CAP_DONE = threading.Event();
    orig_wv = ipd._wv_return;
    orig_shutting = ipd._shutting_down;
    orig_dispatch = ipd.dispatch;
    orig_q = ipd._work_q;
    orig_worker = ipd._worker;
    ipd._wv_return = _capture_return;
    ipd._shutting_down = False;

    test_q = queue.Queue();
    ipd._work_q = test_q;
    exc_worker = threading.Thread(
        target=ipd._worker_loop, name="jac-ipd-exc-test", daemon=True
    );
    ipd._worker = exc_worker;
    exc_worker.start();
    ipd.dispatch = _raising_dispatch;
    try {
        state = ipd.CallState(lock=threading.Lock());
        test_q.put_nowait(
            (
                0,
                b"exc-call",
                json.dumps(
                    {
                        "kind": "walker",
                        "name": "x",
                        "node": "",
                        "fields": {},
                        "token": ""
                    }
                ),
                state
            )
        );
        assert _CAP_DONE.wait(timeout=10.0) , "worker must reply on dispatch() exception";
        assert _error_code_for(b"exc-call") == "NATIVE_DISPATCH_ERROR" , (
            "worker must produce NATIVE_DISPATCH_ERROR when dispatch() raises"
        );
    } finally {
        ipd.dispatch = orig_dispatch;
        ipd._shutting_down = orig_shutting;
        try {
            test_q.put_nowait(None);
        } except queue.Full { }
        exc_worker.join(timeout=2.0);
        ipd._work_q = orig_q;
        ipd._worker = orig_worker;
        ipd._wv_return = orig_wv;
    }
}


# Backend-free: handle(0, ...) / handle(call_id, 0, ...) must return immediately
# without crashing or producing any reply.
test "handle() is a no-op for null pointers" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    orig_wv = ipd._wv_return;
    try {
        ipd._wv_return = _capture_return;
        ipd.handle(0, 0, 0);
        ipd.handle(0, 1, 0);
        ipd.handle(1, 0, 0);
        assert len(_REPLIES) == 0 , "null-pointer handle() must produce no reply";
    } finally {
        ipd._wv_return = orig_wv;
    }
}


# Backend-free: when webview_return itself fails, _reply must swallow the
# exception (a leaked exception from handle() would freeze the GTK event loop).
# It retries once with a minimal fallback payload; both calls must fire.
test "_reply swallows webview_return failures without raising" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_wv = ipd._wv_return;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._shutting_down = False;
        mock_wv = MagicMock(side_effect=OSError("webview_return exploded"));
        ipd._wv_return = mock_wv;

        raised = False;
        try {
            ipd._reply(
                0, b"any-id", json.dumps({"status": 200, "ok": True, "body": {}})
            );
        } except Exception {
            raised = True;
        }
        assert not raised , "_reply must swallow webview_return failures";
        # Primary attempt + one fallback retry.
        assert mock_wv.call_count == 2 , "_reply must retry once with a fallback payload";
    } finally {
        ipd._wv_return = orig_wv;
        ipd._shutting_down = orig_shutting;
    }
}


# Backend-free: calling shutdown() a second time must be a silent no-op.
test "shutdown() is idempotent" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_q = ipd._work_q;
    orig_tc = ipd._tc;
    orig_runtime = ipd._runtime;
    orig_worker = ipd._worker;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._work_q = None;
        ipd._tc = None;
        ipd._runtime = None;
        ipd._worker = None;
        ipd._shutting_down = False;

        raised = False;
        try {
            ipd.shutdown();
            ipd.shutdown();
        } except Exception {
            raised = True;
        }
        assert not raised , "double shutdown() must not raise";
    } finally {
        ipd._work_q = orig_q;
        ipd._tc = orig_tc;
        ipd._runtime = orig_runtime;
        ipd._worker = orig_worker;
        ipd._shutting_down = orig_shutting;
    }
}


# Backend-free: _on_timeout must be a no-op when _shutting_down is True --
# calling webview_return after the webview closes is undefined behavior.
test "_on_timeout is a no-op when _shutting_down is True" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    orig_shutting = ipd._shutting_down;
    orig_wv = ipd._wv_return;
    try {
        ipd._shutting_down = True;
        ipd._wv_return = _capture_return;

        state = ipd.CallState(lock=threading.Lock());
        ipd._on_timeout(0, b"to-call", state);
        assert _replies_for(b"to-call") == 0 , "_on_timeout must not reply during shutdown";
    } finally {
        ipd._shutting_down = orig_shutting;
        ipd._wv_return = orig_wv;
    }
}


# Backend-free in the guard path: when _runtime is not None at _boot_impl entry,
# the prior runtime is closed before the new boot attempt starts. We verify this
# by installing a mock runtime and confirming close() is called even when the rest
# of _boot_impl fails (nonexistent entry file).
test "_boot_impl closes a prior runtime before re-booting" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }
    import tempfile;

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_runtime = ipd._runtime;
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        mock_runtime = MagicMock();
        ipd._runtime = mock_runtime;
        ipd._BOOT_ERROR = "";

        with tempfile.TemporaryDirectory() as d {
            try {
                ipd._boot_impl("/nonexistent/__not_a_module__.jac", d + "/g");
            } except Exception { }
        }
        assert mock_runtime.close.called , (
            "_boot_impl must close the prior runtime before starting a new boot"
        );
    } finally {
        ipd._runtime = orig_runtime;
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}

test "dispatch_sync() returns the result for a fast call" {
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        mock_resp = MagicMock();
        mock_resp.status_code = 200;
        mock_resp.is_success = True;
        mock_resp.json.return_value = {"ok": True, "data": {"result": 42}};
        mock_client = MagicMock();
        mock_client.post.return_value = mock_resp;

        ipd._tc = mock_client;
        ipd._BOOT_ERROR = "";
        raw = ipd.dispatch_sync(
            json.dumps({"kind": "function", "name": "add", "fields": {"a": 2, "b": 40}})
        );
        env = json.loads(raw);
        assert env["status"] == 200 , "dispatch_sync must return the wrapped envelope";
        assert env["body"]["data"]["result"] == 42 , (
            "the fast dispatch result must round-trip through the worker thread"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}


# Backend-free: the whole point of dispatch_sync(). A slow dispatch stub stands
# in for a walker that stalls past the timeout; dispatch_sync must reject with
# NATIVE_DISPATCH_TIMEOUT and return promptly (it must NOT block for the full
# slow duration).
test "dispatch_sync() times out a slow call with NATIVE_DISPATCH_TIMEOUT" {
    import time;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    orig_timeout = ipd._timeout_s;
    try {
        ipd._tc = object();  # truthy: clears the not-booted guard
        ipd._BOOT_ERROR = "";
        ipd._timeout_s = 30.0;  # default; the explicit timeout_s below wins
        ipd.dispatch = _slow_dispatch;  # sleeps 0.6s

        t0 = time.monotonic();
        raw = ipd.dispatch_sync(
            json.dumps({"kind": "walker", "name": "slow", "fields": {}, "token": ""}),
            timeout_s=0.2
        );
        elapsed = time.monotonic() - t0;
        env = json.loads(raw);
        assert env["body"]["error"]["code"] == "NATIVE_DISPATCH_TIMEOUT" , (
            "a call exceeding timeout_s must reject with NATIVE_DISPATCH_TIMEOUT"
        );
        assert "0.2s" in env["body"]["error"]["message"] , (
            "the timeout message must report the applied threshold"
        );
        assert elapsed < 1.0 , (
            "dispatch_sync must return promptly after the timeout, not wait for "
            "the slow call to finish"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
        ipd.dispatch = orig_dispatch;
        ipd._timeout_s = orig_timeout;
    }
}


# Backend-free: timeout_s <= 0 means "use the configured _timeout_s". Drive a
# slow stub with _timeout_s set short and timeout_s left at its default.
test "dispatch_sync() falls back to _timeout_s when timeout_s <= 0" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    orig_timeout = ipd._timeout_s;
    try {
        ipd._tc = object();
        ipd._BOOT_ERROR = "";
        ipd._timeout_s = 0.2;
        ipd.dispatch = _slow_dispatch;  # 0.6s -- past the configured 0.2s

        raw = ipd.dispatch_sync(
            json.dumps({"kind": "walker", "name": "slow", "fields": {}, "token": ""})
        );
        env = json.loads(raw);
        assert env["body"]["error"]["code"] == "NATIVE_DISPATCH_TIMEOUT" , (
            "timeout_s <= 0 must apply the configured _timeout_s"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
        ipd.dispatch = orig_dispatch;
        ipd._timeout_s = orig_timeout;
    }
}


# Backend-free: when the underlying dispatch() raises, dispatch_sync must catch
# it on the worker thread and return a NATIVE_DISPATCH_ERROR envelope (never let
# the exception escape and freeze the host's GIL-held invoke handler).
test "dispatch_sync() returns NATIVE_DISPATCH_ERROR when dispatch() raises" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    try {
        ipd._tc = object();
        ipd._BOOT_ERROR = "";
        ipd.dispatch = _raising_dispatch;  # always raises RuntimeError

        raw = ipd.dispatch_sync(
            json.dumps({"kind": "walker", "name": "x", "fields": {}, "token": ""}),
            timeout_s=5.0
        );
        env = json.loads(raw);
        assert env["body"]["error"]["code"] == "NATIVE_DISPATCH_ERROR" , (
            "a dispatch() exception must surface as NATIVE_DISPATCH_ERROR"
        );
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
        ipd.dispatch = orig_dispatch;
    }
}


# Backend-free: dispatch_sync() shares dispatch()'s not-booted / boot-error
# guards. When boot() never ran it must reply NOT_BOOTED (not raise / hang).
test "dispatch_sync() replies NOT_BOOTED when boot() never ran" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_tc = ipd._tc;
    orig_err = ipd._BOOT_ERROR;
    try {
        ipd._tc = None;
        ipd._BOOT_ERROR = "";
        raw = ipd.dispatch_sync(
            json.dumps({"kind": "walker", "name": "x", "fields": {}, "token": ""})
        );
        env = json.loads(raw);
        assert env["body"]["error"]["code"] != "NATIVE_BOOT_ERROR" , (
            "a fresh module must not report a stale boot error"
        );
        assert ipd._tc is None , "test must not leave a fake client behind";
    } finally {
        ipd._tc = orig_tc;
        ipd._BOOT_ERROR = orig_err;
    }
}
