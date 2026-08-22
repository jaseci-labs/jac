import json;
import socket;
import secrets;
import threading;
import time;
import from jaclang.runtimelib.invocation { InvocationKind, InvocationRequest }
import from jaclang.runtimelib.http_surface { HTTP_CAPABILITIES }


obj SidecarHandle {
    has base: str,
        token: str,
        capabilities: list[str],
        port: int,
        server: any = None,
        thread: any = None,
        sock: any = None;

    def bootstrap_info -> dict {
        return {
            "base": self.base,
            "token": self.token,
            "capabilities": list(self.capabilities)
        };
    }

    def stop {
        srv = self.server;
        if srv is not None {
            try {
                srv.should_exit = True;
            } except Exception { }
        }
        th = self.thread;
        if th is not None {
            try {
                th.join(timeout=5.0);
            } except Exception { }
        }
        sk = self.sock;
        if sk is not None {
            try {
                sk.close();
            } except Exception { }
        }
    }
}


def _normalize_caps(capabilities: list) -> list[str] {
    seen: list[str] = [];
    for c in (capabilities or []) {
        name = str(c);
        if name in HTTP_CAPABILITIES and name not in seen {
            seen.append(name);
        }
    }
    return seen;
}


def _transport_envelope(result: any) -> tuple[int, dict] {
    status = int(result.http_status or (200 if result.ok else 500));
    return (status, result.to_body());
}


def _bearer_token(request: any) -> str {
    auth = request.headers.get("authorization", "") or "";
    if auth.startswith("Bearer ") {
        return auth[7:];
    }
    return "";
}


