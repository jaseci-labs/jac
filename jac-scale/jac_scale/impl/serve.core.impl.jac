"""Core auth, user management, JWT, API keys, server start/postinit implementations."""
import socket;

"""Find an available port starting from the given port.

Returns the first available port, or raises OSError if none found within max_retries.
"""
impl _find_available_port(start_port: int, max_retries: int = PORT_RETRY_LIMIT) -> int {
    current_port = start_port;
    for _ in range(max_retries) {
        try {
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
                s.bind(('0.0.0.0', current_port));
            }
            return current_port;
        } except OSError as e {
            if e.errno in (ERRNO_ADDR_IN_USE_LINUX, ERRNO_ADDR_IN_USE_WINDOWS)
            or "Address already in use" in str(e) {
                current_port += 1;
            } else {
                raise;
            }
        }
    }
    raise OSError(
        f"Could not find an available port after trying {start_port}-{current_port}"
    );
}

"""Get local network IP addresses (non-localhost)."""
impl _get_network_ips -> list[str] {
    ips: list[str] = [];
    try {
        hostname = socket.gethostname();
        for addr in socket.getaddrinfo(hostname, None) {
            ip = addr[4][0];
            # Filter out localhost and IPv6
            if not ip.startswith('127.') and ':' not in ip {
                if ip not in ips {
                    ips.append(ip);
                }
            }
        }
    } except Exception {
    # Silently ignore network interface errors
    }
    return ips;
}

impl JacAPIServerCore.postinit -> None {
    super.postinit();
    # Support test mode (port=0): base postinit sets self.server = None,
    # but jac-scale needs a JFastApiServer for middleware/endpoint registration.
    if self.server is None {
        import from jac_scale.jserver.jfast_api { JFastApiServer }
        self.server = JFastApiServer();
    }
    self._api_key_manager = ApiKeyManager();
    self.server.app.add_middleware(
        CORSMiddleware,
        allow_origins=['*'],
        allow_credentials=True,
        allow_methods=['*'],
        allow_headers=['*']
    );
    # Add custom response headers from jac.toml [environments.response.headers]
    import from jaclang.project.config { JacConfig }
    import from starlette.middleware.base { BaseHTTPMiddleware }
    import from pathlib { Path }
    # Use base_path to find the correct jac.toml for this project
    start_path = Path(self.base_path) if self.base_path else None;
    config = JacConfig.discover(start_path);
    custom_headers: dict = {};
    if config
    and config.environments
    and "response" in config.environments
    and "headers" in config.environments["response"] {
        custom_headers = config.environments["response"]["headers"];
    }
    if custom_headers {
        class CustomHeadersMiddleware(BaseHTTPMiddleware) {
            async def dispatch(
                self: CustomHeadersMiddleware, request: Any, call_next: Any
            ) -> Any {
                response = await call_next(request);
                for (header_name, header_value) in custom_headers.items() {
                    response.headers[header_name] = header_value;
                }
                return response;
            }
        }
        self.server.app.add_middleware(CustomHeadersMiddleware);
    }
    # Initialize Prometheus metrics if enabled
    import from jac_scale.factories.utility_factory { UtilityFactory }
    metrics_config = get_scale_config().get_monitoring_config();
    self._metrics = UtilityFactory.create_metrics('prometheus', metrics_config);
    if self._metrics.is_enabled() {
        metrics_collector = self._metrics;
        metrics_endpoint = metrics_config.get('endpoint', '/metrics');
        # Add metrics middleware to track request timing
        class MetricsMiddleware(BaseHTTPMiddleware) {
            async def dispatch(
                self: MetricsMiddleware, request: Any, call_next: Any
            ) -> Any {
                # Skip metrics endpoint itself
                if request.url.path == metrics_endpoint {
                    return await call_next(request);
                }

                metrics_collector.request_started();
                start_time = time.perf_counter();

                try {
                    response = await call_next(request);
                    duration = time.perf_counter() - start_time;
                    metrics_collector.record_request(
                        request.method, request.url.path, response.status_code, duration
                    );
                    return response;
                } except Exception as e {
                    duration = time.perf_counter() - start_time;
                    metrics_collector.record_request(
                        request.method, request.url.path, 500, duration
                    );
                    raise;
                } finally {
                    metrics_collector.request_finished();
                }
            }
        }
        self.server.app.add_middleware(MetricsMiddleware);
        # Register /metrics endpoint (admin-only)
        metrics_handler = self._create_admin_metrics_handler(
            self._metrics.get_endpoint_handler()
        );
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=metrics_endpoint,
                callback=metrics_handler,
                parameters=[],
                response_model=None,
                tags=['Monitoring'],
                summary='Prometheus metrics (Admin only)',
                description='Exposes application metrics in Prometheus format for scraping. Requires admin authentication.'
            )
        );
        logger.info(f"Prometheus metrics enabled at {metrics_endpoint} (admin-only)");
    }
}

