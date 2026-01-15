"""Helper function to convert TransportResponse to dict for JSONResponse."""
def _transport_response_to_dict(
    transport_response: TransportResponse
) -> dict[str, Any] {
    result = {
        'ok': transport_response.ok,
        'type': transport_response.type,
        'data': transport_response.data,
        'error': None
    };
    if not transport_response.ok and transport_response.error {
        result['error'] = {
            'code': transport_response.error.code,
            'message': transport_response.error.message,
            'details': transport_response.error.details
        };
    }
    if transport_response.meta {
        meta_dict = {};
        if transport_response.meta.request_id {
            meta_dict['request_id'] = transport_response.meta.request_id;
        }
        if transport_response.meta.trace_id {
            meta_dict['trace_id'] = transport_response.meta.trace_id;
        }
        if transport_response.meta.timestamp {
            meta_dict['timestamp'] = transport_response.meta.timestamp;
        }
        if transport_response.meta.extra {
            meta_dict['extra'] = transport_response.meta.extra;
        }
        if meta_dict {
            result['meta'] = meta_dict;
        }
    }
    return result;
}

"""Helper function to get HTTP status code from TransportResponse."""
def _get_http_status(transport_response: TransportResponse) -> int {
    if transport_response.meta and transport_response.meta.extra {
        return transport_response.meta.extra.get(
            'http_status', 200 if transport_response.ok else 500
        );
    }
    return 200 if transport_response.ok else 500;
}

"""Helper function to convert TransportResponse directly to JSONResponse."""
def _transport_response_to_json_response(
    transport_response: TransportResponse
) -> JSONResponse {
    import from fastapi.responses { JSONResponse }
    return JSONResponse(
        status_code=_get_http_status(transport_response),
        content=_transport_response_to_dict(transport_response)
    );
}

impl JacAPIServer.start(self: JacAPIServer, watch: bool = False) -> None {
    self.introspector.load();
    # Eagerly build client bundle if there are client exports (skip in watch mode)
    if not watch {
        client_exports = self.introspector._client_manifest.get('exports', []);
        if client_exports {
            import time;
            import sys;
            print("Building client bundle...", flush=True);
            start_time = time.time();
            try {
                self.introspector.ensure_bundle();
                elapsed = time.time() - start_time;
                print(f"Client bundle ready ({elapsed:.1f}s).");
            } except Exception as e {
                print(f"\n[ERROR] Failed to build client bundle:", file=sys.stderr);
                print(f"{e}", file=sys.stderr);
                print(
                    f"\nClient pages will not be available until this is fixed.\n",
                    file=sys.stderr
                );
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
    # Use dynamic routing for HMR support, static routing for production
    if watch {
        self.register_dynamic_walker_endpoint();
        self.register_dynamic_function_endpoint();
        self.register_dynamic_introspection_endpoints();
    } else {
        self.register_walkers_endpoints();
        self.register_functions_endpoints();
    }
    self.register_root_asset_endpoint();
    self._configure_openapi_security();
    self.user_manager.create_user('__guest__', '__no_password__');
    self.server.run_server(port=self.port);
}

"""Configure OpenAPI security scheme to only apply to walker endpoints that require auth."""
impl JacAPIServer._configure_openapi_security(self: JacAPIServer) -> None {
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
            }
        }
        self.server.app.openapi_schema = openapi_schema;
        return openapi_schema;
    }
    self.server.app.openapi = custom_openapi;
}

