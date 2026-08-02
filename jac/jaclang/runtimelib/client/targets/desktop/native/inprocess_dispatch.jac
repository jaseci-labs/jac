import sys;
import os;
import json;
import traceback;
import ctypes;
import threading;
import queue;
import uuid;
import inspect;
import from typing { AsyncGenerator }
import from urllib.parse { urlparse, parse_qs }
import from jaclang.runtimelib.streaming { iter_sync_or_async, iter_sse_frames }
import from jaclang.runtimelib.http_surface { build_surface }
import from jaclang.runtimelib.invocation {
    InvocationKind,
    InvocationRequest,
    prepare_invocation_runtime,
    _invoke_sync,
    new_request_id
}


obj CallState {
    has lock: any,
        done: bool = False,
        timer: any = None;
}


obj StreamHandle {
    has cancel: any,
        credits: any = None,
        acked: bool = False,
        stalls: int = 0,
        thread: any = None;
}


glob _runtime: any = None,
     _wv_return: any = None,
     _work_q: any = None,
     _workers: any = None,
     _pool_size: int = 4,
     _worker_local: any = threading.local(),
     _timeout_s: float = 30.0,
     _max_queue: int = 128,
     _debug: bool = False,
     _BOOT_ERROR: str = "",
     _shutting_down: bool = False,
     _stream_emit: any = None,
     _stream_window: int = 256,
     _streams: dict = {},
     _streams_lock: any = threading.Lock(),
     _http_surface: any = None;


def boot(
    entry_file: str,
    graph_path: str,
    timeout_s: float = 30.0,
    max_queue: int = 128,
    debug: bool = False,
    pool_size: int = 4,
    stream_window: int = 256
) {
    _BOOT_ERROR = "";
    _timeout_s = timeout_s;
    _max_queue = max_queue;
    _pool_size = max(1, pool_size);
    _stream_window = max(0, stream_window);

    _debug = debug or bool(os.environ.get("JAC_DESKTOP_DEBUG"));

    try {
        _boot_impl(entry_file, graph_path);
    } except Exception as e {
        _BOOT_ERROR = str(e) + "\n" + traceback.format_exc();
        sys.stderr.write("inprocess_dispatch: boot failed:\n" + _BOOT_ERROR + "\n");
        raise;
    }
}


def _ensure_jac_meta_importer {
    import sys;
    import from jaclang.meta_importer { JacMetaImporter }
    if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path) {
        sys.meta_path.insert(0, JacMetaImporter());
    }
}


def _boot_impl(entry_file: str, graph_path: str) {
    if _runtime is not None {
        try {
            _runtime.close();
        } except Exception as e {
            sys.stderr.write(
                "inprocess_dispatch: prior runtime close on re-boot failed: "
                    + str(e)
                    + "\n"
            );
        }
        _runtime = None;
    }
    _shutting_down = False;

    import jaclang;
    _ensure_jac_meta_importer();

    _runtime = prepare_invocation_runtime(entry_file, graph_path);
    _http_surface = None;

    if _work_q is None {
        _work_q = queue.Queue(maxsize=_max_queue);
        _workers = [];
        for i in range(_pool_size) {
            w = threading.Thread(
                target=_worker_loop,
                name="jac-inprocess-dispatch-" + str(i),
                daemon=True
            );
            w.start();
            _workers.append(w);
        }
    }
}


def set_stream_emit(fn: any) {
    _stream_emit = fn;
}


def runtime -> any {
    # Accessor for the booted PreparedInvocationRuntime (dispatcher + introspector).
    # The opt-in [desktop.http] sidecar shares this SAME dispatcher so uploads and
    # webhooks funnel through the one InvocationDispatcher, exactly like the native
    # webview path -- no second graph boot, no forked execution semantics.
    return _runtime;
}


