import shutil;

import from fastapi { WebSocket }


def _install_ws_catchall(gw: object) {
    import from jaclang.scale.runtime.middleware.ws_forward { websocket_forward }
    import from jaclang.scale.runtime.lifecycle.drain { is_draining }
    import from jaclang.scale.runtime.gateway.service_registry { ServiceStatus }

    @gw.app.websocket("/{ws_path:path}")
    async def ws_proxy(websocket: WebSocket, ws_path: str) -> None {
        if is_draining() {
            await websocket.close(code=1012);
            return;
        }
        full_path: str = "/" + ws_path;
        matched = gw.registry.match_route(full_path);
        if not matched or not matched.url {
            await websocket.accept();
            await websocket.close(code=1008);
            return;
        }
        if matched.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
            await websocket.accept();
            await websocket.close(code=1013);
            return;
        }
        remaining: str = full_path[len(matched.prefix):] or "/";
        query: str = str(websocket.url.query);
        target_http: str = f"{matched.url}{remaining}";
        if query {
            target_http = f"{target_http}?{query}";
        }
        await websocket.accept();
        req_headers: dict[str, str] = dict(websocket.headers.items());
        logger.info(f"ws proxy: {full_path} -> {target_http}");
        await websocket_forward(websocket, target_http, req_headers);
    }
}

impl MicroserviceGateway.resolve_target_url(
    service_entry: ServiceEntry, path: str, query: str
) -> str {
    import jaclang;

    registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    base_url: str = registry.get(service_entry.name, service_entry.url);

    remaining: str = path[len(service_entry.prefix):];
    if not remaining {
        remaining = "/";
    }
    target: str = f"{base_url}{remaining}";
    if query {
        target = f"{target}?{query}";
    }
    return target;
}

impl MicroserviceGateway.serve_static(file_path: str) -> Response | None {
    dist = Path(self.client_dist_dir);
    target = dist / file_path;

