import os;
import json;
import threading;
import urllib.request;
import urllib.error;

import from http.server { ThreadingHTTPServer }
import from jaclang.byllm.serve.supervisor { RunnerSupervisor }
import from jaclang.byllm.serve.manifest { resolve_entry, to_cache_spec, list_aliases }
import from jaclang.byllm.serve.paths { daemon_pidfile, daemon_portfile }
import from jaclang.byllm.model_cache { is_downloaded, gguf_path }

impl _Handler.log_message(self: _Handler, fmt: str, *args: any) -> None {
    return;   # logs go to daemon.log via the process's stdout/stderr
}

impl _Handler._send_json(self: _Handler, status: int, payload: dict) -> None {
    body = json.dumps(payload).encode();
    try {
        self.send_response(status);
        self.send_header("Content-Type", "application/json");
        self.send_header("Content-Length", str(len(body)));
        self.end_headers();
        self.wfile.write(body);
    } except Exception {}
}

impl _Handler.do_GET(self: _Handler) -> None {
    md = self.server.model_daemon;
    path = self.path.split("?")[0];
    if path == "/healthz" {
        self._send_json(200, {"status": "ok"});
    } elif path == "/v1/models" {
        self._send_json(200, md.list_models());
    } elif path == "/api/ps" {
        self._send_json(200, {"runners": md.supervisor.running()});
    } else {
        self._send_json(404, {"error": {"message": f"not found: {path}"}});
    }
}

impl _Handler.do_POST(self: _Handler) -> None {
    md = self.server.model_daemon;
    path = self.path.split("?")[0];
    length = int(self.headers.get("Content-Length", 0) or 0);
    raw = self.rfile.read(length) if length > 0 else b"";
    try {
        body = json.loads(raw) if raw else {};
    } except Exception {
        self._send_json(400, {"error": {"message": "invalid JSON body"}});
        return;
    }
    if path == "/v1/chat/completions" {
        md.handle_chat(self, body);
    } elif path == "/api/show" {
        md.handle_show(self, body);
    } elif path == "/api/pull" {
        # The daemon never downloads; pulls happen in the TTY CLI.
        self._send_json(409, {"error": {
            "type": "download_disabled",
            "message": "The daemon never downloads. Run: jac model pull <alias>"
        }});
    } else {
        self._send_json(404, {"error": {"message": f"not found: {path}"}});
    }
}

impl ModelDaemon.postinit -> None {
    if self.supervisor is None {
        self.supervisor = RunnerSupervisor(serve_cfg=self.serve_cfg);
    }
    self._stop = threading.Event();
}

"""OpenAI-shaped model list (every manifest alias)."""
impl ModelDaemon.list_models -> dict {
    data: list = [];
    for alias in list_aliases() {
        data.append({"id": alias, "object": "model", "owned_by": "jac"});
    }
    return {"object": "list", "data": data};
}

"""POST /api/show -> the merged manifest entry for a model."""
impl ModelDaemon.handle_show(handler: object, body: dict) -> None {
    alias = self._alias_of(str(body.get("model") or body.get("name") or ""));
    try {
        model_entry = resolve_entry(alias);
    } except ValueError as ve {
        handler._send_json(404, {"error": {"type": "model_not_found", "message": str(ve)}});
        return;
    }
    handler._send_json(200, {"alias": alias, "manifest": model_entry});
}

"""POST /v1/chat/completions -> route to a runner (never downloads)."""
impl ModelDaemon.handle_chat(handler: object, body: dict) -> None {
    alias = self._alias_of(str(body.get("model") or ""));
    try {
        model_entry = resolve_entry(alias);
    } except ValueError as ve {
        handler._send_json(404, {"error": {"type": "model_not_found", "message": str(ve)}});
        return;
    }
    spec = to_cache_spec(model_entry);
    if not is_downloaded(alias, spec) {
        handler._send_json(409, {"error": {
            "type": "model_not_pulled",
            "message": f"Local model '{alias}' is not downloaded. Run: jac model pull {alias}"
        }});
        return;
    }
    gguf = str(gguf_path(alias, spec));
    try {
        handle = self.supervisor.ensure(alias, model_entry, gguf);
    } except Exception as e {
        handler._send_json(503, {"error": {"type": "runner_unavailable", "message": str(e)}});
        return;
    }
    body["model"] = alias;
    # Manifest stop strings ride along unless the request brought its own.
    stops = model_entry.get("stop") or [];
    if stops and not body.get("stop") {
        body["stop"] = list(stops);
    }
    # In-flight bracket: the evictor never reaps a runner mid-request.
    self.supervisor.begin_request(alias);
    try {
        self._proxy(handler, handle.base_url(), body);
    } finally {
        self.supervisor.end_request(alias);
    }
}

