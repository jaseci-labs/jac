"""In-process `sv` walker/function dispatch for the Jac-native desktop host.

On the web target a `cl` -> `sv` call is an HTTP POST to a remote backend. On
desktop (issue #6596, Phase J4) the same call runs IN-PROCESS: the embedded
CPython has jaclang loaded, so we boot the real jac-scale ASGI app over a
Starlette `TestClient` (no socket, no remote server) and replay the frozen
`{kind, name, node, fields, token}` request contract against it.

Two roles:

* `boot()` / `dispatch()` are plain Python-callable entry points. The desktop
  host calls them from native code, and the test suite imports this module and
  calls them directly -- that direct-import path is what makes the round-trip
  testable without a webview, a display, or `nacompile`.
* `shutdown()` tears down the worker, transport, and reply path after the host's
  webview exits (between `wv.run()` and `Py_Finalize()`).
* `handle()` is the native trampoline bound to `window.__jac_invoke`. It runs on
  the UI (GTK main-loop) thread with the GIL held, so it must NOT block: it
  copies the request off the (soon-to-be-freed) C-string pointers and enqueues
  it, then returns immediately, freeing the UI loop. A single daemon worker
  thread (started by `boot()`) drains the queue, runs `dispatch()`, and replies
  via `webview_return` -- which is off-thread-safe because its `resolve()` re-
  posts the JS eval onto the run-loop thread (validated by the P0-A spike). The
  reply ALWAYS happens -- even on exception -- so the JS promise never hangs.
  `webview_return` is a DT_NEEDED global symbol of the host binary, bound lazily
  (it does not exist in the test process, which never calls `handle()`).

The lane is single and serialized, so `handle()` also (P1-A) arms a per-call
timeout and bounds the queue: on a full queue it rejects immediately with
`NATIVE_DISPATCH_BUSY`; on expiry a timer thread rejects the JS promise with
`NATIVE_DISPATCH_TIMEOUT`. The timeout is NON-PREEMPTIVE -- the single worker is
blocked synchronously inside `dispatch()` and cannot expire its own call, so the
timer only abandons the result and unblocks the promise; the walker keeps
occupying the lane until it finishes, after which the worker drops the now-
orphaned late reply via a per-call claim flag (so a request id is never replied
to twice). Timeout and queue depth come from `[plugins.desktop.dispatch]` in
jac.toml, baked into the `boot()` call at build time.

Every natively-constructed error envelope carries a `request_id` (P1-C) so an
error surfaced in the app can be correlated with its full traceback in the
terminal/log. The production error contract is `{code, message, request_id}`:
the traceback / boot reason is ALWAYS written to stderr keyed by that id (so a
release build stays debuggable from the log) but is echoed INTO the envelope
only when debug is on -- no traceback leaks to the client otherwise. Debug comes
from `[plugins.desktop.dispatch].debug` (baked into `boot()`), or the
`JAC_DESKTOP_DEBUG` env var at runtime for a no-rebuild switch.

Unlike `oauth_broker` (which is transpiled to *stdlib-only* Python because the
pre-J4 host had no jaclang), this module deliberately depends on jaclang +
jac-scale: that runtime is exactly what J4 makes available in the embedded
interpreter. It is transpiled with `jac jac2py` and staged beside the binary.
"""

import sys;
import os;
import json;
import traceback;
import ctypes;
import threading;
import queue;
import uuid;

"""Per-call claim state shared between the dispatch worker and the arming timer.

The claim flag (`done`) is the P1-A late-reply suppression guard: both the timer
and the worker race to reply, and only the first caller to set `done` True via
`_claim()` wins the reply slot."""
obj CallState {
    has lock: any,
        done: bool = False,
        timer: any = None;
}


