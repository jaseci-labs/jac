"""Walker, function, webhook, WebSocket endpoint implementations."""
impl JacAPIServerEndpoints.register_walkers_endpoints -> None {
    for walker_name in self.get_walkers() {
        # Skip walkers configured for webhook or websocket transport
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBHOOK or protocol == APIProtocol.WEBSOCKET {
            continue;
        }
        walker_cls = self.get_walkers()[walker_name];
        # Skip walkers with a schedule_spec (they run on a schedule, not as HTTP endpoints)
        if walker_cls?.schedule_spec {
            continue;
        }
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
    walker_fields = self.introspector.introspect_walker(self.get_walkers()[walker_name])[
        'fields'
    ];
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
                name='nd' if (field_name == '_jac_spawn_node') else field_name,
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
            self.get_walkers()[walker_name], kwargs, (username or Con.GUEST.value)
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
        # Skip functions with a schedule_spec (they run on a schedule, not as HTTP endpoints)
        if func_obj?.schedule_spec {
            continue;
        }
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
            self.get_functions()[func_name], kwargs, (username or Con.GUEST.value)
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
    walker_fields = self.introspector.introspect_walker(self.get_walkers()[walker_name])[
        'fields'
    ];
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
    async def websocket_handler(websocket: WebSocket) {
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
                        (username or Con.GUEST.value)
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