"""Serve root-level assets like /img.png, /icons/logo.svg, etc."""
impl JacAPIServer.serve_root_asset(self: JacAPIServer, file_path: str) -> Response {
    allowed_extensions = {'.png','.jpg','.jpeg','.gif','.webp','.svg','.ico','.woff','.woff2','.ttf','.otf','.eot','.mp4','.webm','.mp3','.wav','.css','.js','.json','.pdf','.txt','.xml'};
    file_ext = Path(file_path).suffix.lower();
    if (not file_ext or (file_ext not in allowed_extensions)) {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    if file_path.startswith(
        (f'{cl_route_prefix}/', 'walker/', 'function/', 'user/', 'static/')
    ) {
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    # Find project root (where jac.toml is) instead of using base_path_dir
    # base_path_dir might be src/ when serving src/app.jac, but we need project root
    import from jaclang.project.config { find_project_root }
    base_path_dir = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd();
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (base_path, _) = project_root_result;
    } else {
        # Fallback to base_path_dir if no project root found
        base_path = base_path_dir;
    }
    file_name = Path(file_path).name;
    candidates = [
        base_path / 'dist' / file_path,
        base_path / 'dist' / file_name,
        base_path / 'assets' / file_path,
        base_path / 'assets' / file_name,
        base_path / 'public' / file_path,
        base_path / 'src' / file_path,
        base_path / 'src' / file_name,
        (base_path / file_path)
    ];
    for candidate_file in candidates {
        if (candidate_file.exists() and candidate_file.is_file()) {
            file_content = candidate_file.read_bytes();
            (content_type, _) = mimetypes.guess_type(str(candidate_file));
            if (content_type is None) {
                content_type = 'application/octet-stream';
            }
            headers = {'Cache-Control': 'public, max-age=31536000'};
            return Response(
                content=file_content, media_type=content_type, headers=headers
            );
        }
    }
    return Response(
        status_code=404,
        content=f"Asset not found: {file_path}",
        media_type='text/plain'
    );
}

"""Register root-level asset serving endpoint for files like /img.png, /logo.svg"""
impl JacAPIServer.register_root_asset_endpoint(self: JacAPIServer) -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/{file_path:path}',
            callback=self.serve_root_asset,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Path to asset file (e.g., img.png, icons/logo.svg)',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve root-level assets',
            description='Endpoint to serve assets from root path with common extensions (.png, .jpg, .svg, etc.)'
        )
    );
}

"""Serve a static file given its path."""
impl JacAPIServer.serve_static_file(self: JacAPIServer, file_path: str) -> Response {
    try {
        # Find project root (where jac.toml is) instead of using base_path_dir
        # base_path_dir might be src/ when serving src/app.jac, but we need project root
        import from jaclang.project.config { find_project_root }
        base_path_dir = Path(Jac.base_path_dir) if Jac.base_path_dir else Path.cwd();
        project_root_result = find_project_root(base_path_dir);
        if project_root_result {
            (base_path, _) = project_root_result;
        } else {
            # Fallback to base_path_dir if no project root found
            base_path = base_path_dir;
        }
        file_name = Path(file_path).name;
        # Check multiple locations for files
        # 1. .jac/client/dist/ (Jac-client build output)
        client_build_dist_file = base_path / '.jac' / 'client' / 'dist' / file_path;
        client_build_dist_file_simple = base_path / '.jac' / 'client' / 'dist' / file_name;
        # 2. dist/ (jac core build output)
        dist_file = base_path / 'dist' / file_path;
        dist_file_simple = base_path / 'dist' / file_name;
        # 3. assets/ (static assets)
        assets_file = base_path / 'assets' / file_path;
        assets_file_simple = base_path / 'assets' / file_name;
        if file_name.endswith('.css') {
            # Check .jac/client/dist/ first (jac-client)
            if client_build_dist_file.exists() {
                css_content = client_build_dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif client_build_dist_file_simple.exists() {
                css_content = client_build_dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file.exists() {
                css_content = dist_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif dist_file_simple.exists() {
                css_content = dist_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file.exists() {
                css_content = assets_file.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } elif assets_file_simple.exists() {
                css_content = assets_file_simple.read_text(encoding='utf-8');
                return Response(content=css_content, media_type='text/css');
            } else {
                return Response(
                    status_code=404,
                    content='CSS file not found',
                    media_type='text/plain'
                );
            }
        }
        for candidate_file in [
            client_build_dist_file,
            client_build_dist_file_simple,
            dist_file,
            dist_file_simple,
            assets_file,
            assets_file_simple
        ] {
            if (candidate_file.exists() and candidate_file.is_file()) {
                file_content = candidate_file.read_bytes();
                (content_type, _) = mimetypes.guess_type(str(candidate_file));
                if (content_type is None) {
                    content_type = 'application/octet-stream';
                }
                return Response(content=file_content, media_type=content_type);
            }
        }
        return Response(
            status_code=404, content='Static file not found', media_type='text/plain'
        );
    } except Exception as exc {
        return Response(status_code=500);
    }
}

"""Register the static file serving endpoint using JEndPoint."""
impl JacAPIServer.register_static_file_endpoint(self: JacAPIServer) -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/{file_path:path}',
            callback=self.serve_static_file,
            parameters=[
                APIParameter(
                    name='file_path',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Path of the static file to serve',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Static Files'],
            summary='Serve static files',
            description='Endpoint to serve static files from the server.'
        )
    );
}

"""Register the client.js serving endpoint using JEndPoint."""
impl JacAPIServer.register_client_js_endpoint(self: JacAPIServer) -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/static/client.js',
            callback=self.serve_client_js_callback(),
            parameters=[],
            response_model=None,
            tags=['Static Files'],
            summary='Serve client.js',
            description='Endpoint to serve the client-side JavaScript file.'
        )
    );
}

