import from jaclang.cli.console { console }
import from jaclang.cli.banners { JAC_DISCORD_URL }

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

impl JacAPIServer.start(dev: bool = False, no_client: bool = False) -> None {
    self.introspector.load();
    # Eagerly build client bundle if there are client exports (skip in dev or no_client mode)
    if not dev and not no_client {
        client_exports = self.introspector._client_manifest.get('exports', []);
        if client_exports {
            import time;
            import sys;
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
                console.warning(f"Failed to build client bundle: {e}");
                console.print(
                    "\n  Client pages will not be available until this is fixed.\n",
                    style="muted",
                    file=sys.stderr
                );
                console.info('Try again after running: jac clean --all', emoji=True);
                console.info(
                    f'If it still doesn\'t work, ask for help at {JAC_DISCORD_URL}',
                    emoji=True
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
    self.register_update_username_endpoint();
    self.register_update_password_endpoint();
    self.register_api_key_endpoints();
    # Use dynamic routing for HMR support, static routing for production
    if dev {
        self.register_dynamic_walker_endpoint();
        self.register_dynamic_function_endpoint();
        self.register_dynamic_introspection_endpoints();
        self.register_dynamic_webhook_endpoint();
    } else {
        self.register_walkers_endpoints();
        self.register_functions_endpoints();
        self.register_webhook_endpoints();
    }
    self.register_root_asset_endpoint();
    self._configure_openapi_security();
    self.user_manager.create_user('__guest__', '__no_password__');
    self.server.run_server(port=self.port);
}

"""Configure OpenAPI security scheme to only apply to walker endpoints that require auth."""
impl JacAPIServer._configure_openapi_security -> None {
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
            }
        }
        self.server.app.openapi_schema = openapi_schema;
        return openapi_schema;
    }
    self.server.app.openapi = custom_openapi;
}

