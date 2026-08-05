import from pathlib { Path }

obj HotModule {
    has version: str,
        dex_path: str,
        url_path: str;
}

def publish_hot_module(state: dict, version: str, dex_path: str) {
    state["module"] = HotModule(
        version=version,
        dex_path=str(dex_path),
        url_path=f"/_jac/dev/modules/android/{version}/classes.dex"
    );
}

def current_hot_module(state: dict) -> (HotModule | None) {
    return state.get("module");
}

def _is_hex_version(version: str) -> bool {
    if len(version) != 16 {
        return False;
    }
    for ch in version {
        if ch not in "0123456789abcdef" {
            return False;
        }
    }
    return True;
}

def _resolve_versioned_dex(state: dict, raw_path: str) -> (Path | None) {
    prefix = "/_jac/dev/modules/android/";
    suffix = "/classes.dex";
    if not raw_path.startswith(prefix) or not raw_path.endswith(suffix) {
        return None;
    }
    version = raw_path[len(prefix):-len(suffix)];

    if not _is_hex_version(version) {
        return None;
    }
    modules_root = state.get("modules_root");
    if not modules_root {
        return None;
    }
    base_dir = Path(str(modules_root)).resolve();
    dex_path = (base_dir / version / "classes.dex").resolve();

    try {
        dex_path.relative_to(base_dir);
    } except Exception {
        return None;
    }
    if dex_path.is_file() {
        return dex_path;
    }
    return None;
}

def jac_dev_handler_cls(state: dict) -> any {
    import from http.server { BaseHTTPRequestHandler }
    import from json { dumps }

    def do_get(handler: any) -> None {
        raw_path = handler.path.split("?")[0];
        if raw_path == "/_jac/dev/modules/manifest.json" {
            mod = current_hot_module(state);
            body = dumps(
                {
                    "version": mod.version if mod else "",
                    "path": mod.url_path if mod else ""
                }
            ).encode(
                "utf-8"
            );
            handler.send_response(200);
            handler.send_header("Content-Type", "application/json");
            handler.send_header("Content-Length", str(len(body)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(body);
        } elif raw_path == "/_jac/dev/modules/android/classes.dex" {
            mod = current_hot_module(state);
            dex_path = Path(str(mod.dex_path)) if mod else None;
            data: bytes = b"";
            if dex_path and dex_path.is_file() {
                data = dex_path.read_bytes();
            }
            if not data {
                handler.send_response(404);
                handler.send_header("Cache-Control", "no-store");
                handler.end_headers();
                return;
            }
            handler.send_response(200);
            handler.send_header("Content-Type", "application/octet-stream");
            handler.send_header("Content-Length", str(len(data)));
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
            handler.wfile.write(data);
        } else {
            dex_path = _resolve_versioned_dex(state, raw_path);
            if dex_path is not None {
                data = dex_path.read_bytes();
                handler.send_response(200);
                handler.send_header("Content-Type", "application/octet-stream");
                handler.send_header("Content-Length", str(len(data)));
                handler.send_header("Cache-Control", "no-store");
                handler.end_headers();
                handler.wfile.write(data);
                return;
            }
            handler.send_response(404);
            handler.send_header("Cache-Control", "no-store");
            handler.end_headers();
        }
    }

    def silent_log(handler: any, fmt: any, *args: any) { }

    return type(
        "JacDevHandler",
        (BaseHTTPRequestHandler, ),
        {"do_GET": do_get, "protocol_version": "HTTP/1.0", "log_message": silent_log}
    );
}

def start_jac_dev_server(port: int, state: dict) -> any {
    import from http.server { ThreadingHTTPServer }
    import from threading { Thread }

    handler_cls = jac_dev_handler_cls(state);

    httpd = ThreadingHTTPServer(("127.0.0.1", port), handler_cls);
    thread = Thread(target=httpd.serve_forever, daemon=True);
    thread.start();
    return httpd;
}

def _jac_start_dev_server(port: int, state: dict) -> any {
    return start_jac_dev_server(port, state);
}