"""Create callback to serve the client.js file."""
impl JacAPIServer.serve_client_js_callback(
    self: JacAPIServer
) -> Callable[..., Response] {
    def callback -> Response {
        try {
            self.introspector.load();
            self.introspector.ensure_bundle();
            return Response(
                content=self.introspector._bundle.code,
                media_type='application/javascript'
            );
        } except RuntimeError as exc {
            return Response(content=str(exc), status_code=503, media_type='text/plain');
        }
    }
    return callback;
}

"""Register the page rendering endpoint using JEndPoint."""
impl JacAPIServer.register_page_endpoint(self: JacAPIServer) -> None {
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    base_route_app = config.serve.base_route_app if config else "";
    # Register the configurable cl route (e.g., /cl/{page_name})
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path=f'/{cl_route_prefix}/{{page_name}}',
            callback=self.render_page_callback(),
            parameters=[
                APIParameter(
                    name='page_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the page to render',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Pages'],
            summary='Render a page',
            description=f'Endpoint to render and retrieve a specific page by name at /{cl_route_prefix}/{{name}}.'
        )
    );
    # If base_route_app is configured, register it at /
    if base_route_app {
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path='/',
                callback=self.render_base_route_callback(base_route_app),
                parameters=[],
                response_model=None,
                tags=['Pages'],
                summary='Base route app',
                description=f'Serves the {base_route_app} client app at the root path.'
            )
        );
    }
}

