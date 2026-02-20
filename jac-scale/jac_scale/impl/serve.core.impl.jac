"""Core auth, user management, JWT, API keys, server start/postinit implementations."""
impl JacAPIServerCore.postinit -> None {
    super.postinit();
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
                        request.method,
                        request.url.path,
                        response.status_code,
                        duration
                    );
                    return response;
                } except Exception as e {
                    duration = time.perf_counter() - start_time;
                    metrics_collector.record_request(
                        request.method, request.url.path, 500, duration
                    );
                    raise ;
                } finally {
                    metrics_collector.request_finished();
                }
            }
        }
        self.server.app.add_middleware(MetricsMiddleware);
        # Register /metrics endpoint
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=metrics_endpoint,
                callback=self._metrics.get_endpoint_handler(),
                parameters=[],
                response_model=None,
                tags=['Monitoring'],
                summary='Prometheus metrics',
                description='Exposes application metrics in Prometheus format for scraping'
            )
        );
        logger.info(f"Prometheus metrics enabled at {metrics_endpoint}");
    }
}

impl JacAPIServerCore.start(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[[], None] | None = None
) -> None {
    self.introspector.load();
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
    self.register_create_user_endpoint();
    self.register_login_endpoint();
    self.register_page_endpoint();
    self.register_refresh_token_endpoint();
    self.register_sso_endpoints();
    self.register_client_js_endpoint();
    self.register_static_file_endpoint();
    self.register_update_username_endpoint();
    self.register_update_password_endpoint();
    self.register_api_key_endpoints();
    self.register_graph_endpoint();
    # Use dynamic routing for HMR support, static routing for production
    if dev {
        self.register_dynamic_walker_endpoint();
        self.register_dynamic_function_endpoint();
        self.register_dynamic_introspection_endpoints();
        self.register_dynamic_webhook_endpoint();
        self.register_dynamic_websocket_endpoint();
    } else {
        self.register_walkers_endpoints();
        self.register_functions_endpoints();
        self.register_webhook_endpoints();
        self.register_websocket_endpoints();
    }
    self.register_root_asset_endpoint();
    self._configure_openapi_security();
    self.user_manager.create_user('__guest__', '__no_password__');
    # Call the ready callback (e.g., to print startup banner)
    if on_ready {
        on_ready();
    }
    self.server.run_server(port=self.port);
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

impl JacAPIServerCore.register_login_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/login',
            callback=self.login,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='username for login',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Password for login',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='User login',
            description='Endpoint for user authentication and token generation'
        )
    );
}

impl JacAPIServerCore.login(username: str, password: str) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    if (not username or not password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Username and password required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.authenticate(username, password);
    if not result {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid credentials',
            meta=Meta(extra={'http_status': 401})
        );
    }
    result['token'] = self.user_manager.create_jwt_token(username);
    return TransportResponse.success(
        data=dict[(str, JsonValue)](result), meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerCore.register_create_user_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/register',
            callback=self.create_user,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username for new user',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Password for new user',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='Register user API.',
            description='Endpoint for creating a new user account'
        )
    );
}

impl JacAPIServerCore.create_user(username: str, password: str) -> TransportResponse {
    import traceback;
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    try {
        res = self.user_manager.create_user(username, password);
        if ('error' in res) {
            return TransportResponse.fail(
                code='USER_EXISTS',
                message=res.get('error', 'User creation failed'),
                meta=Meta(extra={'http_status': 400})
            );
        }
        res['token'] = self.user_manager.create_jwt_token(username);
        return TransportResponse.success(
            data=res, meta=Meta(extra={'http_status': 201})
        );
    } except Exception as e {
        error_trace = traceback.format_exc();
        console.print(f"Error in create_user: {e}\n{error_trace}");
        return TransportResponse.fail(
            code='INTERNAL_ERROR',
            message=f"Registration failed: {e}",
            meta=Meta(extra={'http_status': 500})
        );
    }
}

impl JacAPIServerCore.register_refresh_token_endpoint -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/user/refresh-token',
            callback=self.refresh_token,
            parameters=[
                APIParameter(
                    name='token',
                    data_type='string',
                    required=True,
                    default=None,
                    description='JWT token to refresh (with or without Bearer prefix)',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='Refresh JWT token',
            description='Endpoint for refreshing an existing JWT token. Token must be within the refresh window.'
        )
    );
}