impl JacAPIServerCore.start(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[..., None] | None = None
) -> None {
    self.introspector.load();
    self._ensure_sv_siblings();
    # Eagerly build client bundle if there are client exports (skip in dev, no_client, or PWA mode)
    if not dev and not no_client {
        client_exports = self.introspector._client_manifest.get('exports', []);
        if client_exports {
            import sys;
            import from jaclang.project.config { get_config }
            config = get_config();
            dist_dir = config.get_client_dir() / 'dist' if config else None;
            is_pwa = dist_dir and (dist_dir / 'manifest.json').exists();
            if is_pwa {
                console.print("  ✔ PWA bundle already built", style="success");
            } else {
                start_time = time.time();
                try {
                    with console.status(
                        "[cyan]Building client bundle...[/cyan]", spinner="dots"
                    ) as status {
                        self.introspector.ensure_bundle();
                    }
                    elapsed = time.time() - start_time;
                    console.print(
                        f"  ✔ Client bundle ready ({elapsed:.1f}s)", style="success"
                    );
                } except Exception as e {
                    # Format error with diagnostics
                    error_output = str(e);
                    project_dir = config.project_root if config else Path.cwd();
                    formatted_error = Jac.format_build_error(
                        error_output=error_output,
                        project_dir=project_dir,
                        config=config
                    );
                    console.warning("Failed to build client bundle");
                    console.print(file=sys.stderr);
                    console.print(formatted_error, file=sys.stderr);
                    console.warning(
                        'Client pages will not be available until this is fixed.',
                        emoji=True
                    );
                    console.print(file=sys.stderr);
                    console.info(
                        'Try again after running: jac clean --all', emoji=True
                    );
                    console.info(
                        f'If it still doesn\'t work, ask for help at {JAC_DISCORD_URL}',
                        emoji=True
                    );
                }
            }
        }
    }
    server_config = get_scale_config().get_server_config();
    if not server_config.get('docs_enabled', True) {
        self.server.app.docs_url = None;
        self.server.app.openapi_url = None;
        self.server.app.redoc_url = None;
    }
    self._register_endpoints();
    if dev {
        # Add middleware to refresh endpoints on HMR file changes
        import from starlette.requests { Request as StarletteRequest }
        import from starlette.responses { Response as StarletteResponse }
        _self = self;
        @self.server.app.middleware("http")
        async def hmr_refresh_middleware(
            request: StarletteRequest, call_next: Any
        ) -> StarletteResponse {
            if _self._hmr_pending {
                _self._refresh_dev_endpoints();
            }
            return await call_next(request);
        }
    }
    self.user_manager.create_internal_user(Con.GUEST.value, '__no_password__');
    self._setup_scheduler();
    # Find an available port (may differ from requested if port is in use)
    original_port = self.port;
    self.port = _find_available_port(self.port);
    if self.port != original_port {
        console.print(
            f"  Port {original_port} is in use, using port {self.port} instead",
            style="warning"
        );
    }
    # Print startup banner with correct port
    self._print_startup_banner(dev, no_client);
    # Call the ready callback with the actual port (e.g., to print startup banner)
    if on_ready {
        on_ready(self.port);
    }
    self.server.run_server(port=self.port);
}

"""Print startup banner with correct port."""
impl JacAPIServerCore._print_startup_banner(dev: bool, no_client: bool) -> None {
    import from importlib.metadata { version as pkg_version }

    # Print header
    try {
        version = pkg_version('jaclang');
        console.print(f"\n  JAC DEV SERVER v{version}\n", style="bold cyan");
    } except Exception {
        console.print(f"\n  JAC DEV SERVER\n", style="bold cyan");
    }

    # Build URLs list (consistent with existing _print_startup_message pattern)
    urls: list[tuple[str, str]] = [];
    urls.append(("Local", f"http://localhost:{self.port}/"));
    for ip in _get_network_ips() {
        urls.append(("Network", f"http://{ip}:{self.port}/"));
    }

    # Print URLs with arrows (uses console.print_urls for consistency)
    console.print_urls(urls);
    console.print();
    console.print("  🚀 Server ready", style="bold green");
}

