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
    import from jac_scale.microservices.gateway_internals.middleware.ws_forward {
        websocket_forward
    }
    import from jac_scale.microservices.gateway_internals.drain { is_draining }
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

"""Bootstrap admin UI - copy pre-built React bundle to admin_dist_dir
if needed.

Skips when the destination index.html is at least as new as the source,
so normal restarts don't re-copy. Refreshes on package upgrade (source
newer) or cold start (destination missing).

Renamed from `bootstrap_admin` (A-05c) so it doesn't shadow
`JacAPIServerAdmin.bootstrap_admin` once `MicroserviceGateway` inherits
that mixin to register admin JSON endpoints. The two are complementary:
this stages static assets; the inherited one creates the default admin
user record.
"""
impl MicroserviceGateway.bootstrap_admin_ui -> None {
    admin_dist = Path(self.admin_dist_dir);
    dest_index = admin_dist / "index.html";

    try {
        import from jac_scale.admin { admin_portal }
        admin_pkg_dir = Path(admin_portal.__file__).parent;
        bundled_dist = admin_pkg_dir / "_dist";
        src_index = bundled_dist / "index.html";

        if not (bundled_dist.exists() and src_index.exists()) {
            # Editable install path: jac-scale was installed via
            # `pip install -e`, so the release pipeline that pre-builds
            # `_dist/` never ran. If the destination already has an
            # index.html (test fixture, previous boot, manual build),
            # respect it; otherwise fall back to the inherited
            # `build_admin_client` which invokes `jac build main.jac`
            # in `admin/ui/`. Drops the need for jacBuilder-style
            # `RUN jac run scripts/build_admin_ui.jac` workarounds.
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
     # Bare (no trailing slash) built-in routes. These exist as exact
     # paths in the monolith but their `/foo/` prefix sibling would NOT
     # match them via startswith: "/jobs" does not start with "/jobs/".
     # - /user, /graph: bare GET views
     # - /jobs: scheduler POST (create) + GET (list); /jobs/{id} is
     #   already covered by the "/jobs/" prefix above.
     _BUILTIN_EXACT: set[str] = {"/user", "/graph", "/jobs"};

"""Copy incoming request headers, dropping hop-by-hop headers.

Also ensures X-Trace-Id is present on every forwarded request (either
the inbound one or a freshly-minted UUID). Downstream services pick
it up and thread it through their own logs + sv-import RPC calls.
"""
impl MicroserviceGateway.build_forward_headers(request: Request) -> dict[str, str] {
    import from jac_scale.microservices.runtime.trace_ctx {
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
    # O-02: forward the active SERVER span's W3C `traceparent` so the
    # downstream hop's span links as our child (same trace id as
    # X-Trace-Id above). Overwrites any inbound traceparent that was
    # copied in the loop. No-op when tracing is off and no id is
    # available (current_traceparent returns None).
    import from jac_scale.microservices.runtime.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        fwd["traceparent"] = tp;
    }
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
    import from jac_scale.microservices.gateway_internals.drain { is_draining }
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

            import from jac_scale.microservices.runtime.util { http_forward_timeout }
            import from jac_scale.microservices.impl.http_forward { stream_forward }
            timeout = http_forward_timeout(svc_name);
            # stream_forward (not raw_forward) so a streaming response - SSE
            # from a /function/* generator served to the client - passes
            # through frame-by-frame instead of being buffered to completion.
            # The upstream status is known from the response head before the
            # body, so the 404/405 "try the next service" fan-out still works:
            # release the connection and move on without draining the body.
            fr = await stream_forward(
                request.method, target_url, fwd_headers, body, timeout=int(timeout)
            );
            if fr is None {
                # Transport error (e.g. ServerDisconnectedError) talking
                # to a service we know is healthy. Surfacing this as a
                # 503 keeps the caller from receiving a misleading 405
                # from a sibling service that doesn't own the route.
                import from jac_scale.microservices.runtime.errors {
                    service_unavailable
                }
                return service_unavailable(svc_name, "transport_error");
            }
            # 404 = "I don't have this walker"; 405 = "I have the path
            # but not this method". Both mean "not my route" in the
            # fan-out context, so release this upstream and try the next.
            if fr.status in (404, 405) {
                await fr.cleanup();
                continue;
            }
            return fr.to_response();
        }
    }
    import from jac_scale.microservices.runtime.errors { not_found }
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

    import from jac_scale.microservices.runtime.errors {
        service_unavailable,
        gateway_timeout
    }
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

    import from jac_scale.microservices.runtime.util { http_forward_timeout }
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
    import from jac_scale.microservices.gateway_internals.openapi_agg {
        aggregate_openapi
    }
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
    import from jac_scale.microservices.gateway_internals.middleware.metrics {
        render_metrics
    }
    import from jac_scale.microservices.runtime.errors { error_response }
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

    self.bootstrap_admin_ui();
    # A-05c: register the admin JSON endpoints (/admin/login, /admin/me,
    # /admin/users, etc.) on this gateway's FastAPI app so the admin
    # React bundle can actually authenticate + hit its APIs.
    # Without this, the static UI loads but every API call falls through
    # to the SPA-fallback and React gets HTML where it expected JSON.
    # Failure is non-fatal: in environments without Mongo/Redis (raw dev
    # mode), the gateway still serves traffic, just without admin auth.
    try {
        self._install_admin_api();
    } except Exception as e {
        # Roll back any partial install (self.server gets assigned
        # before any of the calls that can fail like UserManager init).
        # Without this reset, the dispatcher would see server != None and
        # delegate /admin/* to FastAPI even though no routes were
        # registered, breaking the static-UI fallback.
        self.server = None;
        logger.warning(
            "Admin JSON API not installed - admin UI will be read-only "
            f"static. Cause: {type(e).__name__}: {e}"
        );
    }

    # Install the trace-id log filter + JSON formatter (M-14.b) so
    # every log line emitted by the gateway becomes one-line JSON on
    # stdout with `service` / `level` / `trace_id` as queryable fields.
    # `install_structured_logging` is idempotent and also calls
    # `install_trace_log_filter` internally; we still import the trace
    # helpers below because the dispatcher middleware uses them directly.
    import from jac_scale.microservices.runtime.trace_ctx {
        set_current_trace,
        reset_current_trace,
        ensure_trace_id
    }
    import from jac_scale.microservices.runtime.log_emit { install_structured_logging }
    install_structured_logging();

    # Build Prometheus metrics (no-ops when prometheus_client is not
    # installed). Only initialized once per gateway instance; spawning
    # a fresh gateway in tests gets a fresh registry to avoid
    # "Duplicated timeseries" errors.
    import from jac_scale.microservices.gateway_internals.middleware.metrics {
        build_gateway_metrics
    }
    import from jac_scale.config_loader { get_scale_config }
    mon_cfg = get_scale_config().get_monitoring_config();
    (self._metrics_registry, self._metrics_requests, self._metrics_duration) = (
        build_gateway_metrics(
            namespace=mon_cfg.get("namespace", "jac_scale"),
            histogram_buckets=mon_cfg.get("histogram_buckets")
        )
    );

    # O-02: configure tracing once per process (no-op when disabled /
    # jac-scale[tracing] absent); the dispatcher opens a span per request.
    import from jac_scale.microservices.runtime.tracing {
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

        # Stamp the request with a trace id (preserving any inbound
        # X-Trace-Id so clients can correlate upstream logs). The
        # ContextVar is read by build_forward_headers for proxy +
        # passthrough calls, and by downstream jfast_api middleware
        # when the request lands on each service.
        trace_id = ensure_trace_id(request.headers.get("X-Trace-Id"));
        tok = set_current_trace(trace_id);

        # O-02: open one SERVER span per request (None when inactive).
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
            } elif path == "/admin" or path.startswith("/admin/") {
                # A-05c: when the admin JSON API has been installed,
                # JFastApiServer has registered FastAPI routes for
                # /admin/login, /admin/me, /admin/users, etc., plus a
                # catchall `/admin/{path:path}` that performs SPA asset
                # + index.html fallback. Delegate to FastAPI's
                # router via call_next so those routes can match. If
                # the install failed (Mongo unreachable etc.), fall
                # back to the static-asset handler so the UI still
                # loads read-only.
                svc_label = "__admin__";
                admin_resp: Response | None = None;
                if gw.server is not None {
                    admin_resp = await call_next(request);
                } else {
                    admin_resp = gw.handle_admin(path);
                }
                if admin_resp is None {
                    import from jac_scale.microservices.runtime.errors { not_found }
                    admin_resp = not_found(path);
                }
                resp = admin_resp;
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
                    static_resp = gw.handle_static(request, path);
                    if static_resp is not None {
                        svc_label = "__static__";
                        resp = static_resp;
                    }
                }
                if resp is None {
                    import from jac_scale.microservices.runtime.errors { not_found }
                    resp = not_found(path);
                }
            }
            # Echo trace id so clients can correlate and our e2e can
            # verify end-to-end propagation across the gateway hop.
            resp.headers["X-Trace-Id"] = trace_id;
            # O-02: record the outcome on the SERVER span.
            if span is not None {
                span.set_attribute("http.status_code", resp.status_code);
                span.set_attribute("jac.service", svc_label);
            }
            # Prometheus metrics (no-op when prometheus_client absent).
            if gw._metrics_requests is not None {
                import from jac_scale.microservices.gateway_internals.middleware.metrics {
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
            # End the SERVER span (flushes it to the exporter) and clear
            # the per-request traceparent before resetting the trace ctx.
            end_span(span);
            reset_current_trace(tok);
        }
    }