def start(
    dispatcher: any,
    introspector: any,
    capabilities: list,
    port: int = 0,
    ready_timeout_s: float = 10.0
) -> SidecarHandle {
    import uvicorn;
    import from fastapi {
        FastAPI,
        Request,
        WebSocket,
        WebSocketDisconnect,
        HTTPException
    }
    import from fastapi.responses { JSONResponse }

    caps = _normalize_caps(capabilities);
    token = secrets.token_urlsafe(32);

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    sock.bind(("127.0.0.1", int(port)));
    actual_port = int(sock.getsockname()[1]);
    base = "http://127.0.0.1:" + str(actual_port);

    openapi_on = "openapi" in caps;
    app = FastAPI(
        title="jac-desktop-sidecar",
        docs_url=("/docs" if openapi_on else None),
        redoc_url=None,
        openapi_url=("/openapi.json" if openapi_on else None)
    );

    def _gate(request: any) {
        supplied: any = request.headers.get("x-jac-sidecar-token", "") or "";
        gate: any = token;
        import hmac;
        if not hmac.compare_digest(supplied, gate) {
            raise HTTPException(status_code=401, detail="invalid sidecar token");
        }
    }

    async def _run_invocation(
        kind: any, name: str, fields: dict, node_id: any, user_token: str
    ) -> any {
        request = InvocationRequest(
            kind=kind, name=name, fields=fields, node_id=node_id, token=user_token
        );
        result = await dispatcher.invoke(request);
        (status, body) = _transport_envelope(result);
        return JSONResponse(status_code=status, content=body);
    }

    if "multipart" in caps {
        walkers = introspector.get_walkers();
        functions = introspector.get_functions();

        async def _multipart_fields(request: any) -> dict {
            form = await request.form();
            fields: dict = {};
            for (key, value) in form.multi_items() {
                val: any = value;
                if hasattr(val, "read") and hasattr(val, "filename") {
                    fields[key] = await val.read();
                } else {
                    fields[key] = val;
                }
            }
            return fields;
        }

        def _make_walker_handler(wname: str) -> any {
            async def _handler(request: any) -> any {
                _gate(request);
                fields = await _multipart_fields(request);
                node_id = request.path_params.get("nd") or None;
                return await _run_invocation(
                    InvocationKind.WALKER,
                    wname,
                    fields,
                    node_id,
                    _bearer_token(request)
                );
            }
            return _handler;
        }

        def _make_function_handler(fname: str) -> any {
            async def _handler(request: any) -> any {
                _gate(request);
                fields = await _multipart_fields(request);
                return await _run_invocation(
                    InvocationKind.FUNCTION, fname, fields, None, _bearer_token(request)
                );
            }
            return _handler;
        }

        for (wname, _wcls) in walkers.items() {
            h = _make_walker_handler(str(wname));
            app.add_route("/walker/" + str(wname), h, methods=["POST"]);
            app.add_route("/walker/" + str(wname) + "/{nd}", h, methods=["POST"]);
        }
        for (fname, _fobj) in functions.items() {
            fh = _make_function_handler(str(fname));
            app.add_route("/function/" + str(fname), fh, methods=["POST"]);
        }
    }

    if "webhooks" in caps {
        async def _webhook(request: any) -> any {
            _gate(request);
            name = str(request.path_params.get("name") or "");
            raw = await request.body();
            fields: dict = {};
            if raw {
                try {
                    parsed = json.loads(raw.decode("utf-8"));
                    if isinstance(parsed, dict) {
                        fields = parsed;
                    } else {
                        fields = {"payload": parsed};
                    }
                } except Exception {
                    fields = {"payload": raw.decode("utf-8", "replace")};
                }
            }
            return await _run_invocation(
                InvocationKind.WALKER, name, fields, None, _bearer_token(request)
            );
        }
        app.add_route("/webhook/{name}", _webhook, methods=["POST"]);
    }

    if "websockets" in caps {
        async def _ws_walker(websocket: any) -> None {
            name = str(websocket.path_params.get("name") or "");
            supplied: any = websocket.headers.get("x-jac-sidecar-token", "") or "";
            gate: any = token;
            import hmac;
            if not hmac.compare_digest(supplied, gate) {
                await websocket.close(code=4401);
                return;
            }
            await websocket.accept();
            user_token = "";
            auth = websocket.headers.get("authorization", "") or "";
            if auth.startswith("Bearer ") {
                user_token = auth[7:];
            }
            try {
                while True {
                    text = await websocket.receive_text();
                    try {
                        msg = json.loads(text);
                    } except Exception {
                        msg = {};
                    }
                    fields = msg if isinstance(msg, dict) else {};
                    request = InvocationRequest(
                        kind=InvocationKind.WALKER,
                        name=name,
                        fields=fields,
                        token=user_token
                    );
                    result = await dispatcher.invoke(request);
                    (_status, body) = _transport_envelope(result);
                    await websocket.send_text(json.dumps(body));
                }
            } except WebSocketDisconnect { }
        }
        app.add_websocket_route("/ws/walker/{name}", _ws_walker);
    }

    config = uvicorn.Config(
        app,
        host="127.0.0.1",
        port=actual_port,
        log_level="warning",
        access_log=False,
        loop="asyncio",
        ws=("auto" if "websockets" in caps else "none")
    );
    server: any = uvicorn.Server(config);

    server.install_signal_handlers = lambda { };

    def _serve {
        import warnings;
        with warnings.catch_warnings() {
            warnings.simplefilter("ignore");
            try {
                server.run(sockets=[sock]);
            } except Exception as e {
                import traceback;
                import sys;
                sys.stderr.write(
                    "jac-http-sidecar: server thread crashed: "
                        + str(e)
                        + "\n"
                        + traceback.format_exc()
                        + "\n"
                );
            }
        }
    }

    thread = threading.Thread(target=_serve, name="jac-http-sidecar", daemon=True);
    thread.start();

    deadline = time.monotonic() + ready_timeout_s;
    while not getattr(server, "started", False) {
        if time.monotonic() > deadline {
            break;
        }
        time.sleep(0.02);
    }

    return SidecarHandle(
        base=base,
        token=token,
        capabilities=caps,
        port=actual_port,
        server=server,
        thread=thread,
        sock=sock
    );
}
