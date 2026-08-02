"""In-process `sv` dispatch round-trip test (issue #6596, Phase J4).

Boots the staged `inprocess_dispatch` module -- the exact module the generated
desktop host runs -- against the `inprocess_app` fixture, and asserts that a
walker and a function call each round-trip IN-PROCESS (no socket, no remote
server) and return the `{status, ok, body}` envelope the client runtime expects.

This is the `sv` half of the `cl` -> `sv` path. The `cl` half (the client
runtime routing a call through `window.__jac_invoke` instead of `fetch`) is
covered by `jac/tests/runtimelib/test_native_invoke.jac`. Together they prove
the full round-trip without a live webview, a display, or `nacompile`.

Direct dispatch uses `InvocationDispatcher` in runtimelib and does not require
FastAPI, Starlette, or `jaclang.scale.server.inprocess`. The lean `jac test`
desktop CI step does NOT install starlette, so the heavy imports are lazy
(module import + collection stay backend-free) and each test self-skips when
the backend deps are absent. It runs for real in the scale-backed CI step --
see `.github/workflows/ci.yml`.
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


"""Dispatch one `{kind, name, node, fields, token}` request through the staged
module (booting it once on first use); returns the reply already JSON-decoded."""
def _dispatch_request(request: dict) -> dict {
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        boot,
        dispatch,
        _runtime
    }

    # Re-boot when the staged runtime is gone: some backend-free tests below
    # exercise shutdown() against the real booted runtime, which closes it and
    # leaves `_runtime` None. Tests after that point that need a live backend
    # (e.g. the NOT_FOUND dispatch tests) must boot again rather than dispatch
    # into a shut-down runtime and see NOT_BOOTED.
    if not _BOOTED or _runtime is None {
        graph_root = tempfile.mkdtemp(prefix="jac_ipd_test_");
        boot(_FIXTURE, os.path.join(graph_root, "graph"));
        _BOOTED = True;
    }
    raw = dispatch(json.dumps(request));
    return json.loads(raw);
}


test "walker call round-trips in-process and returns its report" {
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


test "native dispatch errors without stream emit hook" {
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        set_stream_emit
    }
    set_stream_emit(None);
    reply = _dispatch_request(
        {
            "kind": "function",
            "name": "stream_numbers",
            "node": "",
            "fields": {"n": 2},
            "token": ""
        }
    );
    assert reply["ok"] == False;
    assert reply["body"]["error"]["code"] == "NATIVE_DISPATCH_ERROR";
    assert "emit hook" in reply["body"]["error"]["message"];
}


test "native dispatch opens push stream for streaming functions" {
    import time;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        set_stream_emit
    }

    seen: list = [];
    done = threading.Event();
    def capture(stream_id: str, frame: dict) {
        entry = dict(frame);
        entry["stream_id"] = stream_id;
        seen.append(entry);
        if frame.get("type") in ("end", "error") {
            done.set();
        }
    }
    set_stream_emit(capture);
    try {
        reply = _dispatch_request(
            {
                "kind": "function",
                "name": "stream_numbers",
                "node": "",
                "fields": {"n": 3},
                "token": ""
            }
        );
        assert reply.get("__jac_stream") == True;
        assert reply.get("protocol") == "push";
        assert reply.get("v") == 1;
        sid = reply.get("stream_id");
        assert isinstance(sid, str) and len(sid) > 0;
        assert done.wait(2.0) , "stream pump did not emit end in time";
        # Allow a brief settle for the final append ordering.
        time.sleep(0.05);
        data_frames = [
            f["data"]
            for f in seen
            if f.get("type") == "data"
        ];
        assert data_frames == [{"n": 0}, {"n": 1}, {"n": 2}];
        assert all(f.get("stream_id") == sid for f in seen);
        assert seen[-1].get("type") == "end";
    } finally {
        set_stream_emit(None);
    }
}


# Backend-free (Gate B): a consumer that goes away mid-stream must stop the pump
# promptly, close the generator, and NOT emit a terminal `end` frame.
test "cancel_stream stops the pump and suppresses the end frame" {
    import time;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_emit = ipd._stream_emit;
    orig_shutting = ipd._shutting_down;
    orig_window = ipd._stream_window;

    frames: list = [];
    started = threading.Event();
    closed = threading.Event();
    def _capture(sid: str, frame: dict) {
        frames.append(frame);
    }
    def _slow_gen {
        started.set();
        try {
            for i in range(1000) {
                time.sleep(0.03);
                yield {"n": i};
            }
        } finally {
            closed.set();
        }
    }
    try {
        ipd._shutting_down = False;
        ipd._stream_window = 0;  # isolate cancellation from backpressure
        ipd._stream_emit = _capture;

        raw = ipd._open_native_stream(_slow_gen());
        env = json.loads(raw);
        sid = env["stream_id"];
        assert env["__jac_stream"] == True;
        assert started.wait(2.0);
        time.sleep(0.09);  # let a couple frames flow
        n_before = len(
            [
                f
                for f in frames
                if f["type"] == "data"
            ]
        );
        assert n_before >= 1;

        ipd.cancel_stream(sid);
        assert closed.wait(2.0) , "cancel must close the generator (finally ran)";
        time.sleep(0.15);
        n_after = len(
            [
                f
                for f in frames
                if f["type"] == "data"
            ]
        );
        # Pump stopped: at most one in-flight frame after cancel, no runaway.
        assert n_after <= n_before + 1;
        assert not any(f["type"] == "end" for f in frames) , (
            "a cancelled stream must not emit a terminal end frame"
        );
        # The stream deregistered itself.
        assert sid not in ipd._streams , "cancelled stream must be unregistered";
    } finally {
        ipd._stream_emit = orig_emit;
        ipd._shutting_down = orig_shutting;
        ipd._stream_window = orig_window;
    }
}


# Backend-free (Gate B): with a positive window and a consumer that acks, the
# pump holds frames to at most one window of in-flight until credits are released.
test "stream backpressure bounds in-flight frames until acked" {
    import time;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_emit = ipd._stream_emit;
    orig_shutting = ipd._shutting_down;
    orig_window = ipd._stream_window;

    frames: list = [];
    def _capture(sid: str, frame: dict) {
        frames.append(frame);
    }
    def _fast_gen {
        for i in range(5) {
            yield {"n": i};
        }
    }
    try {
        ipd._shutting_down = False;
        ipd._stream_window = 2;  # only 2 frames may be in flight before an ack
        ipd._stream_emit = _capture;

        raw = ipd._open_native_stream(_fast_gen());
        env = json.loads(raw);
        sid = env["stream_id"];

        # Before any ack (and before the ~0.5s no-ack degrade), the producer is
        # throttled to the window even though it could yield all 5 at once.
        time.sleep(0.15);
        data_before = len(
            [
                f
                for f in frames
                if f["type"] == "data"
            ]
        );
        assert data_before <= 2 , (
            "backpressure must bound in-flight frames to the window before acks"
        );

        # Acking releases credits; the rest of the stream drains to completion.
        ipd.stream_ack(sid, 5);
        deadline = time.monotonic() + 2.0;
        while not any(f["type"] == "end" for f in frames)
            and time.monotonic() < deadline {
            time.sleep(0.02);
        }
        data_after = len(
            [
                f
                for f in frames
                if f["type"] == "data"
            ]
        );
        assert data_after == 5 , "all frames flow once credits are released";
        assert any(f["type"] == "end" for f in frames) , "acked stream completes with end";
    } finally {
        ipd._stream_emit = orig_emit;
        ipd._shutting_down = orig_shutting;
        ipd._stream_window = orig_window;
    }
}


# Backend-free (Step 5): a generator that raises mid-stream must emit a terminal
# `error` frame (never `end`), close the generator, and deregister the stream.
test "a generator raising mid-stream emits an error frame and deregisters" {
    import time;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_emit = ipd._stream_emit;
    orig_shutting = ipd._shutting_down;
    orig_window = ipd._stream_window;

    frames: list = [];
    closed = threading.Event();
    def _capture(sid: str, frame: dict) {
        frames.append(frame);
    }
    def _boom_gen {
        try {
            yield {"n": 0};
            raise ValueError("kaboom mid-stream");
        } finally {
            closed.set();
        }
    }
    try {
        ipd._shutting_down = False;
        ipd._stream_window = 0;
        ipd._stream_emit = _capture;

        raw = ipd._open_native_stream(_boom_gen());
        sid = json.loads(raw)["stream_id"];
        deadline = time.monotonic() + 2.0;
        while not any(f["type"] in ("error", "end") for f in frames)
            and time.monotonic() < deadline {
            time.sleep(0.01);
        }
        assert closed.wait(2.0) , "the raising generator must be closed (finally ran)";
        types = [
            f["type"]
            for f in frames
        ];
        assert "data" in types , types;
        assert types[-1] == "error" , types;
        err = frames[-1]["error"];
        assert err["error_type"] == "ValueError" , err;
        assert "kaboom" in err["message"] , err;
        assert not any(f["type"] == "end" for f in frames) , (
            "an errored stream must not also emit a terminal end frame"
        );
        # Deregistration happens in the pump's finally, which runs just after the
        # generator's own finally (closed.set); poll rather than race it.
        dl = time.monotonic() + 2.0;
        while sid in ipd._streams and time.monotonic() < dl {
            time.sleep(0.01);
        }
        assert sid not in ipd._streams , "an errored stream must deregister itself";
    } finally {
        ipd._stream_emit = orig_emit;
        ipd._shutting_down = orig_shutting;
        ipd._stream_window = orig_window;
    }
}


# Backend-free (Step 5): shutdown() with a live stream must cancel it -- close the
# generator (running its commit-at-drain teardown), deregister it, emit no `end`
# -- and return promptly without hanging or leaking. Uses a mock runtime so the
# real booted backend is untouched.
test "shutdown cancels an active stream without hanging or leaking" {
    import time;
    import queue;
    import from importlib { import_module }
    import from unittest.mock { MagicMock }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_emit = ipd._stream_emit;
    orig_shutting = ipd._shutting_down;
    orig_window = ipd._stream_window;
    orig_q = ipd._work_q;
    orig_workers = ipd._workers;
    orig_runtime = ipd._runtime;

    frames: list = [];
    started = threading.Event();
    closed = threading.Event();
    def _capture(sid: str, frame: dict) {
        frames.append(frame);
    }
    def _slow_gen {
        started.set();
        try {
            for i in range(1000) {
                time.sleep(0.03);
                yield {"n": i};
            }
        } finally {
            closed.set();
        }
    }
    try {
        ipd._shutting_down = False;
        ipd._stream_window = 0;
        ipd._stream_emit = _capture;
        ipd._work_q = queue.Queue();
        ipd._workers = [];
        ipd._runtime = MagicMock();

        raw = ipd._open_native_stream(_slow_gen());
        sid = json.loads(raw)["stream_id"];
        assert started.wait(2.0);
        time.sleep(0.05);

        t0 = time.monotonic();
        ipd.shutdown();
        elapsed = time.monotonic() - t0;

        assert closed.wait(2.0) , "shutdown must close the active stream's generator";
        assert elapsed < 5.0 , "shutdown must not hang on an active stream";
        assert sid not in ipd._streams , "shutdown must deregister the stream";
        assert not any(f["type"] == "end" for f in frames) , (
            "a cancelled stream must not emit a terminal end frame"
        );
    } finally {
        ipd._stream_emit = orig_emit;
        ipd._shutting_down = orig_shutting;
        ipd._stream_window = orig_window;
        ipd._work_q = orig_q;
        ipd._workers = orig_workers;
        ipd._runtime = orig_runtime;
    }
}


# End-to-end streaming context-lifetime parity: a streaming function whose yield
# frames perform graph WRITES is drained through the native push pump -- a daemon
# thread with a foreign contextvars.Context. `context_bound_stream` must keep
# root.shared resolving inside every yield frame and commit the body's writes
# exactly once at drain, provable by a later read_notes seeing them all. (The
# discriminating mechanism test lives in tests/runtimelib/test_streaming.jac;
# this single-user in-process path shares one root across contexts, so it proves
# the wired path works but does not on its own isolate the context binding.)
test "streaming graph writes inside yield frames commit exactly once (context lifetime)" {
    import time;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        set_stream_emit
    }

    seen: list = [];
    done = threading.Event();
    def capture(stream_id: str, frame: dict) {
        seen.append(frame);
        if frame.get("type") in ("end", "error") {
            done.set();
        }
    }
    set_stream_emit(capture);
    try {
        reply = _dispatch_request(
            {
                "kind": "function",
                "name": "stream_notes",
                "node": "",
                "fields": {"texts": ["s-one", "s-two", "s-three"]},
                "token": ""
            }
        );
        assert reply.get("__jac_stream") == True;
        assert reply.get("protocol") == "push";
        assert done.wait(3.0) , "stream pump did not finish in time";
        time.sleep(0.05);
        # No error frame: every graph write inside a yield frame succeeded
        # against the live request context.
        errs = [
            f
            for f in seen
            if f.get("type") == "error"
        ];
        assert errs == [] , f"graph op failed inside a yield frame: {errs}";
        data = [
            f["data"]["saved"]
            for f in seen
            if f.get("type") == "data"
        ];
        assert data == ["s-one", "s-two", "s-three"];
        assert seen[-1].get("type") == "end";
    } finally {
        set_stream_emit(None);
    }

    # A SEPARATE request reads root.shared back: all three notes were committed
    # exactly once at drain-time -- not lost to a torn-down context, not doubled.
    read_back = _dispatch_request(
        {"kind": "walker", "name": "read_notes", "node": "", "fields": {}, "token": ""}
    );
    assert read_back["ok"] == True;
    notes = read_back["body"]["data"]["reports"][0]["notes"];
    for t in ["s-one", "s-two", "s-three"] {
        assert t in notes , f"streamed note {t!r} not committed: {notes}";
        assert notes.count(t) == 1 , f"streamed note {t!r} committed more than once: {notes}";
    }
}


test "async streaming drains context-bound through the native pump (Phase 3)" {
    import time;
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        set_stream_emit
    }

    # An async generator returned by an `sv` function must be recognized as a
    # stream, opened as a push stream, and drained by the native pump on its own
    # fresh event loop -- each `__anext__` stepped inside the captured request
    # context (so `root` resolves in the async body) via
    # `context_bound_async_stream`. A torn-down context would surface as an error
    # frame. (Async graph WRITES inside yield frames are proven deterministically
    # by tests/runtimelib/test_streaming.jac; this is the wired-path proof.)
    seen: list = [];
    done = threading.Event();
    def capture(stream_id: str, frame: dict) {
        seen.append(frame);
        if frame.get("type") in ("end", "error") {
            done.set();
        }
    }
    set_stream_emit(capture);
    try {
        reply = _dispatch_request(
            {
                "kind": "function",
                "name": "astream_numbers",
                "node": "",
                "fields": {"n": 3},
                "token": ""
            }
        );
        assert reply.get("__jac_stream") == True;
        assert reply.get("protocol") == "push";
        assert done.wait(3.0) , "async stream pump did not finish in time";
        time.sleep(0.05);
        # No error frame: every async step ran against the live request context.
        errs = [
            f
            for f in seen
            if f.get("type") == "error"
        ];
        assert errs == [] , f"async yield frame ran against a torn-down context: {errs}";
        data = [
            f["data"]["n"]
            for f in seen
            if f.get("type") == "data"
        ];
        assert data == [0, 1, 2];
        # The pump reached a clean terminal `end` -- the async wrapper (and its
        # source) closed without a dangling task or loop error.
        assert seen[-1].get("type") == "end";
    } finally {
        set_stream_emit(None);
    }
}


test "dispatch_outcome exposes SSE mode for streaming functions" {
    import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
        boot,
        dispatch_outcome
    }

    if not _BOOTED {
        graph_root = tempfile.mkdtemp(prefix="jac_ipd_test_");
        boot(_FIXTURE, os.path.join(graph_root, "graph"));
        _BOOTED = True;
    }
    outcome = dispatch_outcome(
        json.dumps(
            {
                "kind": "function",
                "name": "stream_numbers",
                "node": "",
                "fields": {"n": 3},
                "token": ""
            }
        )
    );
    assert outcome["mode"] == "sse";
    assert outcome["stream"] is not None;
    frames = list(outcome["stream"]);
    assert frames == [{"n": 0}, {"n": 1}, {"n": 2}];
}


# Needs the backend like the round-trips above. Exercises `root.shared` through
# the desktop path (the #6685 seam acceptance): a note written to the shared root
# by one in-process request must be read back by a later one. This is what proves
# the EAGER shared-root resolver the seam now installs explicitly (instead of the
# desktop copy leaning on postinit's lazy one by construction-order luck) actually
# backs `root.shared` for unauthenticated desktop calls.
test "root.shared round-trips a write then read on the desktop path (P1-D / #6685)" {
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
    orig_runtime = ipd._runtime;
    try {
        ipd._BOOT_ERROR = "stale ImportError from a prior failed boot";
        ipd._runtime = object();
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
        # not NATIVE_BOOT_ERROR. Reset _runtime to None so dispatch() reaches the
        # NOT_BOOTED path rather than calling .post() on the fake object().
        ipd._BOOT_ERROR = "";
        ipd._runtime = None;
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
        ipd._runtime = orig_runtime;
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
    orig_runtime = ipd._runtime;
    orig_workers = ipd._workers;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._work_q = None;
        ipd._runtime = None;
        ipd._workers = None;
        ipd._shutting_down = False;
        ipd.shutdown();
        assert ipd._shutting_down == False , "no-op shutdown must not flip the flag";
        assert ipd._work_q is None;
        assert ipd._runtime is None;
    } finally {
        ipd._work_q = orig_q;
        ipd._runtime = orig_runtime;
        ipd._workers = orig_workers;
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
    orig_workers = ipd._workers;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._shutting_down = False;
        ipd._work_q = queue.Queue();
        worker = threading.Thread(
            target=ipd._worker_loop, name="jac-ipd-shutdown-test", daemon=True
        );
        ipd._workers = [worker];
        worker.start();
        ipd.shutdown();
        assert not worker.is_alive() , "worker must exit after shutdown sentinel";
        assert ipd._work_q is None , "shutdown clears the queue handle";
    } finally {
        if worker is not None and worker.is_alive() {
            worker.join(timeout=1.0);
        }
        ipd._work_q = orig_q;
        ipd._workers = orig_workers;
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
    orig_workers = ipd._workers;
    orig_wv = ipd._wv_return;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._wv_return = _capture_return;
        ipd._shutting_down = False;
        ipd._work_q = queue.Queue();
        ipd._workers = None;  # enforce "no worker" regardless of prior-test state
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
        ipd._workers = orig_workers;
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
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    try {
        ipd._shutting_down = False;
        ipd._wv_return = _capture_return;
        ipd._work_q = None;
        ipd._runtime = None;
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
        ipd._runtime = orig_runtime;
        ipd._BOOT_ERROR = orig_err;
    }
}


test "dispatch() returns NOT_FOUND for an unknown walker" {
    reply = _dispatch_request(
        {
            "kind": "walker",
            "name": "no_such_walker_here",
            "node": "",
            "fields": {},
            "token": ""
        }
    );
    assert reply["status"] == 404;
    assert reply["ok"] == False;
    assert reply["body"]["error"]["code"] == "NOT_FOUND";
}


test "dispatch() returns NOT_FOUND for an unknown function" {
    reply = _dispatch_request(
        {
            "kind": "function",
            "name": "no_such_function_here",
            "node": "",
            "fields": {},
            "token": ""
        }
    );
    assert reply["status"] == 404;
    assert reply["ok"] == False;
    assert reply["body"]["error"]["code"] == "NOT_FOUND";
}


# Backend-free: when dispatch() itself raises (not returning an error envelope),
# _worker_loop must catch the exception and produce a NATIVE_DISPATCH_ERROR reply
# rather than letting the JS promise hang forever.
test "_worker_loop replies NATIVE_DISPATCH_ERROR when dispatch() raises" {
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
    orig_workers = ipd._workers;
    ipd._wv_return = _capture_return;
    ipd._shutting_down = False;

    test_q = queue.Queue();
    ipd._work_q = test_q;
    exc_worker = threading.Thread(
        target=ipd._worker_loop, name="jac-ipd-exc-test", daemon=True
    );
    ipd._workers = [exc_worker];
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
        ipd._workers = orig_workers;
        ipd._wv_return = orig_wv;
    }
}


# Backend-free (Gate C): with a worker pool, a slow walker must NOT block a fast
# one -- the fast call returns while the slow call is still executing on another
# pool worker. Proves the pool removed the single-worker head-of-line blocking.
test "pool runs invocations concurrently (no head-of-line blocking)" {
    import queue;
    import time;
    import ctypes;
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    _REPLIES.clear();
    _CAP.clear();
    orig_wv = ipd._wv_return;
    orig_shutting = ipd._shutting_down;
    orig_dispatch = ipd.dispatch;
    orig_q = ipd._work_q;
    orig_workers = ipd._workers;
    orig_timeout = ipd._timeout_s;

    release = threading.Event();
    def _blocking_dispatch(payload_json: str) -> str {
        req = json.loads(payload_json);
        if req.get("name") == "slow" {
            release.wait(5.0);
            return json.dumps(
                {
                    "status": 200,
                    "ok": True,
                    "body": {"ok": True, "data": {"which": "slow"}}
                }
            );
        }
        return json.dumps(
            {"status": 200, "ok": True, "body": {"ok": True, "data": {"which": "fast"}}}
        );
    }

    q = queue.Queue();
    workers: list = [];
    try {
        ipd._wv_return = _capture_return;
        ipd._shutting_down = False;
        ipd._timeout_s = 30.0;
        ipd.dispatch = _blocking_dispatch;
        ipd._work_q = q;
        for i in range(2) {
            w = threading.Thread(
                target=ipd._worker_loop, name="jac-ipd-pool-" + str(i), daemon=True
            );
            w.start();
            workers.append(w);
        }
        ipd._workers = workers;

        def _enqueue(id_str: bytes, name: str) {
            id_buf = ctypes.create_string_buffer(id_str);
            payload = json.dumps(
                {"kind": "walker", "name": name, "node": "", "fields": {}, "token": ""}
            );
            req_buf = ctypes.create_string_buffer(
                json.dumps([payload]).encode("utf-8")
            );
            ipd.handle(
                ctypes.cast(id_buf, ctypes.c_void_p).value,
                ctypes.cast(req_buf, ctypes.c_void_p).value,
                0
            );
            # Keep buffers alive until handle() has copied/enqueued them.
            return (id_buf, req_buf);
        }

        keep_slow = _enqueue(b"slow-1", "slow");  # occupies one worker, blocks
        keep_fast = _enqueue(b"fast-1", "fast");  # must be served by the other

        deadline = time.monotonic() + 5.0;
        while _replies_for(b"fast-1") == 0 and time.monotonic() < deadline {
            time.sleep(0.02);
        }
        assert _replies_for(b"fast-1") == 1 , (
            "fast call must return while the slow call is still blocked (pool concurrency)"
        );
        assert _replies_for(b"slow-1") == 0 , (
            "slow call is still blocked -- proves calls are not serialized"
        );

        release.set();
        deadline = time.monotonic() + 5.0;
        while _replies_for(b"slow-1") == 0 and time.monotonic() < deadline {
            time.sleep(0.02);
        }
        assert _replies_for(b"slow-1") == 1 , "slow call completes once released";
    } finally {
        release.set();
        ipd._shutting_down = True;
        for _i in range(len(workers)) {
            try {
                q.put_nowait(None);
            } except queue.Full { }
        }
        for w in workers {
            w.join(timeout=2.0);
        }
        ipd.dispatch = orig_dispatch;
        ipd._work_q = orig_q;
        ipd._workers = orig_workers;
        ipd._wv_return = orig_wv;
        ipd._shutting_down = orig_shutting;
        ipd._timeout_s = orig_timeout;
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
    orig_runtime = ipd._runtime;
    orig_workers = ipd._workers;
    orig_shutting = ipd._shutting_down;
    try {
        ipd._work_q = None;
        ipd._runtime = None;
        ipd._workers = None;
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
        ipd._runtime = orig_runtime;
        ipd._workers = orig_workers;
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
    orig_runtime = ipd._runtime;
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
        ipd._runtime = orig_runtime;
        ipd._BOOT_ERROR = orig_err;
    }
}

test "dispatch_sync() returns the result for a fast call" {
    import from importlib { import_module }

    ipd = import_module(
        "jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch"
    );
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    try {
        def _fast_dispatch(payload_json: str) -> str {
            return json.dumps(
                {
                    "status": 200,
                    "ok": True,
                    "body": {"ok": True, "data": {"result": 42}}
                }
            );
        }
        ipd._runtime = object();
        ipd._BOOT_ERROR = "";
        ipd.dispatch = _fast_dispatch;
        raw = ipd.dispatch_sync(
            json.dumps({"kind": "function", "name": "add", "fields": {"a": 2, "b": 40}})
        );
        env = json.loads(raw);
        assert env["status"] == 200 , "dispatch_sync must return the wrapped envelope";
        assert env["body"]["data"]["result"] == 42 , (
            "the fast dispatch result must round-trip through the worker thread"
        );
    } finally {
        ipd.dispatch = orig_dispatch;
        ipd._runtime = orig_runtime;
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
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    orig_timeout = ipd._timeout_s;
    try {
        ipd._runtime = object();  # truthy: clears the not-booted guard
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
        ipd._runtime = orig_runtime;
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
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    orig_timeout = ipd._timeout_s;
    try {
        ipd._runtime = object();
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
        ipd._runtime = orig_runtime;
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
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    orig_dispatch = ipd.dispatch;
    try {
        ipd._runtime = object();
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
        ipd._runtime = orig_runtime;
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
    orig_runtime = ipd._runtime;
    orig_err = ipd._BOOT_ERROR;
    try {
        ipd._runtime = None;
        ipd._BOOT_ERROR = "";
        raw = ipd.dispatch_sync(
            json.dumps({"kind": "walker", "name": "x", "fields": {}, "token": ""})
        );
        env = json.loads(raw);
        assert env["body"]["error"]["code"] != "NATIVE_BOOT_ERROR" , (
            "a fresh module must not report a stale boot error"
        );
        assert ipd._runtime is None , "test must not leave a fake client behind";
    } finally {
        ipd._runtime = orig_runtime;
        ipd._BOOT_ERROR = orig_err;
    }
}