"""Configure OpenAPI security scheme to only apply to walker endpoints that require auth."""
impl JacAPIServerCore._configure_openapi_security -> None {
    import from fastapi.openapi.utils { get_openapi }
    def custom_openapi -> dict[str, Any] {
        if self.server.app.openapi_schema {
            return self.server.app.openapi_schema;
        }
        openapi_schema = get_openapi(
            title=self.server.app.title,
            version=self.server.app.version,
            routes=self.server.app.routes
        );
        openapi_schema['components'] = openapi_schema.get('components', {});
        openapi_schema['components']['securitySchemes'] = {
            'BearerAuth': {
                'type': 'http',
                'scheme': 'bearer',
                'bearerFormat': 'JWT',
                'description': "Enter your JWT token (without 'Bearer ' prefix)"
            }
        };
        for (path, path_item) in openapi_schema.get('paths', {}).items() {
            if path.startswith('/walker/') {
                path_parts = path.split('/');
                if (len(path_parts) >= 3) {
                    walker_name = path_parts[2].split('{')[0].rstrip('/');
                    if (
                        (walker_name in self.get_walkers())
                        and self.introspector.is_auth_required_for_walker(walker_name)
                    ) {
                        for method in path_item {
                            if (method in ['get', 'post', 'put', 'patch', 'delete']) {
                                path_item[method]['security'] = [{'BearerAuth': []}];
                            }
                        }
                    }
                }
            } elif path.startswith('/function/') {
                path_parts = path.split('/');
                if (len(path_parts) >= 3) {
                    func_name = path_parts[2];
                    if (
                        (func_name in self.get_functions())
                        and self.introspector.is_auth_required_for_function(func_name)
                    ) {
                        for method in path_item {
                            if (method in ['get', 'post', 'put', 'patch', 'delete']) {
                                path_item[method]['security'] = [{'BearerAuth': []}];
                            }
                        }
                    }
                }
            } elif path in ['/user/username', '/user/password'] {
                for method in path_item {
                    if (method in ['put', 'patch']) {
                        path_item[method]['security'] = [{'BearerAuth': []}];
                    }
                }
            } elif path == '/graph/data' {
                for method in path_item {
                    if (method in ['get', 'post', 'put', 'patch', 'delete']) {
                        # Optional auth - show lock icon but allow without token (falls back to __guest__)
                        path_item[method]['security'] = [{'BearerAuth': []}, {}];
                    }
                }
            }
        }
        self.server.app.openapi_schema = openapi_schema;
        return openapi_schema;
    }
    self.server.app.openapi = custom_openapi;
}

# ============================================================================
# HMR (Hot Module Replacement) Support
# ============================================================================
"""Register the /healthz endpoint for liveness checks."""
impl JacAPIServerCore.register_health_endpoint -> None {
    async def health_check -> dict {
        return {"status": "ok"};
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/healthz',
            callback=health_check,
            parameters=[],
            response_model=None,
            tags=['Health'],
            summary='Liveness check',
            description='Returns 200 if the server is running'
        )
    );
}

"""Register the /cl/__error__ endpoint for client-side error reporting."""
impl JacAPIServerCore._register_client_error_endpoint -> None {
    import from fastapi { Request }
    import from fastapi.responses { JSONResponse }
    async def client_error_handler(request: Request) -> JSONResponse {
        try {
            data = await request.json();
        } except Exception {
            return JSONResponse(status_code=400, content={"error": "Invalid JSON"});
        }
        message = data.get('message', '');
        if not message {
            return JSONResponse(
                status_code=400, content={"error": "Missing required field: message"}
            );
        }
        # Rate limit and deduplicate
        import from jaclang.runtimelib.source_mapping {
            SourceMapper,
            _error_rate_limiter
        }
        if not _error_rate_limiter.should_log(message) {
            return JSONResponse(
                status_code=200, content={"ok": True, "throttled": True}
            );
        }
        stack = data.get('stack', '');
        url = data.get('url', '');
        source = data.get('source', '');
        # Resolve stack trace to .jac files via source maps
        if stack and self.base_path {
            try {
                mapper = SourceMapper.from_bundle(self.base_path);
                stack = mapper.resolve_stack_trace(stack);
            } except Exception { }
        }
        log_parts = [f"[Client] {message}"];
        if stack {
            log_parts.append(f"  Stack: {stack}");
        }
        if url {
            log_parts.append(f"  URL: {url}");
        }
        if source {
            log_parts.append(f"  Source: {source}");
        }
        logger.error('\n'.join(log_parts));
        console.error(f"[Client] {message}");
        if stack {
            for line in stack.split('\n') {
                console.print(f"    {line}");
            }
        }
        return JSONResponse(status_code=200, content={"ok": True});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/cl/__error__',
            callback=client_error_handler,
            parameters=[],
            response_model=None,
            tags=['Client'],
            summary='Report client-side error',
            description='Receives client-side JavaScript errors for server-side logging.'
        )
    );
}