"""Create callback that extracts all query parameters from FastAPI Request."""
impl JacAPIServer.render_page_callback(
    self: JacAPIServer
) -> Callable[..., HTMLResponse] {
    """Render a page by name with all query parameters.""";
    def callback(page_name: str, **kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                page_name, kwargs, '__guest__'
            );
            return HTMLResponse(content=render_payload['html']);
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            print(f"Error rendering page '{page_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

"""Create callback for base route app rendering."""
impl JacAPIServer.render_base_route_callback(
    self: JacAPIServer, app_name: str
) -> Callable[..., HTMLResponse] {
    """Render the base route app.""";
    def callback(**kwargs: JsonValue) -> HTMLResponse {
        try {
            render_payload = self.introspector.render_page(
                app_name, kwargs, '__guest__'
            );
            return HTMLResponse(content=render_payload['html']);
        } except ValueError as exc {
            return HTMLResponse(content=f"<h1>404 Not Found</h1>", status_code=404);
        } except RuntimeError as exc {
            print(f"Error rendering base route app '{app_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

impl JacAPIServer.register_functions_endpoints(self: JacAPIServer) -> None {
    for func_name in self.get_functions() {
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"/function/{func_name}",
                callback=self.create_function_callback(func_name),
                parameters=self.create_function_parameters(func_name),
                response_model=None,
                tags=['Functions'],
                summary='This is a summary',
                description='This is a description'
            )
        );
    }
}

impl JacAPIServer.create_function_parameters(
    self: JacAPIServer, func_name: str
) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
    if self.introspector.is_auth_required_for_function(func_name) {
        parameters.append(
            APIParameter(
                name='Authorization',
                data_type='string',
                required=False,
                default=None,
                description='Bearer token for authentication',
                type=ParameterType.HEADER
            )
        );
    }
    func_fields = self.introspector.introspect_callable(
        self.get_functions()[func_name]
    )['parameters'];
    for field_name in func_fields {
        parameters.append(
            APIParameter(
                name=field_name,
                data_type=func_fields[field_name]['type'],
                required=func_fields[field_name]['required'],
                default=func_fields[field_name]['default'],
                description=f"Field {field_name} for function {func_name}",
                type=ParameterType.BODY
            )
        );
    }
    return parameters;
}

impl JacAPIServer.create_function_callback(
    self: JacAPIServer, func_name: str
) -> Callable[..., TransportResponse] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    requires_auth = self.introspector.is_auth_required_for_function(func_name);
    def callback(**kwargs: JsonValue) -> TransportResponse {
        username: (str | None) = None;
        if requires_auth {
            authorization = kwargs.pop('Authorization', None);
            token: (str | None) = None;
            if (
                authorization
                and isinstance(authorization, str)
                and authorization.startswith('Bearer ')
            ) {
                token = authorization[7:];
            }
            username = self.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }
        print(f"Executing function '{func_name}' with params: {kwargs}");
        result = self.execution_manager.execute_function(
            self.get_functions()[func_name], kwargs, (username or '__guest__')
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='EXECUTION_ERROR',
                message=result.get('error', 'Function execution failed'),
                details=result.get('traceback') if 'traceback' in result else None,
                meta=Meta(extra={'http_status': 500})
            );
        }
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    return callback;
}

impl JacAPIServer.register_walkers_endpoints(self: JacAPIServer) -> None {
    for walker_name in self.get_walkers() {
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"/walker/{walker_name}/{{node}}",
                callback=self.create_walker_callback(walker_name, has_node_param=True),
                parameters=self.create_walker_parameters(
                    walker_name, invoke_on_root=False
                ),
                response_model=None,
                tags=['Walkers'],
                summary='API Entry',
                description='API Entry'
            )
        );
        self.server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"/walker/{walker_name}",
                callback=self.create_walker_callback(walker_name, has_node_param=False),
                parameters=self.create_walker_parameters(
                    walker_name, invoke_on_root=True
                ),
                response_model=None,
                tags=['Walkers'],
                summary='API Root',
                description='API Root'
            )
        );
    }
}

impl JacAPIServer.create_walker_parameters(
    self: JacAPIServer, walker_name: str, invoke_on_root: bool
) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
    if self.introspector.is_auth_required_for_walker(walker_name) {
        parameters.append(
            APIParameter(
                name='Authorization',
                data_type='string',
                required=False,
                default=None,
                description='Bearer token for authentication',
                type=ParameterType.HEADER
            )
        );
    }
    walker_fields = self.introspector.introspect_walker(
        self.get_walkers()[walker_name]
    )['fields'];
    for field_name in walker_fields {
        if ((field_name == '_jac_spawn_node') and invoke_on_root) {
            continue;
        }
        parameters.append(
            APIParameter(
                name='node' if (field_name == '_jac_spawn_node') else field_name,
                data_type=walker_fields[field_name]['type'],
                required=walker_fields[field_name]['required'],
                default=walker_fields[field_name]['default'],
                description=f"Field {field_name} for walker {walker_name}",
                type=ParameterType.BODY
                if (field_name != '_jac_spawn_node')
                else ParameterType.PATH
            )
        );
    }
    return parameters;
}