# ── Boot / transport state ───────────────────────────────────────────────────
# The booted Starlette TestClient (in-process jac-scale app). Set by boot();
# read by dispatch(). None until boot() runs.
glob _tc: any = None,
     # The PreparedInProcessRuntime the seam (#6685) hands back -- owns the prepared
     # server + transport so shutdown has one handle. `_tc` is its `.client`, kept as
     # a direct alias so dispatch() is unchanged. None until boot() runs.
     _runtime: any = None,
     # Lazily-bound `webview_return` C function (global symbol of the host binary).
     # Stays None in the test process, which never reaches handle().
     _wv_return: any = None,
     # The single serialized dispatch queue. handle() enqueues; _worker_loop() drains.
     # Created (and the worker started) once by boot(); None until then.
     _work_q: any = None,
     # The daemon worker started by boot(); joined (bounded) by shutdown().
     _worker: any = None,
     # ── P1-A / P1-C tuning ───────────────────────────────────────────────────────
     # Per-call timeout (seconds) and bounded-queue depth. Defaults are overridden by
     # boot() from [plugins.desktop.dispatch] (baked in at build time).
     _timeout_s: float = 30.0,
     _max_queue: int = 128,
     # When True, native error envelopes echo the full traceback / boot reason in
     # `error.details`; when False (release default) only `{code, message, request_id}`
     # is sent. Set by boot() from .debug or the JAC_DESKTOP_DEBUG env (P1-C).
     _debug: bool = False,
     # ── Status flags ─────────────────────────────────────────────────────────────
     # P1-B: the boot failure reason (str + traceback), or "" if boot succeeded / has
     # not run. Set in boot()'s except path before re-raise; read by dispatch() so a
     # call that reaches a broken backend gets NATIVE_BOOT_ERROR (with the real reason)
     # instead of NOT_BOOTED. The host shows a native error page when boot() re-raises.
     _BOOT_ERROR: str = "",
     # Set by shutdown(); handle() rejects new work and _reply() is a no-op so timer
     # callbacks cannot call webview_return after the window closes.
     _shutting_down: bool = False,
     # Serializes forward() calls (the CEF loopback path) against the single
     # in-process TestClient. The webview path serializes via the daemon worker;
     # CEF has no worker -- its ThreadingTCPServer can drive concurrent loopback
     # threads into _tc, so they take this lock instead. None until first use.
     _sv_lock: any = None;


"""Boot the in-process jac-scale ASGI app for `entry_file`'s module.

`entry_file` is the user's `.jac` entry point; `graph_path` is the on-disk graph
/ persistence dir (created if absent). Idempotent enough to call once at host
startup. Leaves the booted client in the module global `_tc`.
"""
def boot(
    entry_file: str,
    graph_path: str,
    timeout_s: float = 30.0,
    max_queue: int = 128,
    debug: bool = False
) {
    global _timeout_s,_max_queue,_debug,_BOOT_ERROR;
    # Clear any stale boot failure from a prior attempt so a successful retry
    # does not leave dispatch() permanently blocked on NATIVE_BOOT_ERROR.
    _BOOT_ERROR = "";
    _timeout_s = timeout_s;
    _max_queue = max_queue;
    # P1-C: traceback gating defaults OFF (release contract: no traceback leaks
    # to the client). The build bakes the configured value in; JAC_DESKTOP_DEBUG
    # flips it on at runtime without a rebuild.
    _debug = debug or bool(os.environ.get("JAC_DESKTOP_DEBUG"));
    # P1-B: any boot failure is recorded (so dispatch() can return a real
    # NATIVE_BOOT_ERROR envelope) AND re-raised, so PyRun_SimpleString(DISPATCH_PY)
    # returns != 0 in the host and it shows a native error page instead of
    # navigating to a silently-broken app (where the first __jac_invoke would
    # hang forever).
    try {
        _boot_impl(entry_file, graph_path);
    } except Exception as e {
        _BOOT_ERROR = str(e) + "\n" + traceback.format_exc();
        sys.stderr.write("inprocess_dispatch: boot failed:\n" + _BOOT_ERROR + "\n");
        raise;
    }
}


