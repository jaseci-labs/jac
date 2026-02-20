"""Walker, function, webhook, WebSocket endpoint implementations."""
impl JacAPIServerEndpoints.register_walkers_endpoints -> None {
    for walker_name in self.get_walkers() {
        # Skip walkers configured for webhook or websocket transport
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBHOOK or protocol == APIProtocol.WEBSOCKET {
            continue;
        }
        walker_cls = self.get_walkers()[walker_name];
        restspec = walker_cls.restspec if walker_cls?.restspec else None;
        spec_method = restspec.method if restspec?.method else HTTPMethod.POST;
        spec_path = restspec.path if restspec?.path else f"/walker/{walker_name}";

        self.server.add_endpoint(
            JEndPoint(
                method=spec_method,
                path=f"{spec_path}/{{nd}}",
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

impl JacAPIServerEndpoints.create_walker_parameters(
    walker_name: str, invoke_on_root: bool, method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
    # Extract path parameter names from restspec path (e.g. /items/{item_id} -> {"item_id"})
    walker_cls = self.get_walkers()[walker_name];
    restspec = walker_cls.restspec if walker_cls?.restspec else None;
    spec_path = restspec.path if restspec else None;
    path_param_names = _extract_path_param_names(spec_path);
    walker_fields = self.introspector.introspect_walker(
        self.get_walkers()[walker_name]
    )['fields'];
    for field_name in walker_fields {
        if ((field_name == '_jac_spawn_node') and invoke_on_root) {
            continue;
        }
        field_type = walker_fields[field_name]['type'];
        # Determine parameter type: path params first, then file, then query/body by method
        if field_name == '_jac_spawn_node' or field_name in path_param_names {
            param_type = ParameterType.PATH;
        } elif ('UploadFile' in field_type or 'uploadfile' in field_type.lower()) {
            # Support UploadFile type for file uploads
            param_type = ParameterType.FILE;
        } elif method == HTTPMethod.GET {
            param_type = ParameterType.QUERY;
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

impl JacAPIServerEndpoints.create_walker_callback(
    walker_name: str, has_node_param: bool = False
) -> Callable[..., (TransportResponse | StreamingResponse)] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    import from fastapi { Request }
    requires_auth = self.introspector.is_auth_required_for_walker(walker_name);
    async def callback(
        request: Request, nd: (str | None) = None, **kwargs: JsonValue
    ) -> (TransportResponse | StreamingResponse) {
        username: (str | None) = None;
        if requires_auth {
            authorization = request.headers.get('Authorization');
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
        if nd {
            kwargs['_jac_spawn_node'] = nd;
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

# ============================================================================
# Function Endpoints
# ============================================================================
impl JacAPIServerEndpoints.register_functions_endpoints -> None {
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

impl JacAPIServerEndpoints.create_function_parameters(
    func_name: str, method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
    # Extract path parameter names from restspec path
    func_obj = self.get_functions()[func_name];
    restspec = func_obj.restspec if func_obj?.restspec else None;
    spec_path = restspec.path if restspec else None;
    path_param_names = _extract_path_param_names(spec_path);
    func_fields = self.introspector.introspect_callable(func_obj)['parameters'];
    for field_name in func_fields {
        field_type = func_fields[field_name]['type'];
        if field_name in path_param_names {
            param_type = ParameterType.PATH;
        } elif ('UploadFile' in field_type or 'uploadfile' in field_type.lower()) {
            param_type = ParameterType.FILE;
        } elif method == HTTPMethod.GET {
            param_type = ParameterType.QUERY;
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

impl JacAPIServerEndpoints.create_function_callback(
    func_name: str
) -> Callable[..., (TransportResponse | StreamingResponse)] {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    import from fastapi { Request }
    requires_auth = self.introspector.is_auth_required_for_function(func_name);
    async def callback(
        request: Request, **kwargs: JsonValue
    ) -> (TransportResponse | StreamingResponse) {
        username: (str | None) = None;
        if requires_auth {
            authorization = request.headers.get('Authorization');
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

# ============================================================================
# Webhook Endpoints
# ============================================================================
"""Get the API protocol for a walker by checking its restspec."""
impl JacAPIServerEndpoints.get_walker_protocol(walker_name: str) -> str {
    walkers = self.get_walkers();
    if walker_name not in walkers {
        return APIProtocol.HTTP;
    }
    walker_cls = walkers[walker_name];
    restspec = walker_cls.restspec if walker_cls?.restspec else None;
    if restspec?.protocol {
        return restspec.protocol;
    }
    return APIProtocol.HTTP;
}

"""Create webhook callback for a walker with HMAC-SHA256 signature verification."""
impl JacAPIServerEndpoints.create_webhook_callback(
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
impl JacAPIServerEndpoints.create_webhook_parameters(
    walker_name: str
) -> list[APIParameter] {
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
    # Add walker fields as body parameters (excluding protocol)
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

"""Register webhook endpoints for walkers with protocol=WEBHOOK."""
impl JacAPIServerEndpoints.register_webhook_endpoints -> None {
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);

        if protocol == APIProtocol.WEBHOOK {
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

# ============================================================================
# WebSocket Endpoints
# ============================================================================
"""Get or lazily initialize the WebSocket connection manager."""
impl JacAPIServerEndpoints.get_ws_manager -> WebSocketConnectionManager {
    if not self._ws_manager {
        self._ws_manager = WebSocketConnectionManager();
    }
    return self._ws_manager;
}

"""Create a WebSocket handler for a specific walker."""
impl JacAPIServerEndpoints.create_websocket_handler(walker_name: str) -> Callable {
    ws_manager = self.get_ws_manager();
    requires_auth = self.introspector.is_auth_required_for_walker(walker_name);
    # Check if this walker has broadcast enabled
    walker_cls = self.get_walkers()[walker_name];
    restspec = walker_cls.restspec
    if walker_cls?.restspec and walker_cls.restspec
    else None;
    is_broadcast = restspec.broadcast if restspec and restspec?.broadcast else False;
    async def websocket_handler(websocket: WebSocket) -> None {
        await ws_manager.connect(websocket, walker_name);
        try {
            while True {
                data = await websocket.receive_json();

                # Handle authentication if required
                username: (str | None) = None;
                if requires_auth {
                    token = data.pop('token', None)
                    or websocket.query_params.get('token');
                    if token {
                        username = self.user_manager.validate_jwt_token(token);
                    }
                    if not username {
                        await websocket.send_json(
                            {
                                'ok': False,
                                'error': {
                                    'code': 'UNAUTHORIZED',
                                    'message': 'Invalid or missing token'
                                }
                            }
                        );
                        continue;
                    }
                }

                # Spawn the walker with received fields
                try {
                    result = await self.execution_manager.spawn_walker(
                        self.get_walkers()[walker_name],
                        data,
                        (username or '__guest__')
                    );
                    if isinstance(result, dict) and 'error' in result {
                        # Errors always go only to sender
                        await websocket.send_json(
                            {
                                'ok': False,
                                'error': {
                                    'code': 'EXECUTION_ERROR',
                                    'message': result.get(
                                        'error', 'Walker execution failed'
                                    )
                                }
                            }
                        );
                    } else {
                        response = {'ok': True, 'data': result};
                        if is_broadcast {
                            # Broadcast to ALL connections of this walker
                            await ws_manager.broadcast(walker_name, response);
                        } else {
                            # Send only to sender
                            await websocket.send_json(response);
                        }
                    }
                } except Exception as e {
                    logger.error(
                        f"WebSocket walker execution error for '{walker_name}': {e}"
                    );
                    # Errors always go only to sender
                    await websocket.send_json(
                        {
                            'ok': False,
                            'error': {'code': 'INTERNAL_ERROR', 'message': str(e)}
                        }
                    );
                }
            }
        } except WebSocketDisconnect {
            ws_manager.disconnect(websocket, walker_name);
        } except Exception as e {
            logger.error(f"WebSocket error for walker '{walker_name}': {e}");
            ws_manager.disconnect(websocket, walker_name);
        }
    }
    return websocket_handler;
}

"""Register WebSocket endpoints for walkers with protocol=WEBSOCKET (production mode)."""
impl JacAPIServerEndpoints.register_websocket_endpoints -> None {
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBSOCKET {
            handler = self.create_websocket_handler(walker_name);
            self.server.app.websocket(f"/ws/{walker_name}")(handler);
            logger.info(f"Registered WebSocket endpoint: /ws/{walker_name}");
        }
    }
}

# ============================================================================
# Dynamic HMR Endpoints
# ============================================================================
"""Register a single dynamic endpoint for all walkers.

Instead of pre-registering /walker/WalkerA, /walker/WalkerB, etc.,
we register catch-all routes that look up walkers at request time.
This enables HMR since introspector.load() is called per-request.
"""
impl JacAPIServerEndpoints.register_dynamic_walker_endpoint -> None {
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    import from fastapi { Request }
    import from fastapi.responses { StreamingResponse }
    # Dynamic handler that looks up walker at request time
    async def dynamic_walker_handler(
        request: Request, walker_name: str, nd: str | None = None
    ) -> (TransportResponse | StreamingResponse) {
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
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBHOOK {
            return TransportResponse.fail(
                code='BAD_REQUEST',
                message=f"Walker '{walker_name}' is configured as a webhook. Use /webhook/{walker_name} instead.",
                meta=Meta(extra={'http_status': 400})
            );
        }

        # Handle authentication
        username: str | None = None;
        Authorization = request.headers.get('Authorization');
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
        if nd {
            kwargs['_jac_spawn_node'] = nd;
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
impl JacAPIServerEndpoints.register_dynamic_function_endpoint -> None {
    import from fastapi.responses { JSONResponse, StreamingResponse }
    import from fastapi { Request }
    import from jaclang.runtimelib.transport { TransportResponse, Meta }
    async def dynamic_function_handler(
        request: Request, function_name: str
    ) -> (TransportResponse | StreamingResponse) {
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
        Authorization = request.headers.get('Authorization');
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
impl JacAPIServerEndpoints.register_dynamic_introspection_endpoints -> None {
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

"""Register dynamic webhook endpoint for HMR support."""
impl JacAPIServerEndpoints.register_dynamic_webhook_endpoint -> None {
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
        protocol = self.get_walker_protocol(walker_name);
        if protocol != APIProtocol.WEBHOOK {
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

"""Register dynamic WebSocket endpoint for HMR support (dev mode)."""
impl JacAPIServerEndpoints.register_dynamic_websocket_endpoint -> None {
    ws_manager = self.get_ws_manager();
    async def dynamic_ws_handler(websocket: WebSocket, walker_name: str) -> None {
        if self._hmr_pending {
            self.introspector.load(force_reload=True);
            self._hmr_pending = False;
        }

        walkers = self.get_walkers();
        if walker_name not in walkers {
            await websocket.close(
                code=4004, reason=f"Walker '{walker_name}' not found"
            );
            return;
        }

        protocol = self.get_walker_protocol(walker_name);
        if protocol != APIProtocol.WEBSOCKET {
            await websocket.close(
                code=4000,
                reason=f"Walker '{walker_name}' is not a WebSocket walker. Use /walker/{walker_name} instead."
            );
            return;
        }

        handler = self.create_websocket_handler(walker_name);
        await handler(websocket);
    }
    self.server.app.websocket("/ws/{walker_name}")(dynamic_ws_handler);
}