impl JacAPIServer.create_walker_callback(
    self: JacAPIServer, walker_name: str, has_node_param: bool = False
) -> Callable[..., TransportResponse] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    requires_auth = self.introspector.is_auth_required_for_walker(walker_name);
    def callback(node: (str | None) = None, **kwargs: JsonValue) -> TransportResponse {
        username: (str | None) = None;
        if requires_auth {
            authorization = kwargs.pop('Authorization', None);
            token: (str | None) = None;
            if (
                authorization
                and isinstance(authorization, str)
                and authorization.startswith('Bearer ')
            ) {
                token = authorization[7:];
            }
            username = self.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }
        if node {
            kwargs['_jac_spawn_node'] = node;
        }
        result = self.execution_manager.spawn_walker(
            self.get_walkers()[walker_name], kwargs, (username or '__guest__')
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='EXECUTION_ERROR',
                message=result.get('error', 'Walker execution failed'),
                details=result.get('traceback') if 'traceback' in result else None,
                meta=Meta(extra={'http_status': 500})
            );
        }
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    return callback;
}

impl JacAPIServer.register_refresh_token_endpoint(self: JacAPIServer) -> None {
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

impl JacAPIServer.register_create_user_endpoint(self: JacAPIServer) -> None {
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

impl JacAPIServer.refresh_token(
    self: JacAPIServer, token: (str | None) = None
) -> TransportResponse {
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
    new_token = self.refresh_jwt_token(token);
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

impl JacAPIServer.create_user(
    self: JacAPIServer, username: str, password: str
) -> TransportResponse {
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
        res['token'] = self.create_jwt_token(username);
        return TransportResponse.success(
            data=res, meta=Meta(extra={'http_status': 201})
        );
    } except Exception as e {
        error_trace = traceback.format_exc();
        print(f"Error in create_user: {e}\n{error_trace}");
        return TransportResponse.fail(
            code='INTERNAL_ERROR',
            message=f"Registration failed: {e}",
            meta=Meta(extra={'http_status': 500})
        );
    }
}

impl JacAPIServer.register_login_endpoint(self: JacAPIServer) -> None {
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

impl JacAPIServer.login(
    self: JacAPIServer, username: str, password: str
) -> TransportResponse {
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
    result['token'] = self.create_jwt_token(username);
    return TransportResponse.success(
        data=dict[(str, JsonValue)](result), meta=Meta(extra={'http_status': 200})
    );
}

impl JacAPIServer.init(
    self: JacAPIServer, module_name: str, port: int = 8000, base_path: str = ""
) -> None {
    super.init(module_name, port, base_path);
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
    start_path = Path(base_path) if base_path else None;
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
    self.SUPPORTED_PLATFORMS: dict = {};
    # Load SSO config fresh (not from cached global) to support env var overrides at runtime
    sso_config = get_scale_config().get_sso_config();
    for platform in Platforms {
        key = platform.lower();
        platform_config = sso_config.get(key, {});

        client_id = platform_config.get('client_id', '');
        client_secret = platform_config.get('client_secret', '');

        if not client_id or not client_secret {
            continue;
        }

        self.SUPPORTED_PLATFORMS[platform.value] = {
            "client_id": client_id,
            "client_secret": client_secret
        };
    }
}

impl JacAPIServer.refresh_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(
            token, JWT_SECRET, algorithms=[JWT_ALGORITHM], options={"verify_exp": True}
        );
        username = decoded.get('username');

        if not username {
            return None;
        }

        return JacAPIServer.create_jwt_token(username);
    } except Exception {
        return None;
    }
}

impl JacAPIServer.validate_jwt_token(token: str) -> (str | None) {
    try {
        decoded = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM]);
        return decoded['username'];
    } except Exception {
        return None;
    }
}

impl JacAPIServer.create_jwt_token(username: str) -> str {
    now = datetime.now(UTC);
    payload: dict[(str, Any)] = {
        'username': username,
        'exp': (now + timedelta(days=JWT_EXP_DELTA_DAYS)),
        'iat': now.timestamp()
    };
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM);
}

