import os;
import from jaclang.server.bridge {
    BridgeError,
    BridgeUnavailable,
    bridge_error_for_status,
    bridge_error_from
}

glob BRIDGE_TOKEN_ENV: str = "JAC_BRIDGE_TOKEN",
     BRIDGE_USERNAME: str = "__bridge__",
     IDEMPOTENCY_HEADER: str = "X-Jac-Idempotency-Key",
     _registry: dict[str, str] = {},
     _routes: dict[str, str] = {},
     _base_routes: dict[str, str] = {},
     _test_clients: dict[str, any] = {},
     _local_providers: dict[str, any] = {},
     _consumer_providers: dict[str, list[str]] = {},
     _bearer_token: list[str] = [],
     _consumer_app: list[str] = [],
     _read_cache: dict[tuple, any] = {},
     _read_cache_flags: list = [],
     _cache_epoch: list[int] = [0],
     _active_writes: dict[str, int] = {};

def headless_start_args(entry_file: str, port: int) -> list[str] {
    return ["run", "--serve", "--port", str(port), "--no-client", entry_file];
}

def app_start_args(
    entry_file: str, port: int, dev: bool = False, api_port: int = 0
) -> list[str] {
    args: list[str] = ["run", "--serve", "--port", str(port)];
    if dev {
        args.append("--dev");
        if api_port > 0 {
            args.append("--api-port");
            args.append(str(api_port));
        }
    }
    args.append(entry_file);
    return args;
}

def register(app: str, url: str, route: str = "") {
    _registry[app] = url.rstrip("/");
    _base_routes.pop(app, None);
    if route {
        _routes[app] = route;
        _base_routes[app] = route;
    }
}

def unregister(app: str) {
    _registry.pop(app, None);
    _base_routes.pop(app, None);
    _routes.pop(app, None);
}

def registered_route(app: str) -> str {
    return _base_routes.get(app, "");
}

def register_local(app: str, module: any) {
    _local_providers[app] = module;
}

def unregister_local(app: str) {
    _local_providers.pop(app, None);
}

def is_local(app: str) -> bool {
    return app in _local_providers;
}

def register_test_client(app: str, client: any) {
    _test_clients[app] = client;
}

def clear_test_clients {
    _test_clients.clear();
}

def clear_local_providers {
    _local_providers.clear();
}

def set_bearer_token(token: str) {
    _bearer_token.clear();
    if token {
        _bearer_token.append(token);
    }
}

def bearer_token -> str {
    if _bearer_token {
        return _bearer_token[0];
    }
    return os.environ.get(BRIDGE_TOKEN_ENV, "").strip();
}

def bridge_identity(authorization: (str | None)) -> str {
    import hmac;
    secret = os.environ.get(BRIDGE_TOKEN_ENV, "").strip();
    header = str(authorization or "");
    if not secret or not header.startswith("Bearer ") {
        return "";
    }
    presented = header[7:].strip();
    if presented and hmac.compare_digest(presented, secret) {
        return BRIDGE_USERNAME;
    }
    return "";
}

def set_consumer_app(name: str) {
    _consumer_app.clear();
    if name {
        _consumer_app.append(name);
    }
}

def consumer_app -> str {
    return _consumer_app[0] if _consumer_app else "";
}

def clear_read_cache(app: str = "") {
    _cache_epoch[0] += 1;
    if not app {
        _read_cache.clear();
        _read_cache_flags.clear();
        return;
    }
    for key in [
        k
        for k in _read_cache.keys()
        if k[0] == app
    ] {
        _read_cache.pop(key, None);
    }
}

def _read_cache_enabled -> bool {
    consumer = consumer_app();
    if not consumer {
        return False;
    }
    import from jaclang.project.config { get_config }
    cfg = get_config();
    if cfg is None or consumer not in cfg.apps {
        return False;
    }
    if not _read_cache_flags or _read_cache_flags[0] is not cfg {
        _read_cache_flags.clear();
        _read_cache_flags.extend([cfg, {}]);
    }
    flags: dict[str, bool] = _read_cache_flags[1];
    if consumer not in flags {
        scale_cfg = cfg.effective_for_app(consumer).get_plugin_config("scale");
        flags[consumer] = (
            isinstance(scale_cfg, dict) and scale_cfg.get("read_cache") is True
        );
    }
    return flags[consumer];
}