    try {
        resolved = target.resolve();
        dist_resolved = dist.resolve();

        if not resolved.is_relative_to(dist_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
    or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}

impl MicroserviceGateway.serve_project_static(rest: str) -> Response | None {
    if not rest {
        return None;
    }
    project_root = Path(self.base_path);
    file_name: str = Path(rest).name;
    candidate_dirs: list[str] = [
        "assets",
        "dist",
        "public",
        ".jac/client/dist",
        ".jac/client/compiled",
        ".jac/client/compiled/assets"
    ];
    for d in candidate_dirs {
        local_dir: str = str(project_root / d);

        for candidate in (rest, file_name) {
            resp = self.serve_extra_static(local_dir, candidate);
            if resp {
                return resp;
            }
        }
    }
    return None;
}

impl MicroserviceGateway.serve_extra_static(
    local_dir: str, file_path: str
) -> Response | None {
    if not local_dir {
        return None;
    }
    base = Path(local_dir);
    target = base / file_path;

    try {
        resolved = target.resolve();
        base_resolved = base.resolve();
        if not resolved.is_relative_to(base_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
    or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}


impl MicroserviceGateway.serve_spa_fallback -> Response | None {
    index = Path(self.client_dist_dir) / "index.html";
    if index.is_file() {
        return HTMLResponse(content=index.read_text(encoding="utf-8"));
    }
    return None;
}

impl MicroserviceGateway.bootstrap_admin_ui -> None {
    admin_dist = Path(self.admin_dist_dir);
    dest_index = admin_dist / "index.html";

    try {
        import from jaclang.scale.admin { admin_portal }
        admin_pkg_dir = Path(admin_portal.__file__).parent;
        bundled_dist = admin_pkg_dir / "_dist";
        src_index = bundled_dist / "index.html";

        if not (bundled_dist.exists() and src_index.exists()) {
            if dest_index.exists() {
                return;
            }
            logger.info(
                "No pre-built admin _dist - building from source via "
                "JacAPIServerAdmin.build_admin_client"
            );
            if not self.build_admin_client() {
                logger.warning(
                    "Admin UI build failed - the static UI will be "
                    "unavailable. Install bun + jac-client, or use a "
                    "wheel install of jac-scale."
                );
            }
            return;
        }

        if dest_index.exists()
        and dest_index.stat().st_mtime >= src_index.stat().st_mtime {
            return;
        }

        logger.info("Deploying pre-built admin UI to gateway");
        admin_dist.mkdir(parents=True, exist_ok=True);
        for item in bundled_dist.iterdir() {
            dest = admin_dist / item.name;
            if item.is_dir() {
                if dest.exists() {
                    shutil.rmtree(dest);
                }
                shutil.copytree(item, dest);
            } else {
                shutil.copy2(item, dest);
            }
        }
    } except (ImportError, ModuleNotFoundError) {
        logger.debug("Admin module not available, skipping admin UI bootstrap");
    }
}

impl MicroserviceGateway.serve_admin_asset(asset_path: str) -> Response | None {
    admin_dist = Path(self.admin_dist_dir);

    if not asset_path or asset_path == "/" {
        target = admin_dist / "index.html";
    } else {
        target = admin_dist / asset_path;
    }

    try {
        resolved = target.resolve();
        dist_resolved = admin_dist.resolve();
        if not resolved.is_relative_to(dist_resolved) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        index = admin_dist / "index.html";
        if index.is_file() {
            return HTMLResponse(content=index.read_text(encoding="utf-8"));
        }
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/")
    or content_type in ("application/javascript", "application/json") {
        return Response(
            content=target.read_text(encoding="utf-8"), media_type=content_type
        );
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}

glob _BUILTIN_PREFIXES: tuple = (
         "/user/",
         "/cl/",
         "/walker/",
         "/function/",
         "/sso/",
         "/api-key/",
         "/webhook/",
         "/ws/",
         "/jobs/",
         "/graph/"
     ),
     _BUILTIN_EXACT: set[str] = {"/user", "/graph", "/jobs"};

impl MicroserviceGateway.build_forward_headers(request: Request) -> dict[str, str] {
    import from jaclang.scale.runtime.context.trace_ctx {
        get_current_trace,
        ensure_trace_id
    }
    fwd: dict[str, str] = {};
    for (key, value) in request.headers.items() {
        if key.lower() not in HOP_BY_HOP_HEADERS {
            fwd[key] = value;
        }
    }

    trace = get_current_trace() or ensure_trace_id(request.headers.get("X-Trace-Id"));
    fwd["X-Trace-Id"] = trace;

    import from jaclang.scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        fwd["traceparent"] = tp;
    }
    return fwd;
}

impl MicroserviceGateway.handle_health -> Response {
    return JSONResponse(
        status_code=200,
        content={"status": "healthy", "services": self.registry.health_summary()}
    );
}


impl MicroserviceGateway.handle_health_live -> Response {
    return JSONResponse(status_code=200, content={"status": "alive"});
}


impl MicroserviceGateway.handle_health_ready -> Response {
    import from jaclang.scale.runtime.lifecycle.drain { is_draining }
    if is_draining() {
        return JSONResponse(
            status_code=503, content={"status": "draining", "ready": False}
        );
    }
    return JSONResponse(status_code=200, content={"status": "ready"});
}

impl MicroserviceGateway.aggregate_graph_data(request: Request) -> Response | None {
    import json;
    import from jaclang.scale.runtime.context.util { http_forward_timeout }
    import from jaclang.scale.runtime.transport.http_forward { raw_forward }

    fwd_headers = self.build_forward_headers(request);
    query: str = str(request.url.query);

    merged_nodes: dict[str, dict] = {};
    edge_keys: set = set();
    merged_edges: list[dict] = [];
    fragments: int = 0;

    for (svc_name, svc_entry) in self.registry.entries.items() {
        if svc_entry.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING)
        or not svc_entry.url {
            continue;
        }
        target_url = f"{svc_entry.url}/graph/data";
        if query {
            target_url = f"{target_url}?{query}";
        }
        result = await raw_forward(
            "GET",
            target_url,
            fwd_headers,
            b"",
            timeout=int(http_forward_timeout(svc_name))
        );
        if result is None {
            continue;
        }
        (status, _headers, body) = result;
        if status != 200 {
            continue;
        }
        try {
            frag = json.loads(body);
        } except ValueError {
            continue;
        }
        if not isinstance(frag, dict) {
            continue;
        }
        fragments += 1;
        for n in (frag.get("nodes") or []) {
            nid = str(n.get("id"));
            if nid not in merged_nodes {
                merged_nodes[nid] = n;
            }
        }
        for e in (frag.get("edges") or []) {
            key = (str(e.get("from")), str(e.get("to")), str(e.get("label", "")));
            if key not in edge_keys {
                edge_keys.add(key);
                merged_edges.append(e);
            }
        }
    }

    if fragments == 0 {
        return None;
    }
    return JSONResponse(
        status_code=200,
        content={
            "version": "1.0",
            "nodes": list(merged_nodes.values()),
            "edges": merged_edges
        }
    );
}

impl MicroserviceGateway.handle_builtin_passthrough(
    request: Request, path: str
) -> Response | None {
    is_builtin = path.startswith(_BUILTIN_PREFIXES) or path in _BUILTIN_EXACT;
    if not is_builtin {
        return None;
    }

    # Each service can only deserialize its own module's archetypes out of the
    # shared store, so no single service can render the whole graph -- merge
    # every healthy service's fragment instead of forwarding to one of them.
    if request.method == "GET" and path == "/graph/data" {
        agg = await self.aggregate_graph_data(request);
        if agg is not None {
            return agg;
        }
    }

    fwd_headers = self.build_forward_headers(request);
    body: bytes = await request.body();
    query: str = str(request.url.query);

    for (svc_name, svc_entry) in self.registry.entries.items() {
        if svc_entry.status in (ServiceStatus.HEALTHY, ServiceStatus.STARTING)
        and svc_entry.url {
            target_url = f"{svc_entry.url}{path}";
            if query {
                target_url = f"{target_url}?{query}";
            }
            logger.info(f"Passthrough: {request.method} {path} -> {target_url}");

            import from jaclang.scale.runtime.context.util { http_forward_timeout }
            import from jaclang.scale.runtime.transport.http_forward { stream_forward }
            timeout = http_forward_timeout(svc_name);

            fr = await stream_forward(
                request.method, target_url, fwd_headers, body, timeout=int(timeout)
            );
            if fr is None {
                import from jaclang.scale.runtime.context.errors { service_unavailable }
                return service_unavailable(svc_name, "transport_error");
            }

            if fr.status in (404, 405) {
                await fr.cleanup();
                continue;
            }
            return fr.to_response();
        }
    }
    import from jaclang.scale.runtime.context.errors { not_found }
    return not_found(path, message="Not found on any service");
}

impl MicroserviceGateway.handle_admin(path: str) -> Response | None {
    if path == "/admin" {
        import from fastapi.responses { RedirectResponse }
        return RedirectResponse(url="/admin/", status_code=302);
    }
    if path.startswith("/admin/") {
        asset_path: str = path[7:];
        return self.serve_admin_asset(asset_path);
    }
    return None;
}

impl MicroserviceGateway.handle_proxy(request: Request, path: str) -> Response | None {
    svc = self.registry.match_route(path);
    if not svc {
        return None;
    }

    import from jaclang.scale.runtime.context.errors {
        service_unavailable,
        gateway_timeout
    }
    import from jaclang.scale.runtime.transport.http_forward { stream_forward }

    if svc.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
        return service_unavailable(svc.name, svc.status.value);
    }

    target_url = self.resolve_target_url(svc, path, str(request.url.query));
    logger.info(f"Proxy: {request.method} {path} -> {target_url}");

    fwd_headers = self.build_forward_headers(request);
    client_addr: str = getattr(request?.client, "host", "unknown");
    fwd_headers["X-Forwarded-For"] = client_addr;

    body: bytes = await request.body();

    import from jaclang.scale.runtime.context.util { http_forward_timeout }
    timeout = http_forward_timeout(svc.name);
    fr = await stream_forward(
        request.method, target_url, fwd_headers, body, timeout=int(timeout)
    );
    if fr is None {
        return gateway_timeout(svc.name);
    }
    return fr.to_response();
}

impl MicroserviceGateway.handle_openapi -> Response {
    import from jaclang.scale.runtime.gateway.openapi_agg { aggregate_openapi }
    doc = await aggregate_openapi(self.registry);
    return JSONResponse(status_code=200, content=doc);
}

impl MicroserviceGateway.handle_docs -> Response {
    import from fastapi.openapi.docs { get_swagger_ui_html }
    return get_swagger_ui_html(
        openapi_url="/openapi.json", title="Jac Microservice Gateway - API"
    );
}

impl MicroserviceGateway.handle_metrics -> Response {
    import from jaclang.scale.runtime.middleware.metrics { render_metrics }
    import from jaclang.scale.runtime.context.errors { error_response }
    (body, ctype) = render_metrics(self._metrics_registry);
    if not body {
        return error_response(
            code="METRICS_UNAVAILABLE",
            message="metrics not available (install prometheus_client)",
            status=503
        );
    }
    return Response(content=body, media_type=ctype);
}

impl MicroserviceGateway.handle_static(request: Request, path: str) -> Response | None {
    if request.method != "GET" {
        return None;
    }

    file_path: str = path.lstrip("/");
    if file_path {
        mount_matched = False;
        for mount in self.static_mounts {
            prefix = str(mount.get("url_prefix", "")).lstrip("/").rstrip("/");
            if not prefix {
                continue;
            }
            if file_path == prefix {
                continue;
            }
            if file_path.startswith(prefix + "/") {
                mount_matched = True;
                sub_path = file_path[len(prefix) + 1:];
                local_dir = str(mount.get("local_path", ""));
                mounted_resp = self.serve_extra_static(local_dir, sub_path);
                if mounted_resp {
                    return mounted_resp;
                }
                break;
            }
        }

        if not mount_matched {
            static_resp = self.serve_static(file_path);
            if static_resp {
                return static_resp;
            }
        }

        if file_path.startswith("static/") {
            proj_resp = self.serve_project_static(file_path[len("static/"):]);
            if proj_resp {
                return proj_resp;
            }
        }
    } else {
        index_resp = self.serve_spa_fallback();
        if index_resp {
            return index_resp;
        }
    }

    accept: str = request.headers.get("accept", "");
    if "text/html" in accept {
        return self.serve_spa_fallback();
    }
    return None;
}

impl MicroserviceGateway.setup -> FastAPI {
    import time;
    self.app = FastAPI(title="Jac Microservice Gateway");
    gw = self;

    self.bootstrap_admin_ui();

    try {
        self._install_admin_api();
    } except Exception as e {
        self.server = None;
        logger.warning(
            "Admin JSON API not installed - admin UI will be read-only "
            f"static. Cause: {type(e).__name__}: {e}"
        );
    }

    import from jaclang.scale.runtime.context.trace_ctx {
        set_current_trace,
        reset_current_trace,
        ensure_trace_id
    }
    import from jaclang.scale.runtime.context.log_emit { install_structured_logging }
    install_structured_logging();

    import from jaclang.scale.runtime.middleware.metrics { build_gateway_metrics }
    import from jaclang.scale.config.config_loader { get_scale_config }
    mon_cfg = get_scale_config().get_monitoring_config();
    (self._metrics_registry, self._metrics_requests, self._metrics_duration) = (
        build_gateway_metrics(
            namespace=mon_cfg.get("namespace", "jaclang_scale"),
            histogram_buckets=mon_cfg.get("histogram_buckets")
        )
    );

    import from jaclang.scale.runtime.context.tracing {
        install_tracing,
        start_server_span,
        end_span
    }
    trc_cfg = get_scale_config().get_microservices_config().get("tracing", {});
    install_tracing(
        enabled=trc_cfg.get("enabled", False),
        endpoint=trc_cfg.get("endpoint"),
        sample_ratio=float(trc_cfg.get("sample_ratio", 1.0))
    );

    @self.app.middleware("http")
    async def dispatcher(request: Request, call_next: object) -> Response {
        path: str = request.url.path;

        trace_id = ensure_trace_id(request.headers.get("X-Trace-Id"));
        tok = set_current_trace(trace_id);

        span = start_server_span(
            f"{request.method} {path}",
            trace_id,
            request.headers.get("traceparent"),
            {"http.method": request.method, "http.target": path}
        );

        start = time.time();
        svc_label: str = "__unmatched__";
        try {
            resp: Response | None = None;

            import from jaclang.scale.runtime.gateway.dispatch {
                classify_route,
                ROUTE_BUILTIN,
                ROUTE_ADMIN,
                ROUTE_PROXY
            }
            service_prefixes: list = [e.prefix for e in gw.registry.entries.values()];
            decision = classify_route(path, service_prefixes);

            if decision.kind == ROUTE_BUILTIN {
                if path == "/healthz/live" {
                    svc_label = "__health_live__";
                    resp = gw.handle_health_live();
                } elif path == "/healthz/ready" {
                    svc_label = "__health_ready__";
                    resp = gw.handle_health_ready();
                } elif path == "/health" or path == "/healthz" {
                    svc_label = "__health__";
                    resp = gw.handle_health();
                } elif path == "/metrics" {
                    svc_label = "__metrics__";
                    resp = gw.handle_metrics();
                } elif path == "/openapi.json" {
                    svc_label = "__openapi__";
                    resp = await gw.handle_openapi();
                } elif path == "/docs" {
                    svc_label = "__docs__";
                    resp = gw.handle_docs();
                }
            } elif decision.kind == ROUTE_ADMIN {
                svc_label = "__admin__";
                admin_resp: Response | None = None;
                if gw.server is not None {
                    admin_resp = await call_next(request);
                } else {
                    admin_resp = gw.handle_admin(path);
                }
                if admin_resp is None {
                    import from jaclang.scale.runtime.context.errors { not_found }
                    admin_resp = not_found(path);
                }
                resp = admin_resp;
            } elif decision.kind == ROUTE_PROXY {
                matched = gw.registry.match_route(path);
                if matched {
                    svc_label = matched.name;
                    resp = await gw.handle_proxy(request, path);
                }
            }

            if resp is None {
                builtin = await gw.handle_builtin_passthrough(request, path);
                if builtin is not None {
                    svc_label = "__builtin__";
                    resp = builtin;
                }
            }
            if resp is None {
                static_resp = gw.handle_static(request, path);
                if static_resp is not None {
                    svc_label = "__static__";
                    resp = static_resp;
                }
            }
            if resp is None {
                import from jaclang.scale.runtime.context.errors { not_found }
                resp = not_found(path);
            }

            resp.headers["X-Trace-Id"] = trace_id;

            if span is not None {
                span.set_attribute("http.status_code", resp.status_code);
                span.set_attribute("jac.service", svc_label);
            }

            if gw._metrics_requests is not None {
                import from jaclang.scale.runtime.middleware.metrics {
                    classify_outcome
                }
                outcome = classify_outcome(resp.status_code);
                gw._metrics_requests.labels(
                    service=svc_label, method=request.method, outcome=outcome
                ).inc();
                gw._metrics_duration.labels(
                    service=svc_label, method=request.method
                ).observe(
                    time.time() - start
                );
            }
            return resp;
        } finally {
            end_span(span);
            reset_current_trace(tok);
        }
    }

    _install_ws_catchall(self);

    import from jaclang.scale.runtime.middleware.middleware {
        Middleware,
        MiddlewareRegistry
    }
    registry = MiddlewareRegistry();

    import from jaclang.scale.runtime.lifecycle.drain { build_drain_middleware }
    registry.register(
        Middleware(name="drain", priority=20, fn=build_drain_middleware("__gateway__"))
    );

    import from jaclang.scale.config.config_loader { get_scale_config }
    ms_cfg = get_scale_config().get_microservices_config();

    import from jaclang.scale.runtime.middleware.rate_limit {
        build_rate_limit_middleware
    }
    rl_mw = build_rate_limit_middleware(ms_cfg.get("rate_limit", {}));
    if rl_mw is not None {
        registry.register(Middleware(name="rate_limit", priority=10, fn=rl_mw));
    }

    registry.install(self.app);

    cors_cfg = ms_cfg.get("cors", {});
    if cors_cfg.get("allow_origins") {
        import from fastapi.middleware.cors { CORSMiddleware }
        self.app.add_middleware(
            CORSMiddleware,
            allow_origins=cors_cfg["allow_origins"],
            allow_methods=cors_cfg.get("allow_methods", ["*"]),
            allow_headers=cors_cfg.get("allow_headers", ["*"]),
            allow_credentials=cors_cfg.get("allow_credentials", False),
            expose_headers=cors_cfg.get("expose_headers", []),
            max_age=cors_cfg.get("max_age", 600)
        );
    }

    return self.app;
}

impl MicroserviceGateway.start -> None {
    import from jaclang.scale.runtime.lifecycle.drain { install_signal_drain }
    import from jaclang.scale.config.config_loader { get_scale_config }

    if self.app is None {
        self.setup();
    }
    logger.info(f"Gateway starting on {self.host}:{self.port}");

    ms_cfg = get_scale_config().get_microservices_config();
    drain_timeout: float = float(ms_cfg.get("drain_timeout_seconds", 10));

    config = uvicorn.Config(
        getattr(self, "app"),
        host=self.host,
        port=self.port,
        timeout_graceful_shutdown=int(drain_timeout)
    );
    server = uvicorn.Server(config);
    install_signal_drain(server, timeout_s=drain_timeout);
    server.run();
}


impl MicroserviceGateway._install_admin_api -> None {
    import from jaclang.scale.jserver.jfast_api { JFastApiServer }
    import from jaclang.scale.webhook.webhook { ApiKeyManager }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    self.server = JFastApiServer(app=self.app);

    self.user_manager = Jac.get_user_manager(base_path=self.base_path);
    self.server.set_user_manager(self.user_manager);
    self._api_key_manager = ApiKeyManager();

    self.register_admin_endpoints();
    self.register_logs_endpoints();
    self.register_llm_telemetry_endpoints();

    self.register_traces_endpoints();
    self.register_ops_endpoints();
    self.register_deploy_health_endpoints();
    self.register_network_endpoints();
    self.register_podenv_endpoints();

    self.server.create_server();

    logger.info(
        "Admin JSON API installed on gateway "
        "(/admin/login, /admin/me, /admin/users, /admin/logs/*, ...)"
    );
}
