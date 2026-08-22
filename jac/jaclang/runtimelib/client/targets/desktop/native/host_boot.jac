import os;
import sys;
import json;
import hashlib;
import importlib;
import socketserver;
import threading;
import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
    DispatchMode,
    boot as inprocess_boot,
    runtime as inprocess_runtime,
    dispatch_sync as inprocess_dispatch_sync,
    dispatch_outcome as inprocess_dispatch_outcome,
    forward_outcome as inprocess_forward_outcome,
    route_exists as inprocess_route_exists,
    set_stream_emit as inprocess_set_stream_emit,
    cancel_stream as inprocess_cancel_stream,
    stream_ack as inprocess_stream_ack
}
import from jaclang.runtimelib.client.targets.desktop.native.oauth_broker {
    SessionStore,
    make_handler
}


glob PLUGIN_BOOTSTRAP_MODULES: list = [
         "manifest",
         "desktop_plugin",
         "webview_lib",
         "plugin_host",
         "registry"
     ];


obj HostContext {
    has port: int = 0,
        dev_port: int = 0,
        host: any = None,
        server: any = None,
        http: any = None;

    def http_bootstrap_js -> str {
        if self.http is None {
            return "";
        }
        info = self.http.bootstrap_info();
        return "window.__JAC_HTTP__=" + json.dumps(info) + ";";
    }

    def close_http {
        h = self.http;
        if h is None {
            return;
        }
        self.http = None;
        try {
            h.stop();
        } except Exception as e {
            sys.stderr.write("host_boot: HTTP sidecar stop failed: " + str(e) + "\n");
        }
    }

    def dispatch(req_json: str) -> str {
        ctl = stream_control(req_json);
        if ctl is not None {
            return json.dumps(ctl);
        }
        payload = runtime_payload(req_json);
        if payload is not None {
            return inprocess_dispatch_sync(payload);
        }
        return self.host.dispatch(req_json) as str;
    }

    def dispatch_http(req_json: str) -> dict {
        ctl = stream_control(req_json);
        if ctl is not None {
            return {
                "mode": DispatchMode.JSON,
                "status": 200,
                "body": json.dumps(ctl),
                "stream": None
            };
        }
        payload = runtime_payload(req_json);
        if payload is not None {
            return inprocess_dispatch_outcome(payload);
        }
        return {
            "mode": DispatchMode.JSON,
            "status": 200,
            "body": self.host.dispatch(req_json) as str,
            "stream": None
        };
    }

    def setup_webview(wv_handle: int) {
        self.host.setup(wv_handle);

        def _emit_stream(stream_id: str, frame: dict) {
            payload = dict(frame);
            payload["stream_id"] = stream_id;
            self.host.emit("__jac_stream", payload);
        }
        inprocess_set_stream_emit(_emit_stream);
    }
}


def runtime_payload(req_json: str) -> (str | None) {
    try {
        wire = json.loads(req_json);
    } except Exception {
        return None;
    }
    payload: any = None;
    payload_str: str | None = None;
    if isinstance(wire, dict) {
        payload = wire;
        payload_str = req_json;
    } elif isinstance(wire, list) and len(wire) == 1 and isinstance(wire[0], str) {
        first = wire[0] as str;
        try {
            payload = json.loads(first);
            payload_str = first;
        } except Exception {
            return None;
        }
    }
    if isinstance(payload, dict) and payload.get("kind") in ("walker", "function") {
        return payload_str;
    }
    return None;
}


def stream_control(req_json: str) -> (dict | None) {
    try {
        wire = json.loads(req_json);
    } except Exception {
        return None;
    }
    msg = wire;
    if isinstance(wire, list) and len(wire) == 1 and isinstance(wire[0], str) {
        try {
            msg = json.loads(wire[0]);
        } except Exception {
            return None;
        }
    }
    if not isinstance(msg, dict) {
        return None;
    }
    ctl = msg.get("__jac_stream_ctl");
    if ctl is None {
        return None;
    }
    stream_id = str(msg.get("stream_id") or "");
    if not stream_id {
        return {
            "ok": False,
            "error": {"code": "STREAM_CTL_ERROR", "message": "missing stream_id"}
        };
    }
    if ctl == "cancel" {
        inprocess_cancel_stream(stream_id);
        return {"ok": True, "__jac_stream_ctl": "cancel", "stream_id": stream_id};
    }
    if ctl == "ack" {
        n = int(msg.get("n") or 1);
        inprocess_stream_ack(stream_id, n);
        return {"ok": True, "__jac_stream_ctl": "ack", "stream_id": stream_id, "n": n};
    }
    return {
        "ok": False,
        "error": {
            "code": "STREAM_CTL_ERROR",
            "message": "unknown stream control: " + str(ctl)
        }
    };
}


def preferred_port(app_name: str) -> int {
    return 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
}


def _app_root -> str {
    if os.path.isfile("/proc/self/exe") {
        return os.path.dirname(os.path.realpath("/proc/self/exe"));
    }
    return os.path.dirname(os.path.abspath(sys.argv[0]));
}


def _apply_extra_deps(app_dir: str) {
    extra = os.environ.get("JAC_DESKTOP_DEPS", "");
    if not extra {
        return;
    }
    for d in extra.split(os.pathsep) {
        if d and d not in sys.path {
            sys.path.append(d);
        }
    }
}