impl JacAPIServerCore.refresh_token(token: (str | None) = None) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    if (not token) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Token is required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    if token.startswith('Bearer ') {
        token = token[7:];
    }
    new_token = self.user_manager.refresh_jwt_token(token);
    if (not new_token) {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return TransportResponse.success(
        data={'token': new_token, 'message': 'Token refreshed successfully'},
        meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerCore.update_username(
    current_username: str, new_username: str, Authorization: (str | None) = None
) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    # Validate token and extract username
    token: (str | None) = None;
    if (
        Authorization
        and isinstance(Authorization, str)
        and Authorization.startswith('Bearer ')
    ) {
        token = Authorization[7:];
    }
    token_username = self.user_manager.validate_jwt_token(token) if token else None;
    if not token_username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }
    # Ensure user is updating their own username
    if (token_username != current_username) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Cannot update another user\'s username',
            meta=Meta(extra={'http_status': 403})
        );
    }
    if (not new_username) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='New username is required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.update_username(current_username, new_username);
    if ('error' in result) {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Username update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    # Generate new JWT token with updated username
    result['token'] = self.user_manager.create_jwt_token(new_username);
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerCore.update_password(
    username: str,
    current_password: str,
    new_password: str,
    Authorization: (str | None) = None
) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    # Validate token and extract username
    token: (str | None) = None;
    if (
        Authorization
        and isinstance(Authorization, str)
        and Authorization.startswith('Bearer ')
    ) {
        token = Authorization[7:];
    }
    token_username = self.user_manager.validate_jwt_token(token) if token else None;
    if not token_username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Invalid or expired token',
            meta=Meta(extra={'http_status': 401})
        );
    }
    # Ensure user is updating their own password
    if (token_username != username) {
        return TransportResponse.fail(
            code='FORBIDDEN',
            message='Cannot update another user\'s password',
            meta=Meta(extra={'http_status': 403})
        );
    }
    if (not current_password or not new_password) {
        return TransportResponse.fail(
            code='VALIDATION_ERROR',
            message='Current password and new password are required',
            meta=Meta(extra={'http_status': 400})
        );
    }
    result = self.user_manager.update_password(
        username, current_password, new_password
    );
    if ('error' in result) {
        return TransportResponse.fail(
            code='UPDATE_FAILED',
            message=result.get('error', 'Password update failed'),
            meta=Meta(extra={'http_status': 400})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServerCore.register_update_username_endpoint -> None {
    import from fastapi { Request }
    async def update_username_handler(
        request: Request, current_username: str, new_username: str
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.update_username(current_username, new_username, authorization);
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/user/username',
            callback=update_username_handler,
            parameters=[
                APIParameter(
                    name='current_username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Current username',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='new_username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='New username',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='Update username',
            description='Endpoint for updating user\'s username. Requires authentication.'
        )
    );
}

impl JacAPIServerCore.register_update_password_endpoint -> None {
    import from fastapi { Request }
    async def update_password_handler(
        request: Request, username: str, current_password: str, new_password: str
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.update_password(
            username, current_password, new_password, authorization
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.PUT,
            path='/user/password',
            callback=update_password_handler,
            parameters=[
                APIParameter(
                    name='username',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Username',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='current_password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Current password',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='new_password',
                    data_type='string',
                    required=True,
                    default=None,
                    description='New password',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['User APIs'],
            summary='Update password',
            description='Endpoint for updating user\'s password. Requires authentication.'
        )
    );
}

impl JacAPIServerCore.register_sso_endpoints -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/sso/{platform}/{operation}',
            callback=self.user_manager.sso_initiate,
            parameters=[
                APIParameter(
                    name='platform',
                    data_type='string',
                    required=True,
                    default=None,
                    description='SSO platform: google',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='operation',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Operation to perform: "login" or "register"',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['SSO APIs'],
            summary='Initiate SSO authentication',
            description='Redirects to the SSO provider for authentication. Supported platforms: Google. Configure each platform by setting SSO_{PLATFORM}_CLIENT_ID and SSO_{PLATFORM}_CLIENT_SECRET environment variables.'
        )
    );
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/sso/{platform}/{operation}/callback',
            callback=self.user_manager.sso_callback,
            parameters=[
                APIParameter(
                    name='platform',
                    data_type='string',
                    required=True,
                    default=None,
                    description='SSO platform: google',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='operation',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Operation to perform: "login" or "register"',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['SSO APIs'],
            summary='SSO callback endpoint',
            description='Handles the callback from SSO provider after authentication'
        )
    );
}

# ============================================================================
# HMR (Hot Module Replacement) Support
# ============================================================================
"""Enable HMR mode - file changes trigger reload on next request."""
impl JacAPIServerCore.enable_hmr(hot_reloader: Any) -> None {
    self._hot_reloader = hot_reloader;
    # Callback when file changes - sets pending flag
    def on_change(event: Any) -> None {
        self._hmr_pending = True;
        logger.debug(f"Change detected: {event.path}");
    }
    # Register callback with the watcher
    hot_reloader.watcher.add_callback(on_change);
    logger.debug("Dynamic routing enabled for jac-scale");
}

# ============================================================================
# API Key Management
# ============================================================================
"""Get or create the API key manager instance."""
impl JacAPIServerCore.get_api_key_manager -> ApiKeyManager {
    if self._api_key_manager is None {
        self._api_key_manager = ApiKeyManager();
    }
    return self._api_key_manager;
}

"""Create a new API key for the authenticated user."""
impl JacAPIServerCore.create_api_key(
    name: str, expiry_days: int | None = None, Authorization: str | None = None
) -> TransportResponse {
    # Validate JWT token to get username
    token: str | None = None;
    if Authorization and Authorization.startswith('Bearer ') {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;
    if not username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to create API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().create_api_key(
        username=username, name=name, expiry_days=expiry_days
    );
}

"""List all API keys for the authenticated user."""
impl JacAPIServerCore.list_api_keys(
    Authorization: str | None = None
) -> TransportResponse {
    # Validate JWT token to get username
    token: str | None = None;
    if Authorization and Authorization.startswith('Bearer ') {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;
    if not username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to list API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().list_api_keys(username);
}

"""Revoke an API key for the authenticated user."""
impl JacAPIServerCore.revoke_api_key(
    api_key_id: str, Authorization: str | None = None
) -> TransportResponse {
    # Validate JWT token to get username
    token: str | None = None;
    if Authorization and Authorization.startswith('Bearer ') {
        token = Authorization[7:];
    }
    username = self.user_manager.validate_jwt_token(token) if token else None;
    if not username {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Valid authentication required to revoke API keys',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return self.get_api_key_manager().revoke_api_key(username, api_key_id);
}

"""Register API key management endpoints."""
impl JacAPIServerCore.register_api_key_endpoints -> None {
    import from fastapi { Request }
    async def create_api_key_handler(
        request: Request, name: str, expiry_days: int | None = None
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.create_api_key(name, expiry_days, authorization);
    }
    async def list_api_keys_handler(request: Request) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.list_api_keys(authorization);
    }
    async def revoke_api_key_handler(
        request: Request, api_key_id: str
    ) -> TransportResponse {
        authorization = request.headers.get('Authorization');
        return self.revoke_api_key(api_key_id, authorization);
    }
    # Create API key
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/api-key/create',
            callback=create_api_key_handler,
            parameters=[
                APIParameter(
                    name='name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='A friendly name for the API key',
                    type=ParameterType.BODY
                ),
                APIParameter(
                    name='expiry_days',
                    data_type='integer',
                    required=False,
                    default=None,
                    description='Number of days until expiry (default from config)',
                    type=ParameterType.BODY
                )
            ],
            response_model=None,
            tags=['API Keys'],
            summary='Create a new API key',
            description='Creates a new API key for webhook authentication. The API key is wrapped in a JWT and can be used with HMAC-SHA256 signature verification.'
        )
    );
    # List API keys
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/api-key/list',
            callback=list_api_keys_handler,
            parameters=[],
            response_model=None,
            tags=['API Keys'],
            summary='List all API keys',
            description='Lists all API keys for the authenticated user (metadata only, not the actual keys).'
        )
    );
    # Revoke API key
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.DELETE,
            path='/api-key/{api_key_id}',
            callback=revoke_api_key_handler,
            parameters=[
                APIParameter(
                    name='api_key_id',
                    data_type='string',
                    required=True,
                    default=None,
                    description='The ID of the API key to revoke',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['API Keys'],
            summary='Revoke an API key',
            description='Revokes an API key, making it invalid for future webhook requests.'
        )
    );
}