impl JacAPIServer.get_sso(
    self: JacAPIServer, platform: str, operation: str
) -> (GoogleSSO | None) {
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return None;
    }
    credentials = self.SUPPORTED_PLATFORMS[platform];
    redirect_uri = f"{SSO_HOST}/{platform}/{operation}/callback";
    if (platform == Platforms.GOOGLE.value) {
        return GoogleSSO(
            client_id=credentials['client_id'],
            client_secret=credentials['client_secret'],
            redirect_uri=redirect_uri,
            allow_insecure_http=True
        );
    }
    return None;
}

impl JacAPIServer.sso_initiate(
    self: JacAPIServer, platform: str, operation: str
) -> (Response | TransportResponse) {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    if (platform not in [p.value for p in Platforms]) {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if (operation not in [o.value for o in Operations]) {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform, operation);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    with sso {
        return await sso.get_login_redirect();
    }
}

impl JacAPIServer.sso_callback(
    self: JacAPIServer, request: Request, platform: str, operation: str
) -> TransportResponse {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    if (platform not in [p.value for p in Platforms]) {
        return TransportResponse.fail(
            code='INVALID_PLATFORM',
            message=f"Invalid platform '{platform}'. Supported platforms: {', '.join(
                [p.value for p in Platforms]
            )}",
            meta=Meta(extra={'http_status': 400})
        );
    }
    if (platform not in self.SUPPORTED_PLATFORMS) {
        return TransportResponse.fail(
            code='SSO_NOT_CONFIGURED',
            message=f"SSO for platform '{platform}' is not configured. Please set SSO_{platform.upper()}_CLIENT_ID and SSO_{platform.upper()}_CLIENT_SECRET environment variables.",
            meta=Meta(extra={'http_status': 501})
        );
    }
    if (operation not in [o.value for o in Operations]) {
        return TransportResponse.fail(
            code='INVALID_OPERATION',
            message=f"Invalid operation '{operation}'. Must be 'login' or 'register'",
            meta=Meta(extra={'http_status': 400})
        );
    }
    sso = self.get_sso(platform, operation);
    if not sso {
        return TransportResponse.fail(
            code='SSO_INIT_FAILED',
            message=f"Failed to initialize SSO for platform '{platform}'",
            meta=Meta(extra={'http_status': 500})
        );
    }
    try {
        with sso {
            user_info = await sso.verify_and_process(request);
            email = user_info.email;
            if not email {
                return TransportResponse.fail(
                    code='EMAIL_MISSING',
                    message=f"Email not provided by {platform}",
                    meta=Meta(extra={'http_status': 400})
                );
            }
            if (operation == Operations.LOGIN.value) {
                user = self.user_manager.get_user(email);
                if not user {
                    return TransportResponse.fail(
                        code='USER_NOT_FOUND',
                        message='User not found. Please register first.',
                        meta=Meta(extra={'http_status': 404})
                    );
                }
                token = self.create_jwt_token(email);
                return TransportResponse.success(
                    data={
                        'message': 'Login successful',
                        'email': email,
                        'token': token,
                        'platform': platform,
                        'user': dict[(str, JsonValue)](user)
                    },
                    meta=Meta(extra={'http_status': 200})
                );
            } elif (operation == Operations.REGISTER.value) {
                existing_user = self.user_manager.get_user(email);
                if existing_user {
                    return TransportResponse.fail(
                        code='USER_EXISTS',
                        message='User already exists. Please login instead.',
                        meta=Meta(extra={'http_status': 400})
                    );
                }
                random_password = generate_random_password();
                result = self.user_manager.create_user(email, random_password);
                if ('error' in result) {
                    return TransportResponse.fail(
                        code='USER_CREATION_FAILED',
                        message=result.get('error', 'User creation failed'),
                        meta=Meta(extra={'http_status': 400})
                    );
                }
                token = self.create_jwt_token(email);
                result['token'] = token;
                result['platform'] = platform;
                return TransportResponse.success(
                    data=result, meta=Meta(extra={'http_status': 201})
                );
            }
        }
    } except Exception as e {
        return TransportResponse.fail(
            code='AUTHENTICATION_FAILED',
            message=f"Authentication failed: {str(e)}",
            meta=Meta(extra={'http_status': 500})
        );
    }
}