"""Ensure JacMetaImporter is on sys.meta_path (dev pin may have evicted it)."""
def _ensure_jac_meta_importer {
    import sys;
    import from jaclang.meta_importer { JacMetaImporter }
    if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path) {
        sys.meta_path.insert(0, JacMetaImporter());
    }
}


"""Do the actual boot work, separated so boot() stays a thin error-capturing
wrapper (P1-B). Boots the in-process jac-scale ASGI app and leaves it in `_tc`,
then starts the single dispatch worker. Raises on any failure."""
def _boot_impl(entry_file: str, graph_path: str) {
    global _tc,_runtime,_work_q,_worker,_shutting_down,_sv_lock;
    # Guard against double boot() without an intervening shutdown(): close the
    # existing runtime to avoid leaking its JFastApiServer and Jac machine
    # context (which hold open DB connections and memory).
    if _runtime is not None {
        try {
            _runtime.close();
        } except Exception as e {
            sys.stderr.write(
                "inprocess_dispatch: prior runtime close on re-boot failed: " + str(
                    e
                ) + "\n"
            );
        }
        _runtime = None;
        _tc = None;
    }
    _shutting_down = False;
    # Serialization lock for the CEF loopback forward() path (created here, at
    # single-threaded boot, so concurrent loopback threads never race to make it).
    if _sv_lock is None {
        _sv_lock = threading.Lock();
    }
    import jaclang;
    _ensure_jac_meta_importer();
    import from jac_scale.inprocess { prepare_inprocess_runtime }

    # Prepare the in-process jac-scale runtime through the shared no-serve seam
    # (#6685). The seam owns what boot() used to hand-copy out of
    # JacAPIServerCore.start() / ScaleTestClient (and had drifted on): module
    # load, the idempotent jac-scale plugin registration, endpoint registration,
    # guest user + the explicit shared-root resolver, and TestClient construction.
    #  - endpoint_profile="desktop": health, auth (login / refresh / sso), and the
    #    walker + function dispatch this issue is about -- the set a desktop `cl`
    #    client drives.
    #  - setup_background_services=False: emailer / scheduler / events are out of
    #    scope for J4's walker/function dispatch (a real server's start() wires
    #    them; the seam now owns that choice instead of boot() skipping them by
    #    omission).
    #  - transport_kind="testclient": the in-process single-serialized-worker
    #    boundary recorded in #6596 P0-0.
    _runtime = prepare_inprocess_runtime(
        entry_file,
        graph_path,
        endpoint_profile="desktop",
        setup_background_services=False,
        transport_kind="testclient"
    );
    _tc = _runtime.client;

    # Start the single serialized dispatch worker once (daemon: dies with the
    # host). handle() enqueues onto this; the worker runs dispatch() OFF the UI
    # thread so a slow walker can't freeze the window (P0-C). One worker, so
    # in-process requests don't race on the shared Jac runtime / TestClient. The
    # queue is BOUNDED (P1-A): once `max_queue` calls are waiting on the single
    # lane, handle() rejects further calls with BUSY instead of growing forever.
    if _work_q is None {
        _work_q = queue.Queue(maxsize=_max_queue);
        _worker = threading.Thread(
            target=_worker_loop, name="jac-inprocess-dispatch", daemon=True
        );
        _worker.start();
    }
}