    _install_ws_catchall(self);

    # Drain registered LAST so Starlette's insert(0, ...) puts it as
    # the outermost HTTP middleware - 503s short-circuit before the
    # dispatcher stamps metrics or trace-ids.
    import from jac_scale.microservices.gateway_internals.drain {
        build_drain_middleware
    }
    self.app.middleware("http")(build_drain_middleware("__gateway__"));

    import from jac_scale.config_loader { get_scale_config }
    ms_cfg = get_scale_config().get_microservices_config();

    # rate limit between drain and CORS. Preflights bypass the
    # limiter (CORS outer handles OPTIONS short-circuit) and drain
    # inner can still 503 once the limiter allows through.
    import from jac_scale.microservices.gateway_internals.middleware.rate_limit {
        build_rate_limit_middleware
    }
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
    import from jac_scale.microservices.gateway_internals.drain { install_signal_drain }
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


"""A-05c: install the admin JSON endpoints on this gateway's FastAPI app.

Creates a `JFastApiServer` instance that *wraps the gateway's existing
FastAPI app* (instead of constructing a new one), then calls the
`register_admin_endpoints` (JacAPIServerAdmin) + `register_logs_endpoints`
(JacAPIServerLogs) + `register_llm_telemetry_endpoints`
(JacAPIServerLLMTelemetry) methods. They queue JEndPoints via
`self.server.add_endpoint(...)` which the subsequent
`self.server.create_server()` materializes into actual FastAPI routes
on `self.server.app` - same object as `self.app`, so the admin routes
coexist with the gateway's dispatcher middleware.

Failure modes (any exception bubbles up to caller's try/except):
  - Mongo unreachable: UserManager init can't bootstrap; admin auth dead
  - `jac_scale.admin` import failure: no admin module bundled in this
    install path (theoretical; only happens if jac-scale is installed
    without the admin submodule)
  - JFastApiServer middleware double-attach: gateway already has a
    middleware stack; the JFastApi `jwt_validation_middleware` it adds
    overlays before our dispatcher in the FastAPI middleware order. This
    means admin Authorization headers get validated before the dispatcher
    sees the request - intentional, the dispatcher relies on the JWT
    decode having already populated request.state.

Side-effect: any subsequent request to /admin/* on the gateway carries
JWT validation. /admin/login and /admin/reset-password are explicitly
exempted by JFastApiServer's middleware (they need to issue tokens, so
they bypass the validate-then-extract flow).
"""
impl MicroserviceGateway._install_admin_api -> None {
    import from jac_scale.jserver.jfast_api { JFastApiServer }
    import from jac_scale.webhook { ApiKeyManager }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    # 1. JFastApiServer wrapping OUR FastAPI app. The constructor accepts
    #    an existing app, so JEndPoint registrations land on this gateway.
    self.server = JFastApiServer(app=self.app);