impl JacAPIServer.register_sso_endpoints(self: JacAPIServer) -> None {
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/sso/{platform}/{operation}',
            callback=self.sso_initiate,
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
            callback=self.sso_callback,
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
# HMR (Hot Module Replacement) Dynamic Routing Support
# ============================================================================
"""Enable HMR mode - file changes trigger reload on next request."""
impl JacAPIServer.enable_hmr(self: JacAPIServer, hot_reloader: Any) -> None {
    self._hot_reloader = hot_reloader;
    # Callback when file changes - sets pending flag
    def on_change(event: Any) -> None {
        self._hmr_pending = True;
        print(f"[HMR] Change detected: {event.path}", flush=True);
    }
    # Register callback with the watcher
    hot_reloader.watcher.add_callback(on_change);
    print("[HMR] Dynamic routing enabled for jac-scale", flush=True);
}

"""Register a single dynamic endpoint for all walkers.

Instead of pre-registering /walker/WalkerA, /walker/WalkerB, etc.,
we register catch-all routes that look up walkers at request time.
This enables HMR since introspector.load() is called per-request.
"""
impl JacAPIServer.register_dynamic_walker_endpoint(self: JacAPIServer) -> None {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    # Dynamic handler that looks up walker at request time
    def dynamic_walker_handler(
        walker_name: str, node: str | None = None, **kwargs: JsonValue
    ) -> TransportResponse {
        # Reload introspector if files changed (HMR)
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        walkers = self.get_walkers();

        if walker_name not in walkers {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message=f"Walker '{walker_name}' not found. Available: {list(
                    walkers.keys()
                )}",
                meta=Meta(extra={'http_status': 404})
            );
        }

        # Handle authentication if required
        username: str | None = None;
        if self.introspector.is_auth_required_for_walker(walker_name) {
            authorization = kwargs.pop('Authorization', None);
            token: str | None = None;
            if (
                authorization
                and isinstance(authorization, str)
                and authorization.startswith('Bearer ')
            ) {
                token = authorization[7:];
            }
            username = self.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        # Add node to kwargs if provided
        if node {
            kwargs['_jac_spawn_node'] = node;
        }

        result = self.execution_manager.spawn_walker(
            walkers[walker_name], kwargs, (username or '__guest__')
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='EXECUTION_ERROR',
                message=result.get('error', 'Walker execution failed'),
                details=result.get('traceback') if 'traceback' in result else None,
                meta=Meta(extra={'http_status': 500})
            );
        }
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    # Register catch-all route for walkers with node parameter
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/walker/{walker_name}/{node}',
            callback=dynamic_walker_handler,
            parameters=[
                APIParameter(
                    name='walker_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the walker to execute',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='node',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Node ID to spawn walker on',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=False,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Walkers (Dynamic)'],
            summary='Execute walker on node (dynamic HMR)',
            description='Dynamically routes to any registered walker. Supports HMR - walker changes are reflected immediately.'
        )
    );
    # Register catch-all route for walkers without node parameter (root)
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/walker/{walker_name}',
            callback=dynamic_walker_handler,
            parameters=[
                APIParameter(
                    name='walker_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the walker to execute',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=False,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Walkers (Dynamic)'],
            summary='Execute walker on root (dynamic HMR)',
            description='Dynamically routes to any registered walker. Supports HMR - walker changes are reflected immediately.'
        )
    );
}