"""Tear down the in-process dispatch lane (called by the host after wv.run()).

Idempotent no-op when boot() never ran. Stops accepting new work, drains the
queue without replying (the webview is gone), signals the worker with a
sentinel, joins it with a bounded wait, closes the jac-scale transport, and
clears module globals so Py_Finalize() does not race daemon threads or ctypes
webview_return calls."""
def shutdown {
    global _tc,_runtime,_work_q,_worker,_shutting_down,_wv_return;
    if _work_q is None and _tc is None and _runtime is None {
        return;
    }
    if _shutting_down {
        return;
    }
    _shutting_down = True;
    if _work_q is not None {
        while True {
            try {
                item = _work_q.get_nowait();
            } except queue.Empty {
                break;
            }
            if item is None {
                continue;
            }
            (_w, _id, _pj, state) = item;
            timer = state.timer;
            if timer is not None {
                timer.cancel();
            }
            _claim(state);
        }
        try {
            _work_q.put_nowait(None);
        } except queue.Full {
            _work_q.put(None);
        }
    }
    if _worker is not None and _worker.is_alive() {
        _worker.join(timeout=min(_timeout_s, 5.0));
    }
    if _runtime is not None {
        try {
            _runtime.close();
        } except Exception as e {
            sys.stderr.write(
                "inprocess_dispatch: runtime close failed: " + str(e) + "\n"
            );
        }
        _runtime = None;
    }
    # Always clear the queue, client, and worker so a re-boot via _boot_impl()
    # starts fresh. The worker captured the old queue as a local `q` before its
    # blocking get(), so nulling `_work_q` here does not crash it; it drains
    # from its local ref and exits when it processes the sentinel we put above.
    if _worker is not None and _worker.is_alive() {
        sys.stderr.write(
            "inprocess_dispatch: worker still running after join timeout; " + "queue cleared -- worker will drain its local ref and exit\n"
        );
    }
    _tc = None;
    _work_q = None;
    _worker = None;
    _wv_return = None;
}


"""Map one `{kind, name, node, fields, token}` request onto the in-process app.

Returns a JSON string mirroring a fetch Response -- `{status, ok, body}` with
`body` the `{ok, data, error}` envelope -- so the client runtime can replay the
HTTP-path status logic (401 -> re-login) and unwrap `body` exactly as it does on
web. A non-JSON reply (e.g. a bare 404) is wrapped so the client still gets an
envelope instead of a hang.
"""
def dispatch(payload_json: str) -> str {
    if _BOOT_ERROR {
        # boot() failed (P1-B). The host normally shows a native error page and
        # never loads the app, so this path is a belt-and-suspenders net: if a
        # call somehow reaches here, hand back the real reason rather than a bare
        # NOT_BOOTED. The traceback rides in `details` only under debug (P1-C).
        return _error_envelope(
            "NATIVE_BOOT_ERROR", "in-process backend failed to start", _BOOT_ERROR
        );
    }
    # Capture _tc to a local so the rest of the call holds a stable reference
    # even if shutdown() nulls the global concurrently (safe today with a single
    # worker, but would race under a future multi-worker lane without this).
    tc = _tc;
    if tc is None {
        # boot() never ran: reply with an envelope instead of dereferencing a
        # None client and raising -- handle()'s caller turns a raised exception
        # into a hung JS promise.
        return _error_envelope(
            "NOT_BOOTED", "in-process dispatch called before boot()"
        );
    }
    req = json.loads(payload_json);
    kind = req.get("kind");
    name = req.get("name");
    node_id = req.get("node") or "";
    fields = req.get("fields") or {};
    token = req.get("token") or "";
    headers = {};
    if token {
        headers["Authorization"] = "Bearer " + token;
    }
    if kind == "walker" {
        path = "/walker/" + str(name);
        if node_id {
            path = path + "/" + str(node_id);
        }
    } else {
        path = "/function/" + str(name);
    }
    resp = tc.post(path, json=fields, headers=headers);
    try {
        body = resp.json();
    } except Exception {
        body = {"ok": False, "error": {"message": resp.text}};
    }
    return json.dumps(
        {"status": resp.status_code, "ok": resp.is_success, "body": body}
    );
}