def shutdown {
    if _work_q is None and _runtime is None {
        return;
    }
    if _shutting_down {
        return;
    }
    _shutting_down = True;

    with _streams_lock {
        active_streams = list(_streams.values());
    }
    for h in active_streams {
        h.cancel.set();
        creds = h.credits;
        if creds is not None {
            try {
                creds.release();
            } except Exception { }
        }
    }
    # Let each cancelled pump run its finally (close the generator -> commit-at-
    # drain teardown -> deregister) while the runtime + graph DB are still open,
    # so shutdown neither leaks a live stream nor races a commit against a closed
    # user_manager. Best-effort join: the pumps are daemon threads honoring the
    # cancel flag, so this returns promptly.
    for h in active_streams {
        th = h.thread;
        if th is not None and th.is_alive() {
            th.join(timeout=min(_timeout_s, 2.0));
        }
    }
    workers = _workers or [];
    worker_count = len(workers);
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

        for _i in range(max(worker_count, 1)) {
            try {
                _work_q.put_nowait(None);
            } except queue.Full {
                _work_q.put(None);
            }
        }
    }
    for w in workers {
        if w is not None and w.is_alive() {
            w.join(timeout=min(_timeout_s, 5.0));
        }
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

    for w in workers {
        if w is not None and w.is_alive() {
            sys.stderr.write(
                "inprocess_dispatch: worker still running after join timeout; "
                    + "queue cleared -- worker will drain its local ref and exit\n"
            );
        }
    }
    _work_q = None;
    _workers = None;
    _wv_return = None;
    _stream_emit = None;
}


def _transport_body(result: any) -> dict {
    transport = result.to_transport();
    body: dict = {"ok": transport.ok};
    if transport.ok {
        body["data"] = transport.data;
    } elif transport.error {
        err: dict = {"code": transport.error.code, "message": transport.error.message};
        if transport.error.details is not None {
            err["details"] = transport.error.details;
        }
        if transport.meta and transport.meta.request_id {
            err["request_id"] = transport.meta.request_id;
        }
        body["error"] = err;
    }
    return body;
}


def cancel_stream(stream_id: str) {
    with _streams_lock {
        handle = _streams.get(stream_id);
    }
    if handle is not None {
        handle.cancel.set();
        creds = handle.credits;
        if creds is not None {
            try {
                creds.release();
            } except Exception { }
        }
    }
}


def stream_ack(stream_id: str, n: int = 1) {
    with _streams_lock {
        handle = _streams.get(stream_id);
    }
    if handle is not None {
        handle.acked = True;
        creds = handle.credits;
        if creds is not None {
            for _i in range(max(1, n)) {
                creds.release();
            }
        }
    }
}


def _await_credit(handle: StreamHandle, emit: any) -> bool {
    if handle.credits is None {
        return True;
    }
    while True {
        if _shutting_down or handle.cancel.is_set() or emit is None {
            return False;
        }
        if handle.credits.acquire(timeout=0.1) {
            return True;
        }
        handle.stalls += 1;
        if (not handle.acked) and handle.stalls >= 5 {
            handle.credits = None;
            if _debug {
                sys.stderr.write(
                    "inprocess_dispatch: stream backpressure disabled "
                    "(no consumer acks)\n"
                );
            }
            return True;
        }
    }
}


def _pump_native_stream(stream_id: str, gen: object, handle: StreamHandle) {
    emit = _stream_emit;
    cancelled = False;
    items: any = None;
    try {
        if not inspect.isgenerator(gen) and not isinstance(gen, AsyncGenerator) {
            if emit is not None {
                emit(
                    stream_id,
                    {
                        "type": "error",
                        "error": {
                            "error_type": "TypeError",
                            "message": "native stream expected a generator, got "
                                + type(gen).__name__
                        }
                    }
                );
            }
            return;
        }

        items = iter_sync_or_async(gen);
        while True {
            if _shutting_down or emit is None or handle.cancel.is_set() {
                cancelled = True;
                break;
            }
            if not _await_credit(handle, emit) {
                cancelled = True;
                break;
            }
            try {
                item = next(items);
            } except StopIteration {
                break;
            }
            emit(stream_id, {"type": "data", "data": item});
        }

        if emit is not None
            and not _shutting_down
            and not cancelled
            and not handle.cancel.is_set() {
            emit(stream_id, {"type": "end"});
        }
    } except Exception as e {
        if emit is not None and not _shutting_down and not handle.cancel.is_set() {
            try {
                emit(
                    stream_id,
                    {
                        "type": "error",
                        "error": {"error_type": type(e).__name__, "message": str(e)}
                    }
                );
            } except Exception { }
        }
    } finally {
        if items is not None {
            try {
                items.close();
            } except Exception { }
        }
        try {
            close_fn = gen?.close;
            if close_fn {
                close_fn();
            }
        } except Exception { }
        with _streams_lock {
            if _streams.get(stream_id) is handle {
                del _streams[stream_id];
            }
        }
    }
}


