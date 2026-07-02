import os;
import sys;
import json;
import hashlib;
import importlib;
import socketserver;
import threading;
import from jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch {
    boot as inprocess_boot,
    dispatch_sync as inprocess_dispatch_sync,
    forward as inprocess_forward
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
        host: any = None,
        server: any = None;

    def dispatch(req_json: str) -> str {
        payload = runtime_payload(req_json);
        if payload is not None {
            return inprocess_dispatch_sync(payload);
        }
        return self.host.dispatch(req_json) as str;
    }

    def setup_webview(wv_handle: int) {
        self.host.setup(wv_handle);
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


def preferred_port(app_name: str) -> int {
    return 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
}


def _app_root -> str {
    if os.path.isfile("/proc/self/exe") {
        return os.path.dirname(os.path.realpath("/proc/self/exe"));
    }
    return os.path.dirname(os.path.abspath(sys.argv[0]));
}


def _apply_extra_deps {
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
    server_cls: any = socketserver.TCPServer;
    if mode == "cef" {
        server_cls = socketserver.ThreadingTCPServer;
        server_cls.daemon_threads = True;
        handler = make_handler(
            dist,
            store,
            dispatch=ctx.dispatch,
            events=ctx.host as object,
            sv_bridge=inprocess_forward
        );
    } else {
        handler = make_handler(dist, store);
    }
    server_cls.allow_reuse_address = True;
    pref = preferred_port(app_name);
    srv: any = None;
    port = 0;
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
    threading.Thread(target=srv.serve_forever, daemon=True).start();
    ctx.server = srv;
    ctx.port = port;
    sys.stdout.write("JAC_DESKTOP_SERVING http://127.0.0.1:" + str(port) + "/\n");
    sys.stdout.flush();
}


def boot(config_json: str) -> HostContext {
    cfg = json.loads(config_json);
    app_name = str(cfg.get("app_name") or "app");
    mode = str(cfg.get("mode") or "webview");
    entry_rel = str(cfg.get("entry_rel") or "");
    dispatch_cfg = (cfg.get("dispatch") or {}) as dict;
    plugin_configs = (cfg.get("plugins") or {}) as dict;

    app_dir = _app_root();
    data_dir = str(os.environ.get("JAC_DATA_PATH", app_dir));

    _apply_extra_deps();

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
    _start_loopback(ctx, app_dir, data_dir, app_name, mode);
    return ctx;
}