"""Forward a raw HTTP request to the in-process app (the CEF loopback path).

Unlike `dispatch()` -- which wraps the reply in the `{status, ok, body}` envelope
the native-bind transport expects and always rides on HTTP 200 -- this returns
the jac-scale response VERBATIM: `(status_code, body_text, content_type)`. The
CEF target leaves `__JAC_NATIVE__` unset, so the client runtime takes its normal
web fetch path (`POST {origin}/walker/<name>` etc.) against the loopback server;
that server hands the request here and echoes our tuple straight back, so the
client sees a real status (incl. 401 -> re-login) and the raw `{ok,data,error}`
body it parses on web.

`token` is the bearer extracted from the request's `Authorization` header by the
loopback handler (the web client sends it there, not in an envelope field).

Serialized by `_sv_lock`: the CEF loopback is a ThreadingTCPServer, so concurrent
request threads would otherwise hit the single TestClient at once. A 503 envelope
is returned (never an exception) if boot() failed or never ran, mirroring how the
web path would surface a dead backend.
"""
def forward(
    method: str, path: str, body: bytes, token: str = ""
) -> tuple[int, str, str] {
    if _BOOT_ERROR {
        return (
            503,
            json.dumps({"ok": False, "error": {"message": "backend boot failed"}}),
            "application/json"
        );
    }
    tc = _tc;
    if tc is None {
        return (
            503,
            json.dumps({"ok": False, "error": {"message": "backend not booted"}}),
            "application/json"
        );
    }
    global _sv_lock;
    if _sv_lock is None {
        _sv_lock = threading.Lock();
    }
    headers = {"Content-Type": "application/json"};
    if token {
        headers["Authorization"] = "Bearer " + token;
    }
    with _sv_lock {
        resp = tc.request(method, path, content=body, headers=headers);
    }
    ctype = resp.headers.get("content-type", "application/json");
    return (resp.status_code, resp.text, ctype);
}


"""Short unique id stamped into every native error envelope and the matching
stderr log line (P1-C), so a developer can correlate an error surfaced in the app
with its full traceback in the terminal/log."""
def _new_request_id -> str {
    return uuid.uuid4().hex[:12];
}


"""Build a `{status, ok, body}` native-error envelope as a JSON string.

`status` is 0 (no HTTP exchange happened), so the client runtime treats it as a
transport error rather than an auth/redirect status. Used for every error this
module constructs itself -- NATIVE_BOOT_ERROR / NOT_BOOTED (dispatch), the P1-A
reject paths (TIMEOUT, BUSY), NATIVE_DISPATCH_ERROR (worker + malformed request),
and the guarded-reply fallback.

Every envelope carries a `request_id` (P1-C). When `details` (a traceback / boot
reason) is supplied it is ALWAYS written to stderr keyed by that id -- so a
release build stays debuggable from the log -- but is echoed INTO the envelope
only under `_debug`; the production contract is `{code, message, request_id}`
with no traceback leakage."""
def _error_envelope(code: str, message: str, details: str = "") -> str {
    request_id = _new_request_id();
    error = {"code": code, "message": message, "request_id": request_id};
    if details {
        sys.stderr.write(
            "inprocess_dispatch: [" + request_id + "] " + code + ": " + details + "\n"
        );
        if _debug {
            error["details"] = details;
        }
    }
    return json.dumps(
        {"status": 0, "ok": False, "body": {"ok": False, "error": error}}
    );
}


"""Lazily resolve + call the host binary's `webview_return` global symbol.

`id_bytes` MUST be a COPY of the JS call id (a `bytes`), not the raw `id`
pointer: the worker replies after webview has freed the original `id`/`req`
pointers, and `webview_return`'s `resolve()` copies the id string at call time,
so a stale pointer yields a garbage id -> the JS promise never resolves (the bug
the P0-A spike caught). The `c_char_p` argtype passes the bytes by value."""
def _webview_return(w: int, id_bytes: bytes, status: int, payload: bytes) {
    global _wv_return;
    if _wv_return is None {
        lib = ctypes.CDLL(None);
        lib.webview_return.argtypes = [
            ctypes.c_void_p,
            ctypes.c_char_p,
            ctypes.c_int,
            ctypes.c_char_p
        ];
        lib.webview_return.restype = ctypes.c_int;
        _wv_return = lib.webview_return;
    }
    _wv_return(w, id_bytes, status, payload);
}