"""Normalize a wire model name to a bare manifest alias."""
impl ModelDaemon._alias_of(model: str) -> str {
    name = model.strip();
    if name.startswith("openai/") {
        name = name[len("openai/"):];
    }
    return name.strip().lower();
}

"""Proxy the (optionally streaming) chat request to the runner."""
impl ModelDaemon._proxy(handler: object, base_url: str, body: dict) -> None {
    streaming = bool(body.get("stream"));
    data = json.dumps(body).encode();
    req = urllib.request.Request(
        base_url + "/v1/chat/completions",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST"
    );
    try {
        with urllib.request.urlopen(req, timeout=600) as resp {
            if streaming {
                handler.send_response(resp.status);
                handler.send_header("Content-Type", "text/event-stream");
                handler.send_header("Cache-Control", "no-cache");
                handler.end_headers();
                while True {
                    # read1: forward whatever is available NOW. A plain
                    # read(4096) on a chunked response blocks until the
                    # full 4096 bytes accumulate, batching slow token
                    # streams into multi-second lumps.
                    chunk = resp.read1(4096);
                    if not chunk {
                        break;
                    }
                    handler.wfile.write(chunk);
                    handler.wfile.flush();
                }
            } else {
                payload = resp.read();
                handler.send_response(resp.status);
                handler.send_header(
                    "Content-Type", resp.headers.get("Content-Type", "application/json")
                );
                handler.send_header("Content-Length", str(len(payload)));
                handler.end_headers();
                handler.wfile.write(payload);
            }
        }
    } except urllib.error.HTTPError as he {
        err = he.read();
        try {
            handler.send_response(he.code);
            handler.send_header("Content-Type", "application/json");
            handler.send_header("Content-Length", str(len(err)));
            handler.end_headers();
            handler.wfile.write(err);
        } except Exception {}
    } except Exception as e {
        handler._send_json(502, {"error": {"message": f"runner proxy failed: {e}"}});
    }
}

impl ModelDaemon._evict_loop -> None {
    idle_ttl = int(self.serve_cfg.get("idle_ttl", 300));
    wait_s = min(idle_ttl, 15) if idle_ttl > 0 else 15;
    while not self._stop.is_set() {
        self._stop.wait(wait_s);
        if self._stop.is_set() {
            break;
        }
        try {
            self.supervisor.reap_idle(idle_ttl);
        } except Exception {}
    }
}

"""Bind, record pid/port, start the evictor, and serve until stopped."""
impl ModelDaemon.serve -> int {
    import signal;
    bind_port = int(self.serve_cfg.get("serve_port", 0)) or self.port;
    self._httpd = ThreadingHTTPServer(("127.0.0.1", bind_port), _Handler);
    self._httpd.model_daemon = self;
    self.port = int(self._httpd.server_address[1]);
    # SIGTERM (`jac model stop`, service managers) must run the same cleanup
    # as Ctrl-C: raise out of serve_forever so the finally below stops the
    # runners and clears the pid/port files -- otherwise the detached
    # llama-servers (own sessions) outlive the daemon as orphans. Handlers
    # can only be installed on the main thread (tests drive serve() from a
    # worker thread -- skip there).
    def _on_sigterm(signum: int, frame: any) -> None {
        raise SystemExit(0);
    }
    try {
        signal.signal(signal.SIGTERM, _on_sigterm);
    } except Exception {}
    try {
        daemon_pidfile().write_text(str(os.getpid()));
        daemon_portfile().write_text(str(self.port));
    } except Exception {}
    self._evictor = threading.Thread(
        target=self._evict_loop, daemon=True, name="jac-model-evictor"
    );
    self._evictor.start();
    try {
        self._httpd.serve_forever();
    } finally {
        self.shutdown();
    }
    return self.port;
}

impl ModelDaemon.shutdown -> None {
    self._stop.set();
    try {
        self.supervisor.stop_all();
    } except Exception {}
    try {
        daemon_pidfile().unlink(missing_ok=True);
        daemon_portfile().unlink(missing_ok=True);
    } except Exception {}
}
