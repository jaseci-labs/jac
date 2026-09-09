import shutil;

import from jaclang.server.serving.ws { WebSocket }
import from jaclang.server.serving.endpoint { WSEndPoint }
import from jaclang.scale.runtime.routing {
    GATEWAY_BUILTIN_PREFIXES,
    GATEWAY_BARE_API_PATHS,
    GATEWAY_DISCOVERY_SEGMENTS,
    GATEWAY_REPLICATED_SEGMENTS
}


def _install_ws_catchall(gw: MicroserviceGateway) {
    import from jaclang.scale.runtime.middleware.ws_forward { websocket_forward }
    import from jaclang.scale.runtime.gateway.service_registry { ServiceStatus }

    async def ws_proxy(websocket: WebSocket) -> None {
        ws_path: str = websocket.path_params.get('ws_path', '');
        if gw.drain.draining {
            await websocket.close(code=1012);
            return;
        }
        full_path: str = "/" + ws_path;
        matched = gw.registry.match_route(full_path);
        if not matched {
            await gw.refresh_app_routes();
            matched = gw.registry.entries.get(gw.route_table.owner(full_path));
        }
        page_base: str = "";
        if not matched {
            matched = gw.root_member();
            if matched is not None and matched.owns_root() {
                page_base = matched.page_url;
            }
        }
        if not matched or not (page_base or matched.url) {
            await websocket.accept();
            await websocket.close(code=1008);
            return;
        }
        if matched.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
            await websocket.accept();
            await websocket.close(code=1013);
            return;
        }
        remaining: str = full_path;
        if not matched.is_root and full_path.startswith(matched.prefix) {
            remaining = full_path[len(matched.prefix):];
        }
        remaining = remaining or "/";
        query: str = str(websocket.url.query);
        target_http: str = f"{page_base or matched.url}{remaining}";
        if query {
            target_http = f"{target_http}?{query}";
        }

        async def _accept_as_upstream_did(selected: str) {
            await websocket.accept(subprotocol=selected);
        }
        req_headers: dict[str, str] = dict(websocket.headers.items());
        logger.debug(f"ws proxy: {full_path} -> {target_http}");
        await websocket_forward(
            websocket, target_http, req_headers, on_upstream=_accept_as_upstream_did
        );
    }
    gw.app.add_ws_endpoint(WSEndPoint(path="/{ws_path:path}", handler=ws_proxy));
}

impl MicroserviceGateway.service_base_url(service_entry: ServiceEntry) -> str {
    import jaclang;

    registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    return registry.get(service_entry.name, service_entry.url);
}