"""Enable HMR mode - file changes trigger reload on next request."""
impl JacAPIServerCore.enable_hmr(hot_reloader: Any) -> None {
    self._hot_reloader = hot_reloader;
    # Callback when file changes - sets pending flag
    def on_change(event: Any) {
        self._hmr_pending = True;
        logger.debug(f"Change detected: {event.path}");
    }
    # Register callback with the watcher
    hot_reloader.watcher.add_callback(on_change);
    logger.debug("Dynamic routing enabled for jac-scale");
}

"""Register all endpoints (core + user-defined). Called at startup and on HMR refresh."""
impl JacAPIServerCore._register_endpoints -> None {
    # Core endpoints
    self.register_health_endpoint();
    self.register_auth_endpoints();
    self.register_page_endpoint();
    self.register_client_js_endpoint();
    self.register_static_file_endpoint();
    self.register_graph_endpoint();
    self.register_admin_endpoints();
    self.register_llm_telemetry_endpoints();
    # User-defined endpoints (walkers, functions, webhooks)
    self.register_walkers_endpoints();
    self.register_functions_endpoints();
    self.register_webhook_endpoints();
    self.register_websocket_endpoints();
    # Post-registration
    self.register_scheduler_endpoints();
    self.register_root_asset_endpoint();
    self._register_client_error_endpoint();
    self._configure_openapi_security();
}

"""Refresh all endpoints after HMR reload - clears routes and re-registers from scratch."""
impl JacAPIServerCore._refresh_dev_endpoints -> None {
    self._hmr_pending = False;
    self.introspector.load(force_reload=True);
    # Clear all routes and endpoints, then re-setup docs and re-register
    self.server._endpoints[:] = [];
    self.server.app.routes.clear();
    self.server.app.setup();
    self._register_endpoints();
    self.server.execute();
    self.server.app.openapi_schema = None;
}

"""Create the __system__ user, initialise JacScaleScheduler, and register /jobs endpoints."""
impl JacAPIServerCore._setup_scheduler -> None {
    scheduler_config = get_scale_config().get_scheduler_config();
    system_password = scheduler_config.get('system_user_password', 'system_secret');
    try {
        self.user_manager.create_internal_user(
            '__system__', system_password, role='system'
        );
    } except Exception { }
    system_token = self.user_manager.create_jwt_token('__system__');

    # Initialise JacScaleScheduler singleton
    jac_scheduler = JacScaleScheduler.instance();
    jac_scheduler.setup(system_token=system_token or '', server=self);

    # Register static tasks (walkers/functions with STATIC trigger)
    jac_scheduler.register_static_tasks(self.get_walkers(), self.get_functions(), self);

    # Reload persisted dynamic jobs from DB
    jac_scheduler.register_dynamic_tasks_from_db();

    # Start APScheduler background thread
    jac_scheduler.start();
}

"""Create a wrapper around the metrics endpoint that requires admin authentication."""
impl JacAPIServerCore._create_admin_metrics_handler(
    original_handler: Callable[..., Any]
) -> Callable[..., Any] {
    import from fastapi { Request }
    import from fastapi.responses { Response, JSONResponse }
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    import dataclasses;
    import base64;

    monitoring_config = get_scale_config().get_monitoring_config();
    prometheus_password = monitoring_config.get('prometheus_admin_password', '');
    admin_config = get_scale_config().get_admin_config();
    admin_username = admin_config.get('username', 'admin');

    async def admin_metrics_handler(request: Request) -> Response {
        authorization = request.headers.get('Authorization');
        # Accept Bearer JWT token (admin portal) or Basic Auth (Prometheus scraping)
        authed = False;
        if authorization {
            if authorization.startswith('Bearer ') {
                authed = self.validate_admin_token(authorization) is not None;
            } elif authorization.startswith('Basic ') and prometheus_password {
                try {
                    decoded = base64.b64decode(authorization[6:]).decode('utf-8');
                    parts = decoded.split(':', 1);
                    authed = parts[0] == admin_username
                    and parts[1] == prometheus_password;
                } except Exception {
                    authed = False;
                }
            }
        }
        if not authed {
            return JSONResponse(
                status_code=403,
                content=dataclasses.asdict(
                    TransportResponse.fail(
                        code='FORBIDDEN',
                        message='Admin access required',
                        meta=Meta(extra={'http_status': 403})
                    )
                )
            );
        }
        return original_handler();
    }
    return admin_metrics_handler;
}