def _bootstrap_plugin_host(plugin_configs: dict) -> any {
    import jaclang;
    pdir = os.path.join(
        os.path.dirname(str(jaclang.__file__)),
        "runtimelib",
        "client",
        "targets",
        "desktop",
        "plugin"
    );
    if pdir not in sys.path {
        sys.path.insert(0, pdir);
    }
    for name in PLUGIN_BOOTSTRAP_MODULES {
        importlib.import_module(str(name));
    }
    return sys.modules["registry"].bootstrap_plugins(plugin_configs, sys.modules);
}


def _start_loopback(
    ctx: HostContext, app_dir: str, data_dir: str, app_name: str, mode: str
) {
    dist = os.path.join(app_dir, "dist");
    store = SessionStore(os.path.join(data_dir, ".jac", "desktop", "session.json"));

    server_cls: any = socketserver.ThreadingTCPServer;
    server_cls.daemon_threads = True;
    if mode == "cef" {
        handler = make_handler(
            dist,
            store,
            dispatch=ctx.dispatch_http,
            events=ctx.host as object,
            sv_bridge=inprocess_forward_outcome,
            sv_router=inprocess_route_exists
        );
    } else {
        handler = make_handler(dist, store, dispatch=ctx.dispatch);
    }
    server_cls.allow_reuse_address = True;
    pref = preferred_port(app_name);
    srv: any = None;
    port = 0;
    pinned_raw = os.environ.get("JAC_DESKTOP_BROKER_PORT", "");
    if pinned_raw {
        try {
            pinned = int(pinned_raw);
        } except ValueError {
            raise RuntimeError(
                "JAC_DESKTOP_BROKER_PORT must be a port number, got '"
                    + pinned_raw
                    + "'"
            );
        }
        try {
            srv = server_cls(("127.0.0.1", pinned), handler);
            port = pinned;
        } except OSError as bind_err {
            raise RuntimeError(
                "JAC_DESKTOP_BROKER_PORT "
                    + str(pinned)
                    + " could not be bound: "
                    + str(bind_err)
            );
        }
    } else {
        for i in range(64) {
            try {
                srv = server_cls(("127.0.0.1", pref + i), handler);
                port = pref + i;
                break;
            } except OSError {
                continue;
            }
        }
        if srv is None {
            srv = server_cls(("127.0.0.1", 0), handler);
            port = int(srv.server_address[1]);
        }
    }
    threading.Thread(target=srv.serve_forever, daemon=True).start();
    ctx.server = srv;
    ctx.port = port;
    sys.stdout.write("JAC_DESKTOP_SERVING http://127.0.0.1:" + str(port) + "/\n");
    sys.stdout.flush();
}


def _start_http_sidecar(ctx: HostContext, http_cfg: dict) {
    if not http_cfg.get("enabled") {
        return;
    }
    import from jaclang.runtimelib.client.targets.desktop.native.http_sidecar {
        start as sidecar_start
    }
    rt = inprocess_runtime();
    if rt is None {
        sys.stderr.write(
            "host_boot: [desktop.http] enabled but the in-process runtime is not "
            "booted; sidecar not started\n"
        );
        return;
    }
    caps = list(http_cfg.get("capabilities") or []);
    port = int(http_cfg.get("port") or 0);
    try {
        ctx.http = sidecar_start(rt.dispatcher, rt.introspector, caps, port);
        sys.stdout.write(
            "JAC_DESKTOP_HTTP_SIDECAR "
                + str(ctx.http.base)
                + " caps="
                + ",".join(ctx.http.capabilities)
                + "\n"
        );
        sys.stdout.flush();
    } except Exception as e {
        sys.stderr.write("host_boot: HTTP sidecar failed to start: " + str(e) + "\n");
    }
}


def boot(config_json: str) -> HostContext {
    cfg = json.loads(config_json);
    app_name = str(cfg.get("app_name") or "app");
    mode = str(cfg.get("mode") or "webview");
    entry_rel = str(cfg.get("entry_rel") or "");
    dispatch_cfg = (cfg.get("dispatch") or {}) as dict;
    plugin_configs = (cfg.get("plugins") or {}) as dict;
    http_cfg = (cfg.get("http") or {}) as dict;

    app_dir = _app_root();
    data_dir = str(os.environ.get("JAC_DATA_PATH", app_dir));

    _apply_extra_deps(app_dir);

    host = _bootstrap_plugin_host(plugin_configs);
    if mode == "cef" {
        host.setup_cef();
    }

    inprocess_boot(
        os.path.join(app_dir, "sv", entry_rel),
        os.path.join(data_dir, ".jac", "desktop", "graph"),
        timeout_s=(dispatch_cfg.get("timeout_s") or 30.0) as float,
        max_queue=(dispatch_cfg.get("max_queue") or 128) as int,
        debug=bool(dispatch_cfg.get("debug") or False)
    );

    ctx = HostContext(host=host);
    try {
        ctx.dev_port = int(os.environ.get("JAC_DESKTOP_DEV_PORT", "0") or "0");
    } except (TypeError, ValueError) {
        ctx.dev_port = 0;
    }
    _start_http_sidecar(ctx, http_cfg);
    _start_loopback(ctx, app_dir, data_dir, app_name, mode);
    return ctx;
}