"""Serve root-level assets like /img.png, /icons/logo.svg, etc.
Falls back to SPA HTML for extensionless paths when base_route_app is configured."""
impl JacAPIServer.serve_root_asset(file_path: str) -> Response {
    allowed_extensions = {'.png','.jpg','.jpeg','.gif','.webp','.svg','.ico','.woff','.woff2','.ttf','.otf','.eot','.mp4','.webm','.mp3','.wav','.css','.js','.json','.pdf','.txt','.xml'};
    file_ext = Path(file_path).suffix.lower();
    import from jaclang.project.config { get_config }
    config = get_config();
    cl_route_prefix = config.serve.cl_route_prefix if config else "cl";
    api_prefixes = (f'{cl_route_prefix}/', 'walker/', 'function/', 'user/', 'static/');
    if (not file_ext or (file_ext not in allowed_extensions)) {
        # SPA catch-all: serve base_route_app for extensionless paths
        base_route_app = config.serve.base_route_app if config else "";
        if (not file_ext and base_route_app and not file_path.startswith(api_prefixes)) {
            try {
                render_payload = self.introspector.render_page(
                    base_route_app, {}, '__guest__'
                );
                return HTMLResponse(content=render_payload['html']);
            } except ValueError {
                return HTMLResponse(content="<h1>404 Not Found</h1>", status_code=404);
            } except RuntimeError {
                return HTMLResponse(
                    content="<h1>503 Service Unavailable</h1>", status_code=503
                );
            }
        }
        return Response(status_code=404, content='Not found', media_type='text/plain');
    }
    if file_path.startswith(api_prefixes) {
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
impl JacAPIServer.register_root_asset_endpoint -> None {
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
impl JacAPIServer.serve_static_file(file_path: str) -> Response {
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
impl JacAPIServer.register_static_file_endpoint -> None {
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
impl JacAPIServer.register_client_js_endpoint -> None {
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
impl JacAPIServer.serve_client_js_callback -> Callable[..., Response] {
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
impl JacAPIServer.register_page_endpoint -> None {
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
impl JacAPIServer.render_page_callback -> Callable[..., HTMLResponse] {
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
            console.print(f"Error rendering page '{page_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

"""Create callback for base route app rendering."""
impl JacAPIServer.render_base_route_callback(
    app_name: str
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
            console.print(f"Error rendering base route app '{app_name}': {exc}");
            return HTMLResponse(
                content=f"<h1>503 Service Unavailable</h1>", status_code=503
            );
        }
    }
    return callback;
}

impl JacAPIServer.register_functions_endpoints -> None {
    for func_name in self.get_functions() {
        func_obj = self.get_functions()[func_name];
        restspec = func_obj.restspec if func_obj?.restspec else None;
        spec_method = restspec.method if restspec else HTTPMethod.POST;
        spec_path = restspec.path if restspec else None;

        final_path = spec_path or f"/function/{func_name}";

        self.server.add_endpoint(
            JEndPoint(
                method=spec_method,
                path=final_path,
                callback=self.create_function_callback(func_name),
                parameters=self.create_function_parameters(
                    func_name, method=spec_method
                ),
                response_model=None,
                tags=['Functions'],
                summary='This is a summary',
                description='This is a description'
            )
        );
    }
}

impl JacAPIServer.create_function_parameters(
    func_name: str, method: HTTPMethod = HTTPMethod.POST
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
        field_type = func_fields[field_name]['type'];
        # Determine parameter type based on field type and method
        if (
            method == HTTPMethod.GET
            and not ('UploadFile' in field_type or 'uploadfile' in field_type.lower())
        ) {
            param_type = ParameterType.QUERY;
        } elif ('UploadFile' in field_type or 'uploadfile' in field_type.lower()) {
            # Support UploadFile type for file uploads
            param_type = ParameterType.FILE;
        } else {
            param_type = ParameterType.BODY;
        }
        parameters.append(
            APIParameter(
                name=field_name,
                data_type=field_type,
                required=func_fields[field_name]['required'],
                default=func_fields[field_name]['default'],
                description=f"Field {field_name} for function {func_name}",
                type=param_type
            )
        );
    }
    return parameters;
}

impl JacAPIServer.create_function_callback(
    func_name: str
) -> Callable[..., TransportResponse] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    requires_auth = self.introspector.is_auth_required_for_function(func_name);
    async def callback(**kwargs: JsonValue) -> TransportResponse {
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
            username = self.user_manager.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }
        console.print(f"Executing function '{func_name}' with params: {kwargs}");
        result = await self.execution_manager.execute_function(
            self.get_functions()[func_name], kwargs, (username or '__guest__')
        );
        # Handle streaming responses (generators/async generators)
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            return StreamingResponse(
                result,
                media_type='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'close',
                    'X-Accel-Buffering': 'no'
                }
            );
        }
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

impl JacAPIServer.register_walkers_endpoints -> None {
    for walker_name in self.get_walkers() {
        # Skip walkers configured for webhook transport - they use /webhook/{walker_name} instead
        transport_type = self.get_transport_type_for_walker(walker_name);
        if transport_type == TransportType.WEBHOOK {
            continue;
        }
        walker_cls = self.get_walkers()[walker_name];
        restspec = walker_cls.restspec if walker_cls?.restspec else None;
        spec_method = restspec.method if restspec?.method else HTTPMethod.POST;
        spec_path = restspec.path if restspec?.path else f"/walker/{walker_name}";

        self.server.add_endpoint(
            JEndPoint(
                method=spec_method,
                path=f"{spec_path}/{{node}}",
                callback=self.create_walker_callback(walker_name, has_node_param=True),
                parameters=self.create_walker_parameters(
                    walker_name, invoke_on_root=False, method=spec_method
                ),
                response_model=None,
                tags=['Walkers'],
                summary='API Entry',
                description='API Entry'
            )
        );
        self.server.add_endpoint(
            JEndPoint(
                method=spec_method,
                path=spec_path,
                callback=self.create_walker_callback(walker_name, has_node_param=False),
                parameters=self.create_walker_parameters(
                    walker_name, invoke_on_root=True, method=spec_method
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
    walker_name: str, invoke_on_root: bool, method: HTTPMethod = HTTPMethod.POST
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
        field_type = walker_fields[field_name]['type'];
        # Determine parameter type based on field type and method
        if (field_name == '_jac_spawn_node') {
            param_type = ParameterType.PATH;
        } elif (
            method == HTTPMethod.GET
            and not ('UploadFile' in field_type or 'uploadfile' in field_type.lower())
        ) {
            param_type = ParameterType.QUERY;
        } elif ('UploadFile' in field_type or 'uploadfile' in field_type.lower()) {
            # Support UploadFile type for file uploads
            param_type = ParameterType.FILE;
        } else {
            param_type = ParameterType.BODY;
        }
        parameters.append(
            APIParameter(
                name='node' if (field_name == '_jac_spawn_node') else field_name,
                data_type=field_type,
                required=walker_fields[field_name]['required'],
                default=walker_fields[field_name]['default'],
                description=f"Field {field_name} for walker {walker_name}",
                type=param_type
            )
        );
    }
    return parameters;
}

impl JacAPIServer.create_walker_callback(
    walker_name: str, has_node_param: bool = False
) -> Callable[..., TransportResponse] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    requires_auth = self.introspector.is_auth_required_for_walker(walker_name);
    async def callback(
        node: (str | None) = None, **kwargs: JsonValue
    ) -> TransportResponse {
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
            username = self.user_manager.validate_jwt_token(token) if token else None;
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
        result = await self.execution_manager.spawn_walker(
            self.get_walkers()[walker_name], kwargs, (username or '__guest__')
        );
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            return StreamingResponse(
                result,
                media_type='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'close',
                    'X-Accel-Buffering': 'no'
                }
            );
        }
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

impl JacAPIServer.register_refresh_token_endpoint -> None {
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

impl JacAPIServer.register_create_user_endpoint -> None {
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

impl JacAPIServer.refresh_token(token: (str | None) = None) -> TransportResponse {
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

impl JacAPIServer.create_user(username: str, password: str) -> TransportResponse {
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

impl JacAPIServer.update_username(
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

impl JacAPIServer.update_password(
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

impl JacAPIServer.register_update_username_endpoint -> None {
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

impl JacAPIServer.register_update_password_endpoint -> None {
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

impl JacAPIServer.register_login_endpoint -> None {
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

impl JacAPIServer.login(username: str, password: str) -> TransportResponse {
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

impl JacAPIServer.postinit -> None {
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
}

impl JacAPIServer.register_sso_endpoints -> None {
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
# HMR (Hot Module Replacement) Dynamic Routing Support
# ============================================================================
"""Enable HMR mode - file changes trigger reload on next request."""
impl JacAPIServer.enable_hmr(hot_reloader: Any) -> None {
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

"""Register a single dynamic endpoint for all walkers.

Instead of pre-registering /walker/WalkerA, /walker/WalkerB, etc.,
we register catch-all routes that look up walkers at request time.
This enables HMR since introspector.load() is called per-request.
"""
impl JacAPIServer.register_dynamic_walker_endpoint -> None {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    import from fastapi { Request }
    # Dynamic handler that looks up walker at request time
    async def dynamic_walker_handler(
        request: Request,
        walker_name: str,
        node: str | None = None,
        Authorization: str | None = None
    ) -> TransportResponse {
        # Parse request body or query params to get walker fields
        if request.method == 'GET' {
            kwargs: dict[str, Any] = dict(request.query_params);
        } else {
            try {
                body = await request.json();
            } except Exception {
                body = {};
            }
            kwargs = dict(body) if body else {};
        }

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

        # Reject walkers configured for webhook transport - they use /webhook/{walker_name} instead
        transport_type = self.get_transport_type_for_walker(walker_name);
        if transport_type == TransportType.WEBHOOK {
            return TransportResponse.fail(
                code='BAD_REQUEST',
                message=f"Walker '{walker_name}' is configured as a webhook. Use /webhook/{walker_name} instead.",
                meta=Meta(extra={'http_status': 400})
            );
        }

        # Handle authentication
        username: str | None = None;
        authorization = kwargs.pop('Authorization', None);
        if self.introspector.is_auth_required_for_walker(walker_name) {
            token: str | None = None;
            if (
                Authorization
                and isinstance(Authorization, str)
                and Authorization.startswith('Bearer ')
            ) {
                token = Authorization[7:];
            }
            username = self.user_manager.validate_jwt_token(token) if token else None;
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

        result = await self.execution_manager.spawn_walker(
            walkers[walker_name], kwargs, (username or '__guest__')
        );

        # Handle streaming responses (generators/async generators)
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            return StreamingResponse(
                result,
                media_type='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'close',
                    'X-Accel-Buffering': 'no'
                }
            );
        }

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
    # Register catch-all route for walkers with node parameter (POST)
    self.server.add_endpoint(
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
    # Register catch-all route for walkers with node parameter (GET)
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
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
    # Register catch-all route for walkers without node parameter (root) (POST)
    self.server.add_endpoint(
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
    # Register catch-all route for walkers without node parameter (root) (GET)
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
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
impl JacAPIServer.register_dynamic_function_endpoint -> None {
    import from fastapi.responses { JSONResponse }
    import from fastapi { Request }
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    async def dynamic_function_handler(
        request: Request, function_name: str, Authorization: str | None = None
    ) -> TransportResponse {
        # Parse request body or query params to get function arguments
        if request.method == 'GET' {
            kwargs: dict[str, Any] = dict(request.query_params);
        } else {
            try {
                body = await request.json();
            } except Exception {
                body = {};
            }
            kwargs = dict(body) if body else {};
        }

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

        # Handle authentication
        username: str | None = None;
        authorization = kwargs.pop('Authorization', None);
        if self.introspector.is_auth_required_for_function(function_name) {
            token: str | None = None;
            if (
                Authorization
                and isinstance(Authorization, str)
                and Authorization.startswith('Bearer ')
            ) {
                token = Authorization[7:];
            }
            username = self.user_manager.validate_jwt_token(token) if token else None;
            if not username {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        result = await self.execution_manager.execute_function(
            functions[function_name], kwargs, (username or '__guest__')
        );
        # Handle streaming responses (generators/async generators)
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            return StreamingResponse(
                result,
                media_type='text/event-stream',
                headers={
                    'Cache-Control': 'no-cache',
                    'Connection': 'close',
                    'X-Accel-Buffering': 'no'
                }
            );
        }
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
    # Register POST endpoint
    self.server.add_endpoint(
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
    # Register GET endpoint
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
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
impl JacAPIServer.register_dynamic_introspection_endpoints -> None {
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
    self.server.add_endpoint(
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
    self.server.add_endpoint(
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
    self.server.add_endpoint(
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

"""Get or create the API key manager instance."""
impl JacAPIServer.get_api_key_manager -> ApiKeyManager {
    if self._api_key_manager is None {
        self._api_key_manager = ApiKeyManager();
    }
    return self._api_key_manager;
}

"""Create a new API key for the authenticated user."""
impl JacAPIServer.create_api_key(
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
impl JacAPIServer.list_api_keys(Authorization: str | None = None) -> TransportResponse {
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
impl JacAPIServer.revoke_api_key(
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
impl JacAPIServer.register_api_key_endpoints -> None {
    # Create API key
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/api-key/create',
            callback=self.create_api_key,
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
                ),
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
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
            callback=self.list_api_keys,
            parameters=[
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
                )
            ],
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
            callback=self.revoke_api_key,
            parameters=[
                APIParameter(
                    name='api_key_id',
                    data_type='string',
                    required=True,
                    default=None,
                    description='The ID of the API key to revoke',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='Authorization',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Bearer token for authentication',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['API Keys'],
            summary='Revoke an API key',
            description='Revokes an API key, making it invalid for future webhook requests.'
        )
    );
}

"""Get the transport type for a walker by checking its restspec."""
impl JacAPIServer.get_transport_type_for_walker(walker_name: str) -> str {
    walkers = self.get_walkers();
    if walker_name not in walkers {
        return TransportType.HTTP;
    }
    walker_cls = walkers[walker_name];
    restspec = walker_cls.restspec if walker_cls?.restspec else None;
    if restspec?.webhook {
        return TransportType.WEBHOOK;
    }
    return TransportType.HTTP;
}

"""Create webhook callback for a walker with HMAC-SHA256 signature verification."""
impl JacAPIServer.create_webhook_callback(
    walker_name: str
) -> Callable[..., TransportResponse] {
    async def callback(request: Request, **kwargs: JsonValue) -> TransportResponse {
        webhook_config = get_scale_config().get_webhook_config();
        signature_header = webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        );
        verify_signature = webhook_config.get('verify_signature', True);

        # Get API key from header
        api_key = request.headers.get('X-API-Key');
        if not api_key {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Missing X-API-Key header',
                meta=Meta(extra={'http_status': 401})
            );
        }

        # Validate API key and get username
        username = self.get_api_key_manager().validate_api_key(api_key);
        if not username {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired API key',
                meta=Meta(extra={'http_status': 401})
            );
        }

        # Verify HMAC-SHA256 signature if enabled
        if verify_signature {
            signature = request.headers.get(signature_header);
            if not signature {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message=f"Missing {signature_header} header",
                    meta=Meta(extra={'http_status': 401})
                );
            }
            # Get raw body for signature verification
            body = await request.body();
            extracted_signature = WebhookUtils.extract_signature(signature);
            # Use the API key as the secret for HMAC verification
            if not WebhookUtils.verify_signature(body, extracted_signature, api_key) {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Invalid webhook signature',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        # Parse body for walker fields
        try {
            body_bytes = await request.body();
            body_data = json.loads(body_bytes) if body_bytes else {};
        } except Exception {
            body_data = {};
        }

        walker_kwargs: dict[str, Any] = dict(body_data) if body_data else {};

        # Execute the walker
        result = await self.execution_manager.spawn_walker(
            self.get_walkers()[walker_name], walker_kwargs, username
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

"""Create parameters for webhook endpoint."""
impl JacAPIServer.create_webhook_parameters(walker_name: str) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
    # API key header (required for webhooks)
    # Use underscore naming for valid Python identifiers - FastAPI auto-converts to hyphenated headers
    parameters.append(
        APIParameter(
            name='x_api_key',
            data_type='string',
            required=True,
            default=None,
            description='API key for webhook authentication (X-API-Key header)',
            type=ParameterType.HEADER
        )
    );
    # Signature header (for HMAC verification)
    # Use underscore naming for valid Python identifiers
    parameters.append(
        APIParameter(
            name='x_webhook_signature',
            data_type='string',
            required=False,
            default=None,
            description='HMAC-SHA256 signature of the request body (X-Webhook-Signature header)',
            type=ParameterType.HEADER
        )
    );
    # Add walker fields as body parameters (excluding transport_type)
    walker_fields = self.introspector.introspect_walker(
        self.get_walkers()[walker_name]
    )['fields'];
    for field_name in walker_fields {
        if field_name in ('_jac_spawn_node', ) {
            continue;
        }
        field_type = walker_fields[field_name]['type'];
        parameters.append(
            APIParameter(
                name=field_name,
                data_type=field_type,
                required=walker_fields[field_name]['required'],
                default=walker_fields[field_name]['default'],
                description=f"Field {field_name} for webhook walker {walker_name}",
                type=ParameterType.BODY
            )
        );
    }
    return parameters;
}

"""Register webhook endpoints for walkers with transport_type=WEBHOOK."""
impl JacAPIServer.register_webhook_endpoints -> None {
    for walker_name in self.get_walkers() {
        transport_type = self.get_transport_type_for_walker(walker_name);

        if transport_type == TransportType.WEBHOOK {
            self.server.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/webhook/{walker_name}",
                    callback=self.create_webhook_callback(walker_name),
                    parameters=self.create_webhook_parameters(walker_name),
                    response_model=None,
                    tags=['Webhooks'],
                    summary=f'Webhook endpoint for {walker_name}',
                    description=f'Webhook endpoint for {walker_name}. Requires API key authentication and HMAC-SHA256 signature verification.'
                )
            );
        }
    }
}

"""Register dynamic webhook endpoint for HMR support."""
impl JacAPIServer.register_dynamic_webhook_endpoint -> None {
    async def dynamic_webhook_handler(
        request: Request, walker_name: str
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
                message=f"Webhook walker '{walker_name}' not found",
                meta=Meta(extra={'http_status': 404})
            );
        }

        # Verify this walker is configured for webhook transport
        transport_type = self.get_transport_type_for_walker(walker_name);
        if transport_type != TransportType.WEBHOOK {
            return TransportResponse.fail(
                code='BAD_REQUEST',
                message=f"Walker '{walker_name}' is not configured as a webhook. Use /walker/{walker_name} instead.",
                meta=Meta(extra={'http_status': 400})
            );
        }

        webhook_config = get_scale_config().get_webhook_config();
        signature_header = webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        );
        verify_signature = webhook_config.get('verify_signature', True);

        # Get API key from header
        api_key = request.headers.get('X-API-Key');
        if not api_key {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Missing X-API-Key header',
                meta=Meta(extra={'http_status': 401})
            );
        }

        # Validate API key and get username
        username = self.get_api_key_manager().validate_api_key(api_key);
        if not username {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired API key',
                meta=Meta(extra={'http_status': 401})
            );
        }

        # Verify HMAC-SHA256 signature if enabled
        if verify_signature {
            signature = request.headers.get(signature_header);
            if not signature {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message=f"Missing {signature_header} header",
                    meta=Meta(extra={'http_status': 401})
                );
            }
            body = await request.body();
            extracted_signature = WebhookUtils.extract_signature(signature);
            if not WebhookUtils.verify_signature(body, extracted_signature, api_key) {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Invalid webhook signature',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        # Parse body for walker fields
        try {
            body_bytes = await request.body();
            body_data = json.loads(body_bytes) if body_bytes else {};
        } except Exception {
            body_data = {};
        }

        walker_kwargs: dict[str, Any] = dict(body_data) if body_data else {};

        # Execute the walker
        result = await self.execution_manager.spawn_walker(
            walkers[walker_name], walker_kwargs, username
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
    # Register dynamic webhook route
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.POST,
            path='/webhook/{walker_name}',
            callback=dynamic_webhook_handler,
            parameters=[
                APIParameter(
                    name='walker_name',
                    data_type='string',
                    required=True,
                    default=None,
                    description='Name of the webhook walker to execute',
                    type=ParameterType.PATH
                ),
                APIParameter(
                    name='x_api_key',
                    data_type='string',
                    required=True,
                    default=None,
                    description='API key for webhook authentication (X-API-Key header)',
                    type=ParameterType.HEADER
                ),
                APIParameter(
                    name='x_webhook_signature',
                    data_type='string',
                    required=False,
                    default=None,
                    description='HMAC-SHA256 signature of the request body (X-Webhook-Signature header)',
                    type=ParameterType.HEADER
                )
            ],
            response_model=None,
            tags=['Webhooks (Dynamic)'],
            summary='Execute webhook walker (dynamic HMR)',
            description='Dynamically routes to webhook walkers. Supports HMR - walker changes are reflected immediately.'
        )
    );
}
