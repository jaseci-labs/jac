import asyncio;
import json;
import queue;
import webbrowser;
import from urllib.parse { urlparse }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes {
    HTMLResponse,
    JSONResponse,
    Request,
    Response,
    StreamingResponse
}
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.client.targets.desktop.native.oauth_broker {
    CLOSE_PAGE,
    DEFAULT_PREFIX,
    LOOPBACK_HOSTS,
    PendingAuth,
    SAME_SITE_VALUES,
    SessionStore,
    build_sso_login_url
}


glob MAX_INVOKE_BYTES: int = 1048576;


def _host_allowed(request: Request) -> bool {
    raw = str(request.headers.get("Host") or "");
    if not raw {
        return True;
    }
    try {
        host = urlparse("//" + raw).hostname;
    } except Exception {
        return False;
    }
    return host in LOOPBACK_HOSTS;
}


def _origin_allowed(request: Request) -> bool {
    origin = str(request.headers.get("Origin") or "");
    if origin {
        try {
            host = urlparse(origin).hostname;
        } except Exception {
            return False;
        }
        if host not in LOOPBACK_HOSTS {
            return False;
        }
    }
    site = request.headers.get("Sec-Fetch-Site");
    if site and site not in SAME_SITE_VALUES {
        return False;
    }
    return True;
}


def _query(request: Request, name: str, fallback: str = "") -> str {
    values = request.query_params.getlist(name);
    return str(values[0]).strip() if values else fallback;
}


def event_stream(host: any, q: queue.Queue, keepalive_s: float = 15.0) -> any {
    try {
        yield b": connected\n\n";
        while True {
            try {
                msg = q.get(timeout=keepalive_s);
            } except queue.Empty {
                yield b": keepalive\n\n";
                continue;
            }
            if msg is None {
                break;
            }
            yield ("data: " + str(msg) + "\n\n").encode("utf-8");
        }
    } finally {
        host.unsubscribe(q);
    }
}


async def _pull(gen: any) -> any {
    loop = asyncio.get_running_loop();
    done = object();
    def step(source: any) -> any {
        return next(source, done);
    }
    while True {
        item = await loop.run_in_executor(None, step, gen);
        if item is done {
            break;
        }
        yield item;
    }
}


obj DesktopBrokerExtension(ServerExtension) {
    has store: SessionStore,
        host: any = None,
        opener: Callable[[str], bool] = webbrowser.open,
        prefix: str = DEFAULT_PREFIX,
        pending: PendingAuth = PendingAuth();

    def register(server: JacAPIServer) {
        prefix = self.prefix;
        callback_route = prefix + "/oauth/callback";
        store = self.store;
        host = self.host;
        opener = self.opener;
        pending = self.pending;

        async def guard(request: Request, call_next: any) -> Response {
            path = request.url.path;
            if path.startswith(prefix) {
                if not _host_allowed(request) {
                    return JSONResponse(
                        status_code=403,
                        content={"ok": False, "error": "forbidden host"}
                    );
                }
                is_callback = path == callback_route
                    or path.startswith(callback_route + "/");
                if not is_callback and not _origin_allowed(request) {
                    return JSONResponse(
                        status_code=403,
                        content={"ok": False, "error": "cross-site request blocked"}
                    );
                }
            }
            next_fn: any = call_next;
            return await next_fn(request);
        }
        server.add_middleware(guard);

        def health(request: Request, **kwargs: any) -> Response {
            return JSONResponse(content={"ok": True});
        }

        def session_get(request: Request, **kwargs: any) -> Response {
            return JSONResponse(content={"token": store.read()});
        }

        def session_post(request: Request, **kwargs: any) -> Response {
            if len(request.body) > MAX_INVOKE_BYTES {
                return JSONResponse(status_code=413, content={"ok": False});
            }
            try {
                body = request.json_sync();
            } except Exception {
                body = {};
            }
            token = str(body.get("token", "") or "") if isinstance(body, dict) else "";
            store.write(token);
            return JSONResponse(content={"ok": True});
        }

        def session_delete(request: Request, **kwargs: any) -> Response {
            store.clear();
            return JSONResponse(content={"ok": True});
        }

        def oauth_start(request: Request, **kwargs: any) -> Response {
            platform = _query(request, "platform");
            api_base = _query(request, "api_base");
            operation = _query(request, "operation", "login") or "login";
            state = pending.issue();
            host_header = str(request.headers.get("Host") or "")
                or f"127.0.0.1:{server.port}";
            client_callback = f"http://{host_header}{callback_route}/{state}";
            try {
                url = build_sso_login_url(
                    api_base, platform, client_callback, operation
                );
            } except ValueError as e {
                pending.consume(state);
                return JSONResponse(
                    status_code=400, content={"ok": False, "error": str(e)}
                );
            }
            store.clear();
            try {
                opener(url);
            } except Exception as e {
                return JSONResponse(
                    status_code=500, content={"ok": False, "error": f"open_failed: {e}"}
                );
            }
            return JSONResponse(content={"ok": True, "login_url": url});
        }

        def oauth_callback(
            request: Request, state: str = "", **kwargs: any
        ) -> Response {
            token = _query(request, "token");
            error = _query(request, "error");
            if not pending.consume(state) {
                return HTMLResponse(
                    status_code=400,
                    content=CLOSE_PAGE.format(
                        heading="Sign-in failed",
                        body="This sign-in link is invalid or has expired."
                    )
                );
            }
            if token {
                store.write(token);
                return HTMLResponse(
                    content=CLOSE_PAGE.format(
                        heading="Signed in", body="Authentication complete."
                    )
                );
            }
            return HTMLResponse(
                status_code=400,
                content=CLOSE_PAGE.format(
                    heading="Sign-in failed",
                    body=f"The identity provider reported: {error or 'no token'}."
                )
            );
        }

        def events(request: Request, **kwargs: any) -> Response {
            if host is None {
                return JSONResponse(status_code=404, content={"ok": False});
            }
            q = host.subscribe();
            if q is None {
                return JSONResponse(status_code=503, content={"ok": False});
            }
            return StreamingResponse(
                _pull(event_stream(host, q)),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no"
                }
            );
        }

        def invoke(request: Request, **kwargs: any) -> Response {
            if host is None {
                return JSONResponse(status_code=404, content={"ok": False});
            }
            if len(request.body) > MAX_INVOKE_BYTES {
                return JSONResponse(status_code=413, content={"ok": False});
            }
            raw = request.body.decode("utf-8") if request.body else "[]";
            return Response(content=host.dispatch(raw), media_type="application/json");
        }

        def add(
            method: HTTPMethod,
            path: str,
            cb: any,
            params: (list[APIParameter] | None) = None
        ) {
            server.add_endpoint(
                JEndPoint(
                    method=method,
                    path=path,
                    callback=cb,
                    parameters=params if params is not None else [],
                    tags=["Desktop"],
                    summary=path,
                    include_in_schema=False,
                    forward_undeclared_query_params=False
                )
            );
        }

        add(HTTPMethod.GET, prefix + "/health", health);
        add(HTTPMethod.GET, prefix + "/session", session_get);
        add(HTTPMethod.POST, prefix + "/session", session_post);
        add(HTTPMethod.DELETE, prefix + "/session", session_delete);
        add(HTTPMethod.GET, prefix + "/oauth/start", oauth_start);
        add(
            HTTPMethod.GET,
            callback_route + "/{state}",
            oauth_callback,
            [APIParameter(name="state", kind=ParameterType.PATH)]
        );
        add(HTTPMethod.GET, prefix + "/events", events);
        add(HTTPMethod.POST, prefix + "/invoke", invoke);
    }
}