"""Register a single dynamic endpoint for all functions.

Similar to dynamic walker routing, this enables HMR for functions.
"""
impl JacAPIServer.register_dynamic_function_endpoint(self: JacAPIServer) -> None {
    import from fastapi.responses { JSONResponse }
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    def dynamic_function_handler(
        function_name: str, **kwargs: JsonValue
    ) -> TransportResponse {
        # Reload introspector if files changed (HMR)
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        functions = self.get_functions();

        if function_name not in functions {
            return TransportResponse.fail(
                code='NOT_FOUND',
                message=f"Function '{function_name}' not found. Available: {list(
                    functions.keys()
                )}",
                meta=Meta(extra={'http_status': 404})
            );
        }

        # Handle authentication if required
        username: str | None = None;
        if self.introspector.is_auth_required_for_function(function_name) {
            authorization = kwargs.pop('Authorization', None);
            token: str | None = None;
            if (
                authorization
                and isinstance(authorization, str)
                and authorization.startswith('Bearer ')
            ) {
                token = authorization[7:];
            }
            username = self.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        result = self.execution_manager.execute_function(
            functions[function_name], kwargs, (username or '__guest__')
        );
        if 'error' in result {
            return TransportResponse.fail(
                code='EXECUTION_ERROR',
                message=result.get('error', 'Function execution failed'),
                details=result.get('traceback') if 'traceback' in result else None,
                meta=Meta(extra={'http_status': 500})
            );
        }
        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/function/{function_name}',
            callback=dynamic_function_handler,
            parameters=[
                APIParameter(
                    name='function_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the function to call',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=False,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Functions (Dynamic)'],
            summary='Call function (dynamic HMR)',
            description='Dynamically routes to any registered function. Supports HMR - function changes are reflected immediately.'
        )
    );
}

"""Register endpoints for runtime introspection of available walkers/functions.

These endpoints allow clients to discover what walkers and functions are available,
which is especially useful in HMR mode where the list can change dynamically.
"""
impl JacAPIServer.register_dynamic_introspection_endpoints(self: JacAPIServer) -> None {
    import from fastapi.responses { JSONResponse }
    def list_walkers -> dict[str, Any] {
        # Reload introspector if files changed (HMR)
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        walkers = self.get_walkers();
        walker_info = {};
        for walker_name in walkers {
            try {
                info = self.introspector.introspect_walker(walkers[walker_name]);
                walker_info[walker_name] = {
                    'fields': info.get('fields', {}),
                    'requires_auth': self.introspector.is_auth_required_for_walker(
                        walker_name
                    )
                };
            } except Exception as e {
                walker_info[walker_name] = {'error': str(e)};
            }
        }
        return {'walkers': walker_info};
    }
    def list_functions -> dict[str, Any] {
        # Reload introspector if files changed (HMR)
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        functions = self.get_functions();
        function_info = {};
        for func_name in functions {
            try {
                info = self.introspector.introspect_callable(functions[func_name]);
                function_info[func_name] = {
                    'parameters': info.get('parameters', {}),
                    'requires_auth': self.introspector.is_auth_required_for_function(
                        func_name
                    )
                };
            } except Exception as e {
                function_info[func_name] = {'error': str(e)};
            }
        }
        return {'functions': function_info};
    }
    def get_walker_info(walker_name: str) -> dict[str, Any] {
        # Reload introspector if files changed (HMR)
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        walkers = self.get_walkers();
        if walker_name not in walkers {
            return {'error': f"Walker '{walker_name}' not found", 'status': 404};
        }

        info = self.introspector.introspect_walker(walkers[walker_name]);
        return {
            'name': walker_name,
            'fields': info.get('fields', {}),
            'requires_auth': self.introspector.is_auth_required_for_walker(walker_name)
        };
    }
    # List all walkers
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/introspect/walkers',
            callback=list_walkers,
            parameters=[],
            response_model=None,
            tags=['Introspection'],
            summary='List available walkers',
            description='Returns a list of all available walkers with their field definitions. Supports HMR.'
        )
    );
    # List all functions
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/introspect/functions',
            callback=list_functions,
            parameters=[],
            response_model=None,
            tags=['Introspection'],
            summary='List available functions',
            description='Returns a list of all available functions with their parameter definitions. Supports HMR.'
        )
    );
    # Get specific walker info
    self.server_impl.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path='/introspect/walker/{walker_name}',
            callback=get_walker_info,
            parameters=[
                APIParameter(
                    name='walker_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the walker to inspect',
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=['Introspection'],
            summary='Get walker information',
            description='Returns detailed information about a specific walker. Supports HMR.'
        )
    );
}