    # 2. UserManager + ApiKeyManager - the same pattern JacAPIServerCore
    #    .postinit uses for the monolith. UserManager picks Mongo when
    #    MONGODB_URI is set (K8s default), shelf-DB fallback otherwise.
    self.user_manager = Jac.get_user_manager(base_path=self.base_path);
    self.server.set_user_manager(self.user_manager);
    self._api_key_manager = ApiKeyManager();

    # 3. Queue the JSON endpoints. Each call appends JEndPoint specs
    #    to self.server._endpoints (no FastAPI route is created yet).
    #    register_admin_endpoints comes from JacAPIServerAdmin (A-05c);
    #    register_logs_endpoints from JacAPIServerLogs (A-05a) - the
    #    /admin/logs/* Loki-query endpoints the in-admin Logs UI hits;
    #    register_llm_telemetry_endpoints from JacAPIServerLLMTelemetry -
    #    the /admin/llm/telemetry/* endpoints the in-admin LLM metrics UI
    #    hits. Mirrors the monolith's _register_endpoints (serve.core)
    #    which calls all three.
    self.register_admin_endpoints();
    self.register_logs_endpoints();
    self.register_llm_telemetry_endpoints();
    # /admin/traces/* (Tempo proxy) for the in-admin Traces page.
    self.register_traces_endpoints();
    self.register_ops_endpoints();
    self.register_deploy_health_endpoints();
    self.register_network_endpoints();
    self.register_podenv_endpoints();

    # 4. Materialize the queued endpoints as actual FastAPI routes.
    #    JFastApiServer.add_endpoint() only enqueues; create_server()
    #    runs execute() which calls _create_fastapi_route() for every
    #    queued JEndPoint. Without this step the routes never exist
    #    on the app and the dispatcher's call_next sees only 404s
    #    (or the SPA catchall serves index.html -> the React Logs page
    #    gets HTML where it expected JSON and spins on "Loading logs...").
    self.server.create_server();

    logger.info(
        "Admin JSON API installed on gateway "
        "(/admin/login, /admin/me, /admin/users, /admin/logs/*, ...)"
    );
}