"""Guarded reply: never let `webview_return` escape into PyRun_SimpleString.

Used by both the worker and handle()'s inline error path. A raised exception
here would be swallowed silently and hang the JS promise forever, so guard it,
retry once with a minimal payload (in case the large `result` was the problem),
and worst-case log to stderr so the failure is at least visible. `id_bytes` is
the UI-thread copy of the call id (see `_webview_return`)."""
def _reply(w: int, id_bytes: bytes, result: str) {
    if _shutting_down {
        return;
    }
    try {
        _webview_return(w, id_bytes, 0, result.encode("utf-8"));
    } except Exception as e {
        try {
            fallback = _error_envelope("NATIVE_RETURN_ERROR", str(e));
            _webview_return(w, id_bytes, 0, fallback.encode("utf-8"));
        } except Exception as e2 {
            sys.stderr.write(
                "inprocess_dispatch: webview_return failed: " + str(e2) + "\n"
            );
        }
    }
}


"""Atomically claim the single reply for a call; True only for the first caller.

Each queued call carries a `{lock, done, timer}` state. The arming timer (on
expiry) and the worker (on completion) both race to reply -- exactly ONE must
win, or the JS promise gets two `webview_return`s for one id. Whoever claims
first replies; the loser drops its (now-orphaned) reply. This is the P1-A late-
reply suppression -- and because there is only one lane, at most one orphan ever
exists at a time."""
def _claim(state: CallState) -> bool {
    with state.lock {
        if state.done {
            return False;
        }
        state.done = True;
        return True;
    }
}


"""Timer callback (own thread): reject a call that outran `_timeout_s`.

Armed by handle() at enqueue time because the single worker is blocked inside
`dispatch()` and cannot wake itself to expire anything (P1-A). Non-preemptive:
this only rejects the JS promise -- the walker keeps running on the lane until it
finishes, at which point the worker finds the call already claimed and drops the
late result. No-op if the worker already replied (claim lost)."""
def _on_timeout(w: int, id_bytes: bytes, state: CallState) {
    if _shutting_down {
        return;
    }
    if _claim(state) {
        _reply(
            w,
            id_bytes,
            _error_envelope(
                "NATIVE_DISPATCH_TIMEOUT",
                "in-process dispatch exceeded " + str(_timeout_s) + "s"
            )
        );
    }
}


"""Single serialized dispatch worker (daemon thread, started by boot()).

Drains the queue forever: each item is `(w, id_bytes, payload_json, state)`
already copied off the C-strings by handle() on the UI thread. Runs dispatch()
OFF the UI thread so a slow walker cannot freeze the window. One worker, so
requests are serialized -- they don't race on the shared Jac runtime /
TestClient. After dispatch() returns it cancels the call's timeout timer and
replies only if it WINS the claim: if the timer already fired (the call outran
`_timeout_s`), the promise was already rejected and this completion is a now-
orphaned late reply to drop (P1-A)."""
def _worker_loop {
    while True {
        if _shutting_down {
            break;
        }
        q = _work_q;
        if q is None {
            break;
        }
        item = q.get();
        if item is None {
            break;
        }
        (w, id_bytes, payload_json, state) = item;
        result = "";
        try {
            result = dispatch(payload_json);
        } except Exception as e {
            result = _error_envelope(
                "NATIVE_DISPATCH_ERROR", str(e), traceback.format_exc()
            );
        }
        # Best-effort: stop the arming timer so it doesn't fire after we reply.
        # The claim below is the real guard against a double reply (the timer
        # may have fired while dispatch() was still running).
        timer = state.timer;
        if timer is not None {
            timer.cancel();
        }
        if _claim(state) {
            _reply(w, id_bytes, result);
        }
    }
}


