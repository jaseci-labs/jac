import sys;
import os;
import json;
import traceback;
import ctypes;
import threading;
import queue;
import uuid;

obj CallState {
    has lock: any,
        done: bool = False,
        timer: any = None;
}


glob _tc: any = None,
     _runtime: any = None,
     _wv_return: any = None,
     _work_q: any = None,
     _worker: any = None,
     _timeout_s: float = 30.0,
     _max_queue: int = 128,
     _debug: bool = False,
     _BOOT_ERROR: str = "",
     _shutting_down: bool = False,
     _sv_lock: any = None;


def boot(
    entry_file: str,
    graph_path: str,
    timeout_s: float = 30.0,
    max_queue: int = 128,
    debug: bool = False
) {
    global _timeout_s,_max_queue,_debug,_BOOT_ERROR;

    _BOOT_ERROR = "";
    _timeout_s = timeout_s;
    _max_queue = max_queue;

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
    global _tc,_runtime,_work_q,_worker,_shutting_down,_sv_lock;

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

    if _sv_lock is None {
        _sv_lock = threading.Lock();
    }
    import jaclang;
    _ensure_jac_meta_importer();
    import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }

    _runtime = prepare_inprocess_runtime(
        entry_file,
        graph_path,
        endpoint_profile="desktop",
        setup_background_services=False,
        transport_kind="testclient"
    );
    _tc = _runtime.client;

    if _work_q is None {
        _work_q = queue.Queue(maxsize=_max_queue);
        _worker = threading.Thread(
            target=_worker_loop, name="jac-inprocess-dispatch", daemon=True
        );
        _worker.start();
    }
}


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


def dispatch(payload_json: str) -> str {
    if _BOOT_ERROR {
        return _error_envelope(
            "NATIVE_BOOT_ERROR", "in-process backend failed to start", _BOOT_ERROR
        );
    }

    tc = _tc;
    if tc is None {
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
    if _tc is None {
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


def _new_request_id -> str {
    return uuid.uuid4().hex[:12];
}


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

        timer = state.timer;
        if timer is not None {
            timer.cancel();
        }
        if _claim(state) {
            _reply(w, id_bytes, result);
        }
    }
}


def handle(call_id: int, req_ptr: int, w: int) {
    if call_id == 0 or req_ptr == 0 {
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