def _open_native_stream(gen: object) -> str {
    emit = _stream_emit;
    if emit is None {
        return _error_envelope(
            "NATIVE_DISPATCH_ERROR",
            "streaming invocations require a native stream emit hook"
        );
    }
    stream_id = str(uuid.uuid4());
    credits = threading.Semaphore(_stream_window) if _stream_window > 0 else None;
    handle = StreamHandle(cancel=threading.Event(), credits=credits);
    with _streams_lock {
        _streams[stream_id] = handle;
    }
    th = threading.Thread(
        target=_pump_native_stream,
        args=(stream_id, gen, handle),
        name="jac-native-stream-" + stream_id[:8],
        daemon=True
    );
    handle.thread = th;
    th.start();
    return json.dumps(
        {
            "ok": True,
            "__jac_stream": True,
            "v": 1,
            "protocol": "push",
            "stream_id": stream_id
        }
    );
}


def dispatch_outcome(payload_json: str) -> dict {
    if _BOOT_ERROR {
        return {
            "mode": "error",
            "status": 500,
            "body": _error_envelope(
                "NATIVE_BOOT_ERROR", "in-process backend failed to start", _BOOT_ERROR
            ),
            "stream": None
        };
    }

    runtime = _runtime;
    if runtime is None {
        return {
            "mode": "error",
            "status": 500,
            "body": _error_envelope(
                "NOT_BOOTED", "in-process dispatch called before boot()"
            ),
            "stream": None
        };
    }
    try {
        req = json.loads(payload_json);
    } except Exception as e {
        return {
            "mode": "error",
            "status": 400,
            "body": _error_envelope(
                "NATIVE_DISPATCH_ERROR", "invalid invocation payload: " + str(e)
            ),
            "stream": None
        };
    }
    kind_raw = req.get("kind");
    if kind_raw == "walker" {
        kind = InvocationKind.WALKER;
    } elif kind_raw == "function" {
        kind = InvocationKind.FUNCTION;
    } else {
        return {
            "mode": "error",
            "status": 400,
            "body": _error_envelope(
                "NATIVE_DISPATCH_ERROR", "unsupported invocation kind: " + str(kind_raw)
            ),
            "stream": None
        };
    }
    result = _invoke_on_worker_loop(
        runtime.dispatcher,
        InvocationRequest(
            kind=kind,
            name=str(req.get("name") or ""),
            fields=(req.get("fields") or {}) as dict,
            node_id=(req.get("node") or "") or None,
            token=str(req.get("token") or "")
        )
    );
    if result.is_stream {
        return {
            "mode": "sse",
            "status": int(result.http_status or 200),
            "body": "",
            "stream": result.stream
        };
    }
    http_status = result.http_status;
    return {
        "mode": "json",
        "status": http_status,
        "body": json.dumps(
            {"status": http_status, "ok": result.ok, "body": _transport_body(result)}
        ),
        "stream": None
    };
}


def _transport_json(result: any) -> tuple[int, str] {
    transport = result.to_transport();
    status = int(result.http_status or (200 if transport.ok else 500));
    body: dict = {"type": transport.type, "ok": transport.ok};
    if transport.ok {
        body["data"] = transport.data;
    } elif transport.error {
        err: dict = {"code": transport.error.code, "message": transport.error.message};
        if transport.error.details is not None {
            err["details"] = transport.error.details;
        }
        body["error"] = err;
    }
    if transport.meta {
        meta: dict = {};
        if transport.meta.request_id {
            meta["request_id"] = transport.meta.request_id;
        }
        if transport.meta.extra {
            meta["extra"] = transport.meta.extra;
        }
        if meta {
            body["meta"] = meta;
        }
    }
    return (status, json.dumps(body));
}