impl MicroserviceGateway.resolve_target_url(
    service_entry: ServiceEntry, path: str, query: str
) -> str {
    base_url: str = self.service_base_url(service_entry);

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


impl MicroserviceGateway.has_client_bundle -> bool {
    if (Path(self.client_dist_dir) / "index.html").is_file() {
        return True;
    }
    root_svc = self.root_member();
    return root_svc is not None and root_svc.owns_root();
}

impl MicroserviceGateway.serve_spa_fallback -> Response | None {
    index = Path(self.client_dist_dir) / "index.html";
    if index.is_file() {
        return HTMLResponse(content=index.read_text(encoding="utf-8"));
    }
    return None;
}

impl MicroserviceGateway.bootstrap_admin_ui -> None {
    if (Path(self.admin_dist_dir) / "index.html").is_file() {
        return;
    }
    logger.info(
        "No staged admin console; the first request to /admin builds it from source."
    );
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

glob _BUILTIN_PREFIXES: tuple = GATEWAY_BUILTIN_PREFIXES,
     _BUILTIN_EXACT: set[str] = GATEWAY_BARE_API_PATHS,
     _DISCOVERY_SEGMENTS: set[str] = set(GATEWAY_DISCOVERY_SEGMENTS),
     _REPLICATED_SEGMENTS: set[str] = set(GATEWAY_REPLICATED_SEGMENTS);

impl MicroserviceGateway.build_forward_headers(request: Request) -> dict[str, str] {
    import from jaclang.scale.runtime.context.trace_ctx {
        get_current_trace,
        ensure_trace_id
    }
    fwd: dict[str, str] = {};
    for (key, value) in request.headers.items() {
        if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "x-forwarded-for" {
            fwd[key] = value;
        }
    }

    peer: str = request.client_host or "unknown";
    fwd["X-Forwarded-For"] = ", ".join(
        request.headers.getlist("X-Forwarded-For") + [peer]
    );

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
    if self.drain.draining {
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

    for (svc_name, svc_entry) in self.eligible_services() {
        target_url = f"{self.service_base_url(svc_entry)}/graph/data";
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

    if request.method == "GET" and path == "/graph/data" {
        agg = await self.aggregate_graph_data(request);
        if agg is not None {
            return agg;
        }
    }

    stripped: str = path.strip("/");
    first_seg: str = stripped.split("/")[0] if stripped else "";
    root_svc = self.root_member();
    if first_seg in _DISCOVERY_SEGMENTS {
        return await self.probe_services(request, path, self.eligible_services());
    }
    if first_seg in _REPLICATED_SEGMENTS {
        return await self.deliver_once(request, path);
    }

    owner = await self.resolve_learned_owner(path);
    if owner is not None {
        return await self.forward_root_path(request, owner, path);
    }
    unknown: list = [
        (name, svc)
        for (name, svc) in self.eligible_services()
        if not self.route_table.is_learned(name)
    ];
    if not unknown {
        if root_svc is not None {
            return None;
        }
        import from jaclang.scale.runtime.context.errors { not_found }
        return not_found(path, message="No service declares");
    }
    return await self.probe_services(request, path, unknown);
}

impl MicroserviceGateway.eligible_services -> list[tuple[str, ServiceEntry]] {
    return [
        (name, svc)
        for (name, svc) in self.registry.entries.items()
        if svc.is_routable()
    ];
}

impl MicroserviceGateway.root_member -> ServiceEntry | None {
    return self.registry.root_entry();
}

impl MicroserviceGateway.shell_answers(request: Request, path: str) -> bool {
    if request.method != "GET" {
        return False;
    }
    if not (Path(self.client_dist_dir) / "index.html").is_file() {
        return False;
    }
    return not path.lstrip("/") or "text/html" in request.headers.get("accept", "");
}

impl MicroserviceGateway.forward_to_root(
    request: Request, path: str
) -> Response | None {
    root_svc = self.root_member();
    if root_svc is None {
        return None;
    }
    if not root_svc.is_routable() {
        if self.shell_answers(request, path) {
            return None;
        }
        import from jaclang.scale.runtime.context.errors { service_unavailable }
        return service_unavailable(root_svc.name, "not accepting traffic");
    }
    if not root_svc.owns_root() {
        return None;
    }
    if root_svc.page_url {
        page_resp = await self.forward_root_path(
            request, root_svc, path, root_svc.page_url
        );
        if page_resp is not None and page_resp.status_code not in (502, 504) {
            return page_resp;
        }
        logger.warning(
            f"client dev server at {root_svc.page_url} did not answer {path}; "
            f"falling back to {root_svc.name}'s own page rendering"
        );
    }
    return await self.forward_root_path(request, root_svc, path);
}

impl MicroserviceGateway.forward_static_to_root(
    request: Request, path: str
) -> Response | None {
    if request.method != "GET" or not path.startswith("/static/") {
        return None;
    }
    root_svc = self.root_member();
    if root_svc is None or not root_svc.is_routable() {
        return None;
    }
    return await self.forward_root_path(request, root_svc, path);
}

impl MicroserviceGateway.resolve_learned_owner(path: str) -> ServiceEntry | None {
    svc_name: str = self.route_table.owner(path);
    if svc_name and svc_name not in self.registry.entries {
        self.route_table.forget(svc_name);
        svc_name = "";
    }
    if not svc_name {
        if not await self.refresh_app_routes() {
            return None;
        }
        svc_name = self.route_table.owner(path);
    }
    return self.registry.entries.get(svc_name) if svc_name else None;
}

impl MicroserviceGateway.forward_root_path(
    request: Request, service_entry: ServiceEntry, path: str, base_url: str = ""
) -> Response | None {
    if not service_entry.is_routable() {
        import from jaclang.scale.runtime.context.errors { service_unavailable }
        return service_unavailable(service_entry.name, "not accepting traffic");
    }
    query: str = str(request.url.query);
    base: str = base_url or self.service_base_url(service_entry);
    target_url: str = f"{base}{path}";
    if query {
        target_url = f"{target_url}?{query}";
    }
    logger.info(f"Forward: {request.method} {path} -> {target_url}");
    return await self.forward_to(request, service_entry, target_url);
}

impl MicroserviceGateway.deliver_once(request: Request, path: str) -> Response | None {
    eligible = self.eligible_services();
    if not eligible {
        import from jaclang.scale.runtime.context.errors { not_found }
        return not_found(path, message="Not found on any service");
    }

    ready = [
        (name, svc)
        for (name, svc) in eligible
        if svc.status == ServiceStatus.HEALTHY
    ];
    pool = ready or eligible;
    for (_app_name, candidate) in pool {
        if candidate.owns_root() {
            return await self.forward_root_path(request, candidate, path);
        }
    }
    (_name, svc) = pool[0];
    return await self.forward_root_path(request, svc, path);
}

impl MicroserviceGateway.probe_services(
    request: Request, path: str, candidates: list[tuple[str, ServiceEntry]]
) -> Response {
    import from jaclang.scale.runtime.context.util { http_forward_timeout }
    import from jaclang.scale.runtime.transport.http_forward { stream_forward }

    fwd_headers = self.build_forward_headers(request);
    body: bytes = request.body;
    query: str = str(request.url.query);

    ordered: list[tuple[str, ServiceEntry]] = sorted(
        candidates,
        key=lambda (pair: tuple) { (
            0 if pair[1].is_root else 1,
            0 if pair[1].status == ServiceStatus.HEALTHY else 1
        ); }
    );
    for (svc_name, svc_entry) in ordered {
        base: str = svc_entry.page_url
            if (svc_entry.owns_root() and svc_entry.page_url)
            else self.service_base_url(svc_entry);
        target_url = f"{base}{path}";
        if query {
            target_url = f"{target_url}?{query}";
        }
        logger.info(f"Probe: {request.method} {path} -> {target_url}");

        fr = await stream_forward(
            request.method,
            target_url,
            fwd_headers,
            body,
            timeout=int(http_forward_timeout(svc_name))
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
    import from jaclang.scale.runtime.context.errors { not_found }
    return not_found(path, message="Not found on any service");
}

impl MicroserviceGateway.handle_admin(path: str) -> Response | None {
    if path == "/admin" {
        import from jaclang.server.serving.datatypes { RedirectResponse }
        return RedirectResponse(url="/admin/", status_code=302);
    }
    if path.startswith("/admin/") {
        asset_path: str = path[7:];
        return self.serve_admin_asset(asset_path);
    }
    return None;
}

impl MicroserviceGateway.forward_to(
    request: Request, service_entry: ServiceEntry, target_url: str
) -> Response | None {
    import from jaclang.scale.runtime.context.errors {
        service_unavailable,
        gateway_timeout
    }
    import from jaclang.scale.runtime.transport.http_forward { stream_forward }
    import from jaclang.scale.runtime.context.util { http_forward_timeout }

    if service_entry.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
        return service_unavailable(service_entry.name, service_entry.status.value);
    }

    fwd_headers = self.build_forward_headers(request);
    body: bytes = request.body;

    timeout = http_forward_timeout(service_entry.name);
    fr = await stream_forward(
        request.method, target_url, fwd_headers, body, timeout=int(timeout)
    );
    if fr is None {
        return gateway_timeout(service_entry.name);
    }
    return fr.to_response();
}

impl MicroserviceGateway.handle_proxy(request: Request, path: str) -> Response | None {
    svc = self.registry.match_route(path);
    if not svc {
        return None;
    }
    target_url = self.resolve_target_url(svc, path, str(request.url.query));
    logger.info(f"Proxy: {request.method} {path} -> {target_url}");
    return await self.forward_to(request, svc, target_url);
}

impl MicroserviceGateway.refresh_app_routes -> bool {
    import asyncio;
    import time;
    import from jaclang.scale.runtime.gateway.route_table { learn_service_routes }
    import from jaclang.scale.runtime.context.util { route_refresh_seconds }

    crawl = self._spec_crawl;
    if crawl is None or crawl.done() {
        crawl = asyncio.ensure_future(
            learn_service_routes(
                self.registry,
                self.route_table,
                time.monotonic(),
                route_refresh_seconds()
            )
        );
        self._spec_crawl = crawl;
    }
    try {
        attempted: int = await asyncio.shield(crawl);
    } except asyncio.CancelledError {
        raise;
    } except Exception as e {
        logger.warning(f"Route learning failed: {type(e).__name__}: {e}");
        return False;
    }
    if attempted {
        logger.info(
            f"Learned {len(self.route_table.prefixes())} root route(s) "
            f"after asking {attempted} service(s)"
        );
    }
    return attempted > 0;
}

impl MicroserviceGateway.handle_app_route(
    request: Request, path: str
) -> Response | None {
    svc = await self.resolve_learned_owner(path);
    if svc is None {
        return None;
    }
    return await self.forward_root_path(request, svc, path);
}

impl MicroserviceGateway.handle_openapi -> Response {
    import from jaclang.scale.runtime.gateway.openapi_agg { aggregate_openapi }
    doc = await aggregate_openapi(self.registry);
    return JSONResponse(status_code=200, content=doc);
}

impl MicroserviceGateway.handle_docs -> Response {
    import from jaclang.server.serving.openapi { swagger_ui_html }
    return HTMLResponse(content=swagger_ui_html("/openapi.json", "Jac Gateway - API"));
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
    if not file_path {
        return None;
    }

    mount_matched = False;
    for mount in self.static_mounts {
        prefix = str(mount.get("url_prefix", "")).lstrip("/").rstrip("/");
        if not prefix or file_path == prefix {
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
        return self.serve_project_static(file_path[len("static/"):]);
    }
    return None;
}

impl MicroserviceGateway.handle_spa_fallback(
    request: Request, path: str
) -> Response | None {
    if request.method != "GET" {
        return None;
    }
    if not path.lstrip("/") {
        return self.serve_spa_fallback();
    }
    if "text/html" in request.headers.get("accept", "") {
        return self.serve_spa_fallback();
    }
    return None;
}

impl MicroserviceGateway.setup -> ServingApp {
    import time;
    self.app = ServingApp(title="Jac Gateway");
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
    import from jaclang.scale.runtime.middleware.metrics { build_gateway_metrics }
    import from jaclang.scale.config.config_loader { get_scale_config }
    mon_cfg = get_scale_config().get_monitoring_config();
    import from jaclang.scale.runtime.context.log_emit { install_structured_logging }
    install_structured_logging();
    (self._metrics_registry, self._metrics_requests, self._metrics_duration) = (
        build_gateway_metrics(
            namespace=mon_cfg.get("namespace", "jaclang_scale"),
            histogram_buckets=mon_cfg.get("histogram_buckets")
        )
    );

    import from jaclang.scale.observability.factory { UtilityFactory }
    self._metrics = UtilityFactory.create_metrics('prometheus', mon_cfg);

    import from jaclang.scale.runtime.context.tracing {
        install_tracing,
        start_server_span,
        end_span
    }
    trc_cfg = get_scale_config().get_gateway_config().get("tracing", {});
    install_tracing(
        enabled=trc_cfg.get("enabled", False),
        endpoint=trc_cfg.get("endpoint"),
        sample_ratio=float(trc_cfg.get("sample_ratio", 1.0))
    );

    async def dispatcher(request: Request, call_next: object) -> Response {
        next_fn: any = call_next;
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
                ROUTE_IDENTITY,
                ROUTE_PROXY,
                ROUTE_CLIENT_PAGE
            }
            service_prefixes: list = [e.prefix for e in gw.registry.entries.values()];
            decision = classify_route(
                path, service_prefixes, client_pages=gw.has_client_bundle()
            );

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
            } elif decision.kind == ROUTE_CLIENT_PAGE {
                page_resp: Response | None = None;
                root_svc = gw.root_member();
                if request.method == "GET"
                    and (root_svc is None or not root_svc.owns_root()) {
                    page_resp = gw.serve_spa_fallback();
                    if page_resp is None {
                        import from jaclang.scale.runtime.context.errors { not_found }
                        page_resp = not_found(path);
                    }
                }
                if page_resp is not None {
                    svc_label = "__static__";
                    resp = page_resp;
                }
            } elif decision.kind == ROUTE_ADMIN {
                svc_label = "__admin__";
                admin_resp: Response | None = None;
                if gw.server is not None {
                    admin_resp = await next_fn(request);
                } else {
                    admin_resp = gw.handle_admin(path);
                }
                if admin_resp is None {
                    import from jaclang.scale.runtime.context.errors { not_found }
                    admin_resp = not_found(path);
                }
                resp = admin_resp;
            } elif decision.kind == ROUTE_IDENTITY {
                if gw.server is not None {
                    ident_resp = await next_fn(request);
                    if ident_resp.status_code not in (404, 405) {
                        svc_label = "__identity__";
                        resp = ident_resp;
                    }
                }
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
                app_resp = await gw.handle_app_route(request, path);
                if app_resp is not None {
                    svc_label = gw.route_table.owner(path) or "__app_route__";
                    resp = app_resp;
                }
            }
            if resp is None {
                served_by_root = await gw.forward_to_root(request, path);
                if served_by_root is not None {
                    svc_label = gw.registry.root_app or "__root__";
                    resp = served_by_root;
                }
            }
            if resp is None {
                static_from_root = await gw.forward_static_to_root(request, path);
                if static_from_root is not None {
                    svc_label = gw.registry.root_app or "__root__";
                    resp = static_from_root;
                }
            }
            if resp is None {
                spa_resp = gw.handle_spa_fallback(request, path);
                if spa_resp is not None {
                    svc_label = "__static__";
                    resp = spa_resp;
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
            if gw._metrics is not None and gw._metrics.is_enabled() {
                gw._metrics.record_request(
                    request.method, path, resp.status_code, time.time() - start
                );
            }
            return resp;
        } finally {
            end_span(span);
            reset_current_trace(tok);
        }
    }

    self.app.add_middleware(dispatcher);

    import from jaclang.scale.runtime.middleware.middleware {
        Middleware,
        MiddlewareRegistry
    }
    registry = MiddlewareRegistry();

    import from jaclang.server.serving.drain { drain_middleware }
    registry.register(
        Middleware(
            name="drain", priority=20, fn=drain_middleware(self.drain, "__gateway__")
        )
    );

    import from jaclang.scale.config.config_loader { get_scale_config }
    gw_cfg = get_scale_config().get_gateway_config();

    import from jaclang.scale.runtime.middleware.rate_limit {
        build_rate_limit_middleware
    }
    rl_mw = build_rate_limit_middleware(gw_cfg.get("rate_limit", {}));
    if rl_mw is not None {
        registry.register(Middleware(name="rate_limit", priority=10, fn=rl_mw));
    }

    registry.install(self.app);

    cors_cfg = gw_cfg.get("cors", {});
    if cors_cfg.get("allow_origins") {
        import from jaclang.server.serving.middleware { cors_middleware }
        self.app.add_middleware(
            cors_middleware(
                allow_origins=cors_cfg["allow_origins"],
                allow_methods=cors_cfg.get("allow_methods", ["*"]),
                allow_headers=cors_cfg.get("allow_headers", ["*"]),
                allow_credentials=cors_cfg.get("allow_credentials", False),
                expose_headers=cors_cfg.get("expose_headers", []),
                max_age=cors_cfg.get("max_age", 600)
            )
        );
    }
    _install_ws_catchall(self);

    return self.app;
}

def _log_gateway_ready(host: str, bound: int) {
    logger.info(f"Gateway starting on {host}:{bound}");
}


impl MicroserviceGateway.start(on_ready: any = None) -> None {
    import from jaclang.server.net { PORT_RETRY_LIMIT }
    import from jaclang.server.serving.server { ServingServer }
    import from jaclang.server.settings { ServeSettings }

    if self.app is None {
        self.setup();
    }
    settings = ServeSettings.load(
        self.base_path,
        {'host': self.host, 'port': self.port, 'strict_port': self.port_pinned}
    );
    self.drain.timeout = settings.timeouts.drain;
    serving = ServingServer(app=self.app, settings=settings, drain=self.drain);
    import from functools { partial }
    ready: any = on_ready;
    if ready is None {
        ready = partial(_log_gateway_ready, self.host);
    }
    serving.run(
        on_ready=ready, port_retries=0 if self.port_pinned else PORT_RETRY_LIMIT
    );
}


impl MicroserviceGateway.add_endpoint(ep: JEndPoint) -> None {
    self.app.add_endpoint(ep);
}

impl MicroserviceGateway.identity -> UserManager {
    if self.user_manager is None {
        self.user_manager = UserManager(base_path=self.base_path);
    }
    return self.user_manager;
}


impl MicroserviceGateway._install_admin_api -> None {
    import from jaclang.server.endpoints.auth { register_auth_endpoints }
    import from jaclang.server.middleware { jwt_middleware }
    import from jaclang.server.identity.config { configure_identity }
    import from jaclang.server.settings { ServeSettings }

    settings = ServeSettings.load(self.base_path);
    configure_identity(settings.auth, self.base_path);
    self.server = self;
    self.user_manager = self.identity();
    self.app.add_middleware(jwt_middleware(self.user_manager));

    self.register_admin_endpoints();
    self.register_logs_endpoints();
    self.register_llm_telemetry_endpoints();
    self.register_workloads_endpoints();

    self.register_traces_endpoints();
    self.register_ops_endpoints();
    self.register_deploy_health_endpoints();
    self.register_network_endpoints();
    self.register_podenv_endpoints();

    register_auth_endpoints(self);

    logger.info(
        "Admin JSON API installed on gateway "
        "(/admin/login, /admin/me, /admin/users, /admin/workloads/*, /admin/logs/*, ...)"
    );
    logger.info(
        "Gateway-owned identity installed "
        "(/user/register, /user/login, /user/me served by the gateway)"
    );
}
