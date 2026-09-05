import os;
import sys;
import json;
import hashlib;
import importlib;
import from pathlib { Path }


glob PLUGIN_BOOTSTRAP_MODULES: list = [
         "manifest",
         "desktop_plugin",
         "webview_lib",
         "plugin_host",
         "registry"
     ],
     EMBEDDED: str = "embedded",
     PORT_RETRIES: int = 64;


obj HostContext {
    has port: int = 0,
        dev_port: int = 0,
        host: any = None,
        runtime: any = None,
        _stop: any = None;

    def setup_webview(wv_handle: int) {
        self.host.setup(wv_handle);
    }

    def shutdown {
        stop = self._stop;
        self._stop = None;
        if stop is not None {
            try {
                stop();
            } except Exception as e {
                sys.stderr.write("host_boot: server stop failed: " + str(e) + "\n");
            }
        }
        runtime = self.runtime;
        self.runtime = None;
        if runtime is not None {
            try {
                runtime.close();
            } except Exception as e {
                sys.stderr.write("host_boot: runtime close failed: " + str(e) + "\n");
            }
        }
    }
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
        os.path.dirname(str(jaclang.__file__)), "client", "targets", "desktop", "plugin"
    );
    if pdir not in sys.path {
        sys.path.insert(0, pdir);
    }
    for name in PLUGIN_BOOTSTRAP_MODULES {
        importlib.import_module(str(name));
    }
    return sys.modules["registry"].bootstrap_plugins(plugin_configs, sys.modules);
}


def _ensure_jac_meta_importer {
    import from jaclang.meta_importer { JacMetaImporter }
    if not any(isinstance(f, JacMetaImporter) for f in sys.meta_path) {
        sys.meta_path.insert(0, JacMetaImporter());
    }
}


def resolve_program(program: dict, app_dir: str) -> str {
    jab = str(program.get("jab") or "");
    if jab {
        import from jaclang.dist.jab { jab_app_meta, materialize_jab }
        jab_path = jab if os.path.isabs(jab) else os.path.join(app_dir, jab);
        img = materialize_jab(jab_path);
        entry_rel = str((jab_app_meta(img).get("entry") or {}).get("path") or "");
        if not entry_rel {
            raise RuntimeError(f"the app image {jab_path} has no entry to serve");
        }
        return str(img / entry_rel);
    }
    entry_path = str(program.get("entry") or "");
    if not entry_path {
        raise RuntimeError("the host config names neither an app image nor an entry");
    }
    return entry_path
        if os.path.isabs(entry_path)
        else os.path.join(app_dir, entry_path);
}


def _pinned_port -> int {
    raw = os.environ.get("JAC_DESKTOP_BROKER_PORT", "");
    if not raw {
        return 0;
    }
    try {
        return int(raw);
    } except ValueError {
        raise RuntimeError(
            "JAC_DESKTOP_BROKER_PORT must be a port number, got '" + raw + "'"
        );
    }
}


def serve_program(
    entry_file: str,
    data_dir: str,
    dist_dir: str,
    app_name: str,
    backend: str,
    host: any,
    store: any
) -> tuple[any, int, any] {
    import from jaclang.client.targets.desktop.native.broker_extension {
        DesktopBrokerExtension
    }
    import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }
    _ensure_jac_meta_importer();
    broker = DesktopBrokerExtension(store=store, host=host);
    remote = backend != EMBEDDED;
    pinned = _pinned_port();
    attempts = [(pinned, 0)]
        if pinned
        else [(preferred_port(app_name), PORT_RETRIES), (0, 0)];
    last_error: (Exception | None) = None;
    for (port, retries) in attempts {
        runtime = prepare_inprocess_runtime(
            entry_file,
            os.path.join(data_dir, ".jac", "desktop", "graph"),
            endpoint_profile="desktop",
            setup_background_services=False,
            transport_kind="listener",
            extensions=[broker],
            overrides={
                "host": "127.0.0.1",
                "port": port,
                "strict_port": retries == 0,
                "no_client": False,
                "client_dist": dist_dir,
                "static_only": remote
            }
        );
        bound: list[int] = [];
        try {
            stop = runtime.server.serve_background(
                on_ready=lambda (p: int) { bound.append(p); }, port_retries=retries
            );
        } except OSError as e {
            last_error = e;
            runtime.close();
            continue;
        }
        if not bound {
            stop();
            runtime.close();
            last_error = RuntimeError("the server did not report a bound port");
            continue;
        }
        return (runtime, bound[0], stop);
    }
    raise RuntimeError(
        "the desktop host could not bind a loopback port"
            + (f": {last_error}" if last_error is not None else "")
    );
}


def boot(config_json: str) -> HostContext {
    import from jaclang.client.targets.desktop.native.oauth_broker { SessionStore }
    cfg = json.loads(config_json);
    app_name = str(cfg.get("app_name") or "app");
    mode = str(cfg.get("mode") or "webview");
    program = (cfg.get("program") or {}) as dict;
    backend = str(cfg.get("backend") or EMBEDDED);
    plugin_configs = (cfg.get("plugins") or {}) as dict;

    app_dir = str(cfg.get("app_dir") or "") or _app_root();
    data_dir = str(os.environ.get("JAC_DATA_PATH", app_dir));

    _apply_extra_deps();

    host = _bootstrap_plugin_host(plugin_configs);
    if mode == "cef" {
        host.setup_cef();
    }

    entry_file = resolve_program(program, app_dir);
    store = SessionStore(os.path.join(data_dir, ".jac", "desktop", "session.json"));
    (runtime, port, stop) = serve_program(
        entry_file,
        data_dir,
        os.path.join(app_dir, "dist"),
        app_name,
        backend,
        host,
        store
    );

    ctx = HostContext(host=host, runtime=runtime, port=port, _stop=stop);
    try {
        ctx.dev_port = int(os.environ.get("JAC_DESKTOP_DEV_PORT", "0") or "0");
    } except (TypeError, ValueError) {
        ctx.dev_port = 0;
    }
    sys.stdout.write("JAC_DESKTOP_SERVING http://127.0.0.1:" + str(port) + "/\n");
    sys.stdout.flush();
    return ctx;
}