def _read_cache_key(app: str, fn: str, kwargs: dict) -> tuple {
    import json;
    return (
        app,
        fn,
        json.dumps(kwargs, sort_keys=True, `default=str),
        json.dumps(request_headers(), sort_keys=True)
    );
}

def auth_headers -> dict[str, str] {
    token = bearer_token();
    if not token {
        return {};
    }
    return {"Authorization": f"Bearer {token}"};
}

def request_headers(idempotency_key: str = "") -> dict[str, str] {
    headers = auth_headers();
    if idempotency_key {
        headers[IDEMPOTENCY_HEADER] = idempotency_key;
    }
    return headers;
}

def has_consumers -> bool {
    return any(bool(v) for v in _consumer_providers.values());
}

def _declare_consumer_provider(consumer_app: str, provider_app: str, route: str = "") {
    set_consumer_app(consumer_app);
    if consumer_app not in _consumer_providers {
        _consumer_providers[consumer_app] = [];
    }
    if provider_app not in _consumer_providers[consumer_app] {
        _consumer_providers[consumer_app].append(provider_app);
    }
    if route and provider_app not in _routes {
        _routes[provider_app] = route;
    }
}

def get_consumer_providers(consumer_app: str) -> list[str] {
    return list(_consumer_providers.get(consumer_app, []));
}

def clear_consumer_providers {
    _consumer_providers.clear();
}

def provider_route(app: str) -> str {
    return _routes.get(app, "");
}

def peer_url_env_key(app: str) -> str {
    safe = "".join(ch if ch.isalnum() else "_" for ch in app);
    return f"JAC_APP_{safe.upper()}_URL";
}

def peer_route_env_key(app: str) -> str {
    return peer_url_env_key(app)[:-4] + "_ROUTE";
}

def peer_url_from_env(app: str) -> str {
    return os.environ.get(peer_url_env_key(app), "").strip();
}

def _unavailable(app: str, name: str = "") -> BridgeUnavailable {
    return BridgeUnavailable(
        app=app,
        name=name,
        detail=f"app '{app}' is not registered; set {peer_url_env_key(app)} "
            + "or call sv_client.register()"
    );
}

def resolve_url(app: str) -> str {
    base = _registry.get(app, "");
    if not base {
        env_url = peer_url_from_env(app);
        if not env_url {
            raise _unavailable(app);
        }
        register(app, env_url, os.environ.get(peer_route_env_key(app), "").strip());
        base = _registry[app];
    }
    route = _base_routes.get(app, "");
    if route and not base.endswith(route) {
        return base + route;
    }
    return base;
}

def _ensure_available(app: str, name: str = "") -> None {
    if app in _local_providers or app in _test_clients or app in _registry {
        return;
    }
    env_url = peer_url_from_env(app);
    if env_url {
        register(app, env_url, os.environ.get(peer_route_env_key(app), "").strip());
        return;
    }
    raise _unavailable(app, name);
}

def _scale_transport -> any {
    import from jaclang.runtime.runtime { _scale_provider }
    provider = _scale_provider();
    if provider is not None and provider.sv_transport_available() {
        return provider;
    }
    return None;
}

def _unwrap_envelope(data: any, app: str, name: str) -> any {
    if isinstance(data, dict) and data.get("ok") {
        return data.get("data");
    }
    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise BridgeError(app=app, name=name, detail=str(msg or "unknown error"));
}

def _http_call(app: str, fn: str, kwargs: dict, headers: dict[str, str]) -> any {
    import from jaclang.server.serving.client { post_stream_aware_sync }
    import from jaclang.server.serving.sse { consume_sse_events }
    label = f"{app}.{fn}";
    if app in _test_clients {
        client = _test_clients[app];
        resp = client.post(f"/function/{fn}", json=kwargs, headers=headers);
        ct = str(resp.headers.get("Content-Type") or "");
        if ct.startswith("text/event-stream") {
            return consume_sse_events(str(resp.text).splitlines(), label);
        }
        data = resp.json();
    } else {
        (kind, payload) = post_stream_aware_sync(
            f"{resolve_url(app)}/function/{fn}",
            json_body=kwargs,
            headers=headers,
            label=label
        );
        if kind == "sse" {
            return payload;
        }
        data = payload;
    }
    envelope = _unwrap_envelope(data, app, fn);
    if isinstance(envelope, dict) and ("result" in envelope) {
        return envelope["result"];
    }
    return envelope;
}

def _rehydrate_walker(envelope: any, stub_cls: any) -> any {
    if not isinstance(envelope, dict) or stub_cls is None {
        raise BridgeError(detail="Walker response has no declared boundary contract");
    }
    payload = dict(envelope.get("result") or {});
    payload["reports"] = envelope.get("reports", []);
    return stub_cls._from_wire(payload);
}

def _http_spawn(
    app: str, walker_name: str, kwargs: dict, stub_cls: any, headers: dict[str, str]
) -> any {
    import from jaclang.server.serving.client { request_sync }
    if app in _test_clients {
        client = _test_clients[app];
        data = client.post(
            f"/walker/{walker_name}", json=kwargs, headers=headers
        ).json();
    } else {
        resp = request_sync(
            "POST",
            f"{resolve_url(app)}/walker/{walker_name}",
            headers=headers,
            json_body=kwargs
        );
        if resp.status_code >= 400 {
            raise bridge_error_for_status(
                resp.status_code, app, walker_name, resp.text()
            );
        }
        data = resp.json();
    }
    return _rehydrate_walker(_unwrap_envelope(data, app, walker_name) or {}, stub_cls);
}

async def _await_if_needed(value: any) -> any {
    import inspect;
    if inspect.isawaitable(value) {
        return await value;
    }
    return value;
}

async def _local_call(app: str, fn: str, kwargs: dict) -> any {
    module = _local_providers[app];
    target = getattr(module, fn, None);
    if target is None or not callable(target) {
        raise BridgeError(app=app, name=fn, detail=f"no function '{fn}'", status=404);
    }
    return await _await_if_needed(target(**kwargs));
}

async def _local_spawn(app: str, walker_name: str, kwargs: dict) -> any {
    import from jaclang { JacRuntime }
    import from jaclang.runtime.context { ExecutionContext }
    module = _local_providers[app];
    walker_cls = getattr(module, walker_name, None);
    if walker_cls is None or not isinstance(walker_cls, type) {
        raise BridgeError(
            app=app, name=walker_name, detail=f"no walker '{walker_name}'", status=404
        );
    }
    current = JacRuntime.peek_context();
    owns_ctx = current is None or current is JacRuntime.exec_ctx;
    req_ctx = current;
    token: any = None;
    if owns_ctx {
        parent = JacRuntime.get_context();
        req_ctx = ExecutionContext(_parent=parent);
        req_ctx.set_user_root(str(parent.system_root.id));
        token = JacRuntime.push_request_context(req_ctx);
    }
    if req_ctx is None {
        raise BridgeUnavailable(
            app=app, name=walker_name, detail="no execution context"
        );
    }
    try {
        mem = req_ctx.mem;
        session = mem if mem?.run_request else None;

        def _spawn_body -> any {
            instance = walker_cls(**kwargs);
            spawned = JacRuntime.`spawn(instance, req_ctx.get_root());
            return spawned if spawned is not None else instance;
        }
        result = (
            session.run_request(_spawn_body) if session is not None else _spawn_body()
        );
        walked = await _await_if_needed(result);
        if session is not None and result is not walked {
            session.commit();
        }
        if not hasattr(walked, "reports") {
            try {
                walked.reports = [];
            } except Exception {}
        }
        return walked;
    } finally {
        if owns_ctx and token is not None {
            JacRuntime.reset_request_context(token);
        }
    }
}