def _get_surface -> any {
    # Lazily build (and cache) the transport-neutral route table from the booted
    # runtime's introspector. Reset to None on every (re-)boot so HMR reloads pick
    # up added/removed walkers + functions. Returns None only when not booted.
    if _http_surface is None {
        rt = _runtime;
        if rt is None {
            return None;
        }
        _http_surface = build_surface(rt.introspector);
    }
    return _http_surface;
}


def route_exists(method: str, path: str) -> bool {
    # Front-door predicate (used by the CEF broker) to decide whether an incoming
    # HTTP-shaped path is a walker/function route before delegating to forward().
    if _runtime is None {
        return False;
    }
    surface = _get_surface();
    if surface is None {
        return False;
    }
    return surface.match(method, urlparse(path).path) is not None;
}


def _bridge_error(status: int, message: str) -> dict {
    return {
        "status": status,
        "body": json.dumps({"ok": False, "error": {"message": message}})
    };
}


def _bridge_resolve(method: str, path: str, body: bytes, token: str) -> dict {
    # Shared route resolution + invocation for both sv-bridge front doors
    # (`forward` -> 3-tuple, `forward_outcome` -> broker outcome dict). Returns
    # either {"error": {status, body}} for a pre-execution failure, or
    # {"result": InvocationResult} for an executed call (which may be streaming).
    if _BOOT_ERROR {
        return {"error": _bridge_error(503, "backend boot failed")};
    }
    runtime = _runtime;
    if runtime is None {
        return {"error": _bridge_error(503, "backend not booted")};
    }
    surface = _get_surface();
    if surface is None {
        return {"error": _bridge_error(503, "backend not booted")};
    }

    # Route + verb resolution is owned by http_surface: custom @restspec paths and
    # verbs, path params, and the walker `/{nd}` node variant all resolve here
    # instead of the old hard-coded `/walker/{name}` split.
    parsed = urlparse(path);
    matched = surface.match(method, parsed.path);
    if matched is None {
        return {"error": _bridge_error(404, "unknown route: " + path)};
    }
    route = matched[0];
    path_params = matched[1];

    body_data: any = None;
    if body {
        try {
            body_data = json.loads(body.decode("utf-8"));
        } except Exception as e {
            return {"error": _bridge_error(400, "invalid request body: " + str(e))};
        }
        if not isinstance(body_data, dict) {
            return {"error": _bridge_error(400, "request body must be a JSON object")};
        }
    }

    # http_surface combines path params + query params (GET binding, with light
    # scalar coercion) + JSON body into the request; validation/422 stays in the
    # dispatcher.
    query = parse_qs(parsed.query) if parsed.query else {};
    request = surface.bind(route, path_params, query, body_data, token);
    result = _invoke_on_worker_loop(runtime.dispatcher, request);
    return {"result": result};
}


def forward(
    method: str, path: str, body: bytes, token: str = ""
) -> tuple[int, str, str] {
    resolved = _bridge_resolve(method, path, body, token);
    err = resolved.get("error");
    if err is not None {
        return (int(err["status"]), str(err["body"]), "application/json");
    }
    result = resolved.get("result");
    if result.is_stream {
        # A direct (non-broker) caller cannot carry a live generator back through
        # the 3-tuple, so materialize the shared SSE frames into the body. The
        # broker path (forward_outcome) instead streams the generator
        # incrementally. Both use the same runtimelib/streaming frame helpers.
        body_text = "".join(iter_sse_frames(result.stream));
        return (int(result.http_status or 200), body_text, "text/event-stream");
    }
    (status, text) = _transport_json(result);
    return (status, text, "application/json");
}


def forward_outcome(method: str, path: str, body: bytes, token: str = "") -> dict {
    # Streaming-aware sv bridge for the CEF broker. A streaming result comes back
    # tagged {mode: "sse", stream: <generator>} so the broker drains it
    # incrementally as text/event-stream (a client disconnect closes the response,
    # which cancels the generator via drain_sse -> the stream-lifecycle teardown).
    # Non-streaming results + pre-execution errors come back as {mode: "json"} the
    # broker renders verbatim (preserving the sv status code).
    resolved = _bridge_resolve(method, path, body, token);
    err = resolved.get("error");
    if err is not None {
        return {
            "mode": "json",
            "status": int(err["status"]),
            "body": str(err["body"]),
            "content_type": "application/json"
        };
    }
    result = resolved.get("result");
    if result.is_stream {
        return {
            "mode": "sse",
            "status": int(result.http_status or 200),
            "stream": result.stream
        };
    }
    (status, text) = _transport_json(result);
    return {
        "mode": "json",
        "status": status,
        "body": text,
        "content_type": "application/json"
    };
}


