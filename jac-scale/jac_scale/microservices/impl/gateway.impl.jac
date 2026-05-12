"""Implementation of MicroserviceGateway methods."""

import shutil;
# WebSocket import must stay at module scope. Jac emits
# `from __future__ import annotations`; FastAPI's WS dependency
# detection does `get_type_hints(endpoint)` against the endpoint's
# `__globals__`, so the `WebSocket` name needs to be resolvable here,
# not just inside `_install_ws_catchall`.
import from fastapi { WebSocket }


"""Register the WebSocket catch-all proxy that dispatches via the
registry (matching prefix -> upstream URL). Close codes: 1012 drain,
1008 no route, 1013 unhealthy."""
def _install_ws_catchall(gw: object) {
    import from jac_scale.microservices._ws_forward { websocket_forward }
    import from jac_scale.microservices._drain { is_draining }
    import from jac_scale.microservices.service_registry { ServiceStatus }

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

"""Build the target URL by stripping prefix and forwarding the rest.

Resolution order:
  1. JacRuntime.get_sv_registry()[module] - public hookspec (plugins can
     override; KubernetesDeployer will return K8s DNS names here)
  2. service_entry.url - URL from our process manager
  3. Fallback: error (no known URL)
"""
impl MicroserviceGateway.resolve_target_url(
    service_entry: ServiceEntry, path: str, query: str
) -> str {
    import jaclang;

    # Use the public hookspec; plugins can swap the URL source without
    # the gateway knowing (jaclang core returns sv_client._registry by
    # default; jac-scale's KubernetesDeployer will return DNS URLs).
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

"""Serve a static file from the client dist directory. Returns None if not found."""
impl MicroserviceGateway.serve_static(file_path: str) -> Response | None {
    dist = Path(self.client_dist_dir);
    target = dist / file_path;

    try {
        resolved = target.resolve();
        dist_resolved = dist.resolve();
        # Path-containment, NOT string-prefix: startswith would match a
        # sibling directory whose name happens to begin with the dist
        # path (e.g. /var/app/dist_secrets vs /var/app/dist).
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

"""Serve a static file from a configured static_mounts local directory.
Path-jails to local_dir (rejects symlink/.. escapes via realpath compare).
Returns None if not found, not a regular file, or outside the jail."""
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


"""Serve index.html for SPA fallback. Returns None if no index.html exists."""
impl MicroserviceGateway.serve_spa_fallback -> Response | None {
    index = Path(self.client_dist_dir) / "index.html";
    if index.is_file() {
        return HTMLResponse(content=index.read_text(encoding="utf-8"));
    }
    return None;
}

"""Bootstrap admin UI - copy pre-built bundle to admin_dist_dir if needed.

Skips when the destination index.html is at least as new as the source,
so normal restarts don't re-copy. Refreshes on package upgrade (source
newer) or cold start (destination missing).
"""
impl MicroserviceGateway.bootstrap_admin -> None {
    admin_dist = Path(self.admin_dist_dir);
    dest_index = admin_dist / "index.html";

    try {
        import from jac_scale.admin { admin_portal }
        admin_pkg_dir = Path(admin_portal.__file__).parent;
        bundled_dist = admin_pkg_dir / "_dist";
        src_index = bundled_dist / "index.html";

        if not (bundled_dist.exists() and src_index.exists()) {
            logger.debug("No pre-built admin UI found in package");
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

"""Serve an admin asset by path. Returns None if not found."""
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

"""Paths whose handling is "try every healthy service until non-404"."""
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
     _BUILTIN_EXACT: set[str] = {"/user","/graph"};

"""Copy incoming request headers, dropping hop-by-hop headers.

Also ensures X-Trace-Id is present on every forwarded request (either
the inbound one or a freshly-minted UUID). Downstream services pick
it up and thread it through their own logs + sv-import RPC calls.
"""
impl MicroserviceGateway.build_forward_headers(request: Request) -> dict[str, str] {
    import from jac_scale.microservices._trace_ctx {
        get_current_trace,
        ensure_trace_id
    }
    fwd: dict[str, str] = {};
    for (key, value) in request.headers.items() {
        if key.lower() not in HOP_BY_HOP_HEADERS {
            fwd[key] = value;
        }
    }
    # Trace-Id is set by the gateway's dispatcher (handle_health path
    # and below). Fall back to the incoming header if the ContextVar
    # isn't set (defensive; shouldn't happen in the dispatcher path).
    trace = get_current_trace() or ensure_trace_id(request.headers.get("X-Trace-Id"));
    fwd["X-Trace-Id"] = trace;
    return fwd;
}

"""Health endpoint - returns registry summary."""
impl MicroserviceGateway.handle_health -> Response {
    return JSONResponse(
        status_code=200,
        content={"status": "healthy", "services": self.registry.health_summary()}
    );
}


"""Liveness endpoint - 200 if the process is alive, ALWAYS.

Liveness gates pod restart. We deliberately don't check anything that
could fail other than the dispatcher itself responding. Checking
dependencies here would let a transient DB blip cascade into a kubelet
restart, which then blips more pods, which can spiral. K8s convention:
liveness = "is the container hung", not "is it usable."
"""
impl MicroserviceGateway.handle_health_live -> Response {
    return JSONResponse(status_code=200, content={"status": "alive"});
}


"""Readiness endpoint - 200 normally, 503 during drain.

Readiness gates traffic. When SIGTERM hits, our drain middleware flips
`is_draining()` true and the readiness probe starts failing; kube-proxy
removes the pod from Endpoints within a probe period or two so new
requests stop arriving while in-flight ones complete. Pair with the
preStop sleep (bridges the kube-proxy-propagation gap) and
terminationGracePeriodSeconds (gives drain time to flush).
"""
impl MicroserviceGateway.handle_health_ready -> Response {
    import from jac_scale.microservices._drain { is_draining }
    if is_draining() {
        return JSONResponse(
            status_code=503, content={"status": "draining", "ready": False}
        );
    }
    return JSONResponse(status_code=200, content={"status": "ready"});
}

"""Built-in jac-scale routes (/user/*, /walker/*, /function/*, etc.).

Each service only has its own walkers/functions, so we try every healthy
service until one returns non-404. Returns None if `path` isn't a built-in.
"""
impl MicroserviceGateway.handle_builtin_passthrough(
    request: Request, path: str
) -> Response | None {
    is_builtin = path.startswith(_BUILTIN_PREFIXES) or path in _BUILTIN_EXACT;
    if not is_builtin {
        return None;
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

            import from jac_scale.microservices._util { http_forward_timeout }
            timeout = http_forward_timeout(svc_name);
            result = await raw_forward(
                request.method, target_url, fwd_headers, body, timeout=int(timeout)
            );
            if result is None {
                # Transport error (e.g. ServerDisconnectedError) talking
                # to a service we know is healthy. Surfacing this as a
                # 503 keeps the caller from receiving a misleading 405
                # from a sibling service that doesn't own the route.
                import from jac_scale.microservices._errors { service_unavailable }
                return service_unavailable(svc_name, "transport_error");
            }
            (sc, rh, rb) = result;
            # 404 = "I don't have this walker"; 405 = "I have the path
            # but not this method". Both mean "not my route" in the
            # fan-out context, so try the next healthy service.
            if sc in (404, 405) {
                continue;
            }
            return Response(status_code=sc, headers=rh, content=rb);
        }
    }
    import from jac_scale.microservices._errors { not_found }
    return not_found(path, message="Not found on any service");
}

"""Admin UI routes - /admin redirects, /admin/* serves assets."""
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

"""Proxy to the matched microservice. Returns None if no match, 503 if
unhealthy, 502 on transport failure. Streams the response (SSE /
chunked / large bodies pass through)."""
impl MicroserviceGateway.handle_proxy(request: Request, path: str) -> Response | None {
    svc = self.registry.match_route(path);
    if not svc {
        return None;
    }

    import from jac_scale.microservices._errors { service_unavailable, gateway_timeout }
    import from jac_scale.microservices.impl.http_forward { stream_forward }

    if svc.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
        return service_unavailable(svc.name, svc.status.value);
    }

    target_url = self.resolve_target_url(svc, path, str(request.url.query));
    logger.info(f"Proxy: {request.method} {path} -> {target_url}");

    fwd_headers = self.build_forward_headers(request);
    client_addr: str = getattr(request?.client, "host", "unknown");
    fwd_headers["X-Forwarded-For"] = client_addr;

    body: bytes = await request.body();

    import from jac_scale.microservices._util { http_forward_timeout }
    timeout = http_forward_timeout(svc.name);
    fr = await stream_forward(
        request.method, target_url, fwd_headers, body, timeout=int(timeout)
    );
    if fr is None {
        return gateway_timeout(svc.name);
    }
    return fr.to_response();
}

"""Return the aggregated OpenAPI schema across all healthy services.

Fetches each service's /openapi.json, prefixes its paths with the
service's gateway route, and merges. See `_openapi_agg.aggregate_openapi`.
"""
impl MicroserviceGateway.handle_openapi -> Response {
    import from jac_scale.microservices._openapi_agg { aggregate_openapi }
    doc = await aggregate_openapi(self.registry);
    return JSONResponse(status_code=200, content=doc);
}

"""Render the Swagger UI page pointing at our aggregated /openapi.json."""
impl MicroserviceGateway.handle_docs -> Response {
    import from fastapi.openapi.docs { get_swagger_ui_html }
    return get_swagger_ui_html(
        openapi_url="/openapi.json", title="Jac Microservice Gateway - API"
    );
}

"""Serve the Prometheus exposition for this gateway's registry.

Returns 503 when prometheus_client is not installed (the 'monitoring'
extra wasn't pulled in). Path routing lands here when
`monitoring.enabled` is set in jac.toml; otherwise /metrics falls
through to passthrough as before.
"""
impl MicroserviceGateway.handle_metrics -> Response {
    import from jac_scale.microservices._metrics { render_metrics }
    import from jac_scale.microservices._errors { error_response }
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

"""Serve static files or SPA fallback for GET requests."""
impl MicroserviceGateway.handle_static(request: Request, path: str) -> Response | None {
    if request.method != "GET" {
        return None;
    }

    file_path: str = path.lstrip("/");
    if file_path {
        # Declarative static mounts are checked first: any URL matching a
        # configured `url_prefix` is served from the corresponding
        # `local_path`. Lets callers expose repo-root directories
        # (e.g. assets/) without restructuring the client build output.
        # First matching mount has canonical ownership of its URL prefix;
        # on file-miss inside that mount we surface a 404 instead of
        # falling through to dist_dir (which could mask the missing asset
        # behind a same-named file under dist).
        mount_matched = False;
        for mount in self.static_mounts {
            prefix = str(mount.get("url_prefix", "")).lstrip("/").rstrip("/");
            if not prefix {
                continue;
            }
            if file_path == prefix {
                # request is exactly the prefix — treat as a directory
                # listing request, which we don't serve. Defer to dist
                # or 404.
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
    } else {
        # GET / is the SPA root. Always serve dist/index.html when it
        # exists, regardless of Accept header (curl, monitoring probes,
        # server-side fetches, and crawlers all need to land somewhere
        # other than 404). Browsers reach the same response via the
        # text/html Accept fallback below; this branch makes
        # the behavior consistent across clients.
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

"""Create the FastAPI app and register the dispatcher middleware."""
impl MicroserviceGateway.setup -> FastAPI {
    import time;
    self.app = FastAPI(title="Jac Microservice Gateway");
    gw = self;

    self.bootstrap_admin();

    # Install the trace-id log filter once when the gateway starts up
    # so every subsequent log line gets a [trace=...] prefix.
    import from jac_scale.microservices._trace_ctx {
        install_trace_log_filter,
        set_current_trace,
        reset_current_trace,
        ensure_trace_id
    }
    install_trace_log_filter();

    # Build Prometheus metrics (no-ops when prometheus_client is not
    # installed). Only initialized once per gateway instance; spawning
    # a fresh gateway in tests gets a fresh registry to avoid
    # "Duplicated timeseries" errors.
    import from jac_scale.microservices._metrics { build_gateway_metrics }
    import from jac_scale.config_loader { get_scale_config }
    mon_cfg = get_scale_config().get_monitoring_config();
    (self._metrics_registry, self._metrics_requests, self._metrics_duration) = (
        build_gateway_metrics(
            namespace=mon_cfg.get("namespace", "jac_scale"),
            histogram_buckets=mon_cfg.get("histogram_buckets")
        )
    );

    @self.app.middleware("http")
    async def dispatcher(request: Request, call_next: object) -> Response {
        path: str = request.url.path;

        # Stamp the request with a trace id (preserving any inbound
        # X-Trace-Id so clients can correlate upstream logs). The
        # ContextVar is read by build_forward_headers for proxy +
        # passthrough calls, and by downstream jfast_api middleware
        # when the request lands on each service.
        trace_id = ensure_trace_id(request.headers.get("X-Trace-Id"));
        tok = set_current_trace(trace_id);

        start = time.time();
        svc_label: str = "__unmatched__";
        try {
            resp: Response | None = None;
            if path == "/healthz/live" {
                # K8s livenessProbe target. Always 200 if dispatcher runs.
                svc_label = "__health_live__";
                resp = gw.handle_health_live();
            } elif path == "/healthz/ready" {
                # K8s readinessProbe target. 503 during drain so kube-proxy
                # removes us from Endpoints before in-flight requests
                # finish; pair with preStop + terminationGracePeriodSeconds.
                svc_label = "__health_ready__";
                resp = gw.handle_health_ready();
            } elif path == "/health" or path == "/healthz" {
                # Backward-compat aliases. /healthz used to be the
                # combined probe target; now /healthz/live + /ready
                # serve K8s and /healthz keeps the registry-summary view
                # for humans / dashboards. /health is the legacy alias.
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
            } else {
                # Prefix-match first so we can label the service name on
                # proxy hits even before handle_proxy gets the Response.
                matched = gw.registry.match_route(path);
                if matched {
                    svc_label = matched.name;
                    resp = await gw.handle_proxy(request, path);
                }
                if resp is None {
                    builtin = await gw.handle_builtin_passthrough(request, path);
                    if builtin is not None {
                        svc_label = "__builtin__";
                        resp = builtin;
                    }
                }
                if resp is None {
                    admin = gw.handle_admin(path);
                    if admin is not None {
                        svc_label = "__admin__";
                        resp = admin;
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
                    import from jac_scale.microservices._errors { not_found }
                    resp = not_found(path);
                }
            }
            # Echo trace id so clients can correlate and our e2e can
            # verify end-to-end propagation across the gateway hop.
            resp.headers["X-Trace-Id"] = trace_id;
            # Prometheus metrics (no-op when prometheus_client absent).
            if gw._metrics_requests is not None {
                import from jac_scale.microservices._metrics { classify_outcome }
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
            reset_current_trace(tok);
        }
    }

    _install_ws_catchall(self);

    # Drain registered LAST so Starlette's insert(0, ...) puts it as
    # the outermost HTTP middleware - 503s short-circuit before the
    # dispatcher stamps metrics or trace-ids.
    import from jac_scale.microservices._drain { build_drain_middleware }
    self.app.middleware("http")(build_drain_middleware("__gateway__"));

    import from jac_scale.config_loader { get_scale_config }
    ms_cfg = get_scale_config().get_microservices_config();

    # rate limit between drain and CORS. Preflights bypass the
    # limiter (CORS outer handles OPTIONS short-circuit) and drain
    # inner can still 503 once the limiter allows through.
    import from jac_scale.microservices._rate_limit { build_rate_limit_middleware }
    rl_mw = build_rate_limit_middleware(ms_cfg.get("rate_limit", {}));
    if rl_mw is not None {
        self.app.middleware("http")(rl_mw);
    }

    # CORS registered AFTER drain so preflights answer correctly
    # even during shutdown (clients need CORS headers to read 503s).
    # Disabled unless `allow_origins` is configured.
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

"""Start the gateway (blocking). Uses Config+Server so install_signal_drain
can wrap `handle_exit` before the event loop starts."""
impl MicroserviceGateway.start -> None {
    import from jac_scale.microservices._drain { install_signal_drain }
    import from jac_scale.config_loader { get_scale_config }

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