async def call(
    app: str,
    fn: str,
    kwargs: dict,
    effects: (list[str] | None) = None,
    contract: str = ""
) -> any {
    writer = effects is None or bool(effects);
    if writer {
        _active_writes[app] = _active_writes.get(app, 0) + 1;
        clear_read_cache(app);
    }
    epoch = _cache_epoch[0];
    cacheable = not writer
        and _active_writes.get(app, 0) == 0
        and _read_cache_enabled();
    key = _read_cache_key(app, contract or fn, kwargs) if cacheable else None;
    if cacheable and key in _read_cache {
        return _read_cache[key];
    }
    try {
        if app in _local_providers {
            result = await _local_call(app, fn, kwargs);
        } else {
            _ensure_available(app, fn);
            headers = request_headers();
            if contract {
                headers["X-Jac-Endpoint"] = contract;
            }
            transport = _scale_transport();
            if transport is not None and app not in _test_clients {
                result = transport.sv_service_call(app, fn, kwargs, headers=headers);
            } else {
                result = _http_call(app, fn, kwargs, headers);
            }
        }
    } except Exception as e {
        raise bridge_error_from(e, app, fn);
    } finally {
        if writer {
            clear_read_cache(app);
            _active_writes[app] -= 1;
        }
    }
    if cacheable and epoch == _cache_epoch[0] and _active_writes.get(app, 0) == 0 {
        _read_cache[key] = result;
    }
    return result;
}

async def spawn_walker(
    app: str, walker_name: str, kwargs: dict, stub_cls: any, idempotency_key: str = ""
) -> any {
    _active_writes[app] = _active_writes.get(app, 0) + 1;
    clear_read_cache(app);
    try {
        if app in _local_providers {
            return await _local_spawn(app, walker_name, kwargs);
        }
        _ensure_available(app, walker_name);
        headers = request_headers(idempotency_key);
        transport = _scale_transport();
        if transport is not None and app not in _test_clients {
            return transport.sv_walker_call(
                app, walker_name, kwargs, stub_cls, headers=headers
            );
        }
        return _http_spawn(app, walker_name, kwargs, stub_cls, headers);
    } except Exception as e {
        raise bridge_error_from(e, app, walker_name);
    } finally {
        clear_read_cache(app);
        _active_writes[app] -= 1;
    }
}

def spawn_deferred(
    app: str, walker_name: str, kwargs: dict, idempotency_key: str = ""
) -> str {
    import from jaclang.server.outbox { enqueue }
    return enqueue(app, walker_name, kwargs, idempotency_key);
}

def ensure_all(apps: list[str]) {
    for app in apps {
        _ensure_available(app);
    }
}