"""Native trampoline for `window.__jac_invoke` (runs on the UI thread).

`call_id` / `req_ptr` are raw C-string pointers carried as ints; `w` is the
webview handle. Both pointers are freed when this callback returns, so we copy
the id (as bytes) and the request payload off them NOW, on the UI thread, then
enqueue for the single worker and return immediately -- blocking here would
freeze the GTK main loop (the bug P0-C fixes). The worker always replies, so the
JS promise never hangs.
"""
def handle(call_id: int, req_ptr: int, w: int) {
    if call_id == 0 or req_ptr == 0 {
        # Null pointers mean this is an internal webview library event (e.g. teardown
        # callback), not a JS caller -- there is no pending promise to resolve, so
        # dropping silently is correct. Log so production logs show if this fires
        # unexpectedly (a real call arriving with a null id would hang its promise).
        sys.stderr.write(
            "inprocess_dispatch: handle() called with null pointer" " (call_id=" + str(
                call_id
            ) + ", req_ptr=" + str(req_ptr) + "); dropping\n"
        );
        return;
    }
    id_bytes = b"";
    try {
        id_bytes = ctypes.cast(call_id, ctypes.c_char_p).value or b"";
        _handle_impl(req_ptr, w, id_bytes);
    } except Exception as e {
        # Last-resort guard: _handle_impl raised despite its internal guards, or
        # the id copy itself failed. Reply best-effort with whatever id we have
        # (empty id -> webview_return drops it, but no harm), and always log via
        # _error_envelope. This is the path Layer B's rc can only stare at.
        _reply(
            w,
            id_bytes,
            _error_envelope("NATIVE_INVOKE_ERROR", str(e), traceback.format_exc())
        );
    }
}

def _handle_impl(req_ptr: int, w: int, id_bytes: bytes) {
    if _shutting_down {
        _reply(
            w,
            id_bytes,
            _error_envelope(
                "NATIVE_DISPATCH_SHUTDOWN", "in-process dispatch is shutting down"
            )
        );
        return;
    }
    try {
        outer = json.loads(ctypes.cast(req_ptr, ctypes.c_char_p).value.decode());
        payload_json = outer[0];
    } except Exception as e {
        # Malformed request: reply inline -- we still hold a valid id copy here
        # on the UI thread, and there's nothing useful to hand the worker.
        _reply(
            w,
            id_bytes,
            _error_envelope("NATIVE_DISPATCH_ERROR", str(e), traceback.format_exc())
        );
        return;
    }
    if _work_q is None {
        # boot() never ran: dispatch inline (yields a NOT_BOOTED envelope) and
        # reply with the still-valid id copy rather than silently dropping the
        # call. Cheap -- dispatch() short-circuits when _tc is None.
        _reply(w, id_bytes, dispatch(payload_json));
        return;
    }
    # P1-A: arm a per-call timeout and bound the queue. The single worker blocks
    # synchronously inside dispatch() and can't expire its own call, so arm the
    # timer HERE (on the UI thread) before handoff -- it rejects the JS promise
    # on expiry. The per-call claim flag lets the timer and the worker race for
    # the one reply, so the loser's (late) reply is dropped. Start the timer
    # before enqueue so the worker always sees `state["timer"]`; the timeout
    # therefore covers queue-wait + dispatch, which is the honest "stop waiting"
    # semantics. A full queue means the lane is saturated -> reject with BUSY.
    state = CallState(lock=threading.Lock());
    timer = threading.Timer(_timeout_s, _on_timeout, (w, id_bytes, state));
    timer.daemon = True;
    state.timer = timer;
    timer.start();
    try {
        _work_q.put_nowait((w, id_bytes, payload_json, state));
    } except queue.Full {
        timer.cancel();
        if _claim(state) {
            _reply(
                w,
                id_bytes,
                _error_envelope(
                    "NATIVE_DISPATCH_BUSY",
                    "in-process dispatch queue is full (max " + str(_max_queue) + ")"
                )
            );
        }
    } except Exception as e {
        timer.cancel();
        _reply(
            w,
            id_bytes,
            _error_envelope("NATIVE_DISPATCH_ERROR", str(e), traceback.format_exc())
        );
    }
}