def dispatch(payload_json: str) -> str {
    outcome = dispatch_outcome(payload_json);
    if outcome.get("mode") == "sse" {
        stream = outcome.get("stream");
        if stream is None {
            return _error_envelope(
                "NATIVE_DISPATCH_ERROR", "streaming outcome missing generator"
            );
        }
        return _open_native_stream(stream);
    }
    return outcome.get("body") as str;
}


def _dispatch_sync_run(payload_json: str, box: dict, done: any) {
    try {
        box["v"] = dispatch(payload_json);
    } except Exception as e {
        box["v"] = _error_envelope(
            "NATIVE_DISPATCH_ERROR", str(e), traceback.format_exc()
        );
    } finally {
        done.set();
    }
}


def dispatch_sync(payload_json: str, timeout_s: float = 0.0) -> str {
    if _BOOT_ERROR {
        return _error_envelope(
            "NATIVE_BOOT_ERROR", "in-process backend failed to start", _BOOT_ERROR
        );
    }
    if _runtime is None {
        return _error_envelope(
            "NOT_BOOTED", "in-process dispatch called before boot()"
        );
    }
    if timeout_s <= 0.0 {
        timeout_s = _timeout_s;
    }
    box: dict = {"v": None};
    done = threading.Event();
    th = threading.Thread(
        target=_dispatch_sync_run,
        args=(payload_json, box, done),
        name="jac-inprocess-dispatch-sync",
        daemon=True
    );
    th.start();

    done.wait(timeout_s);
    if box["v"] is not None {
        return box["v"] as str;
    }
    return _error_envelope(
        "NATIVE_DISPATCH_TIMEOUT",
        "in-process dispatch exceeded " + str(timeout_s) + "s"
    );
}


def _error_envelope(code: str, message: str, details: str = "") -> str {
    request_id = new_request_id();
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


def _webview_return(w: int, id_bytes: bytes, status: int, payload: bytes) {
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


def _claim(state: CallState) -> bool {
    with state.lock {
        if state.done {
            return False;
        }
        state.done = True;
        return True;
    }
}


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


def _invoke_on_worker_loop(dispatcher: any, request: any) -> any {
    loop = _worker_local?.loop;
    if loop is not None {
        return loop.run_until_complete(dispatcher.invoke(request));
    }
    return _invoke_sync(dispatcher, request);
}


def _worker_loop {
    import asyncio;
    loop = asyncio.new_event_loop();
    asyncio.set_event_loop(loop);
    _worker_local.loop = loop;
    try {
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

            timer = state.timer;
            if timer is not None {
                timer.cancel();
            }
            if _claim(state) {
                _reply(w, id_bytes, result);
            }
        }
    } finally {
        _worker_local.loop = None;
        try {
            loop.close();
        } except Exception { }
    }
}


def handle(call_id: int, req_ptr: int, w: int) {
    if call_id == 0 or req_ptr == 0 {
        sys.stderr.write(
            "inprocess_dispatch: handle() called with null pointer" " (call_id="
                + str(call_id)
                + ", req_ptr="
                + str(req_ptr)
                + "); dropping\n"
        );
        return;
    }
    id_bytes = b"";
    try {
        id_bytes = ctypes.cast(call_id, ctypes.c_char_p).value or b"";
        _handle_impl(req_ptr, w, id_bytes);
    } except Exception as e {
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
        _reply(
            w,
            id_bytes,
            _error_envelope("NATIVE_DISPATCH_ERROR", str(e), traceback.format_exc())
        );
        return;
    }
    if _work_q is None {
        _reply(w, id_bytes, dispatch(payload_json));
        return;
    }

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
