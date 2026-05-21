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
    import from typing { get_type_hints }
    parameters: list[APIParameter] = [];
    # Extract path parameter names from restspec path (e.g. /items/{item_id} -> {"item_id"})
    walker_cls = self.get_walkers()[walker_name];
    restspec = walker_cls.restspec if walker_cls?.restspec else None;
    spec_path = restspec.path if restspec else None;
    path_param_names = _extract_path_param_names(spec_path);
    walker_fields = self.introspector.introspect_walker(self.get_walkers()[walker_name])[
        'fields'
    ];
    # Resolve actual type objects for custom-obj support. The jaclang
    # introspector stringifies types, which is insufficient for generating
    # nested Pydantic body models.
    try {
        walker_type_hints = get_type_hints(walker_cls.init);
    } except Exception {
        walker_type_hints = {};
    }
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
        type_obj = walker_fields[field_name].get('type_obj')
            if isinstance(walker_fields[field_name], dict)
            else None;
        if (type_obj is None) {
            type_obj = walker_type_hints.get(field_name);
        }
        parameters.append(
            APIParameter(
                name='nd' if (field_name == '_jac_spawn_node') else field_name,
                data_type=field_type,
                type_obj=type_obj,
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
        username: (str | None) = request.state?.username if request?.state else None;
        if requires_auth and not username {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Unauthorized',
                meta=Meta(extra={'http_status': 401})
            );
        }
        if nd {
            kwargs['_jac_spawn_node'] = nd;
        }
        result = await self.execution_manager.spawn_walker(
            self.get_walkers()[walker_name], kwargs, (username or Con.GUEST.value)
        );
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            import from jac_scale.microservices.gateway_internals.middleware.sse {
                sse_frame_stream
            }
            return StreamingResponse(
                sse_frame_stream(result),
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
        # Skip WebSocket-protocol functions — they register via /ws/function/{name}.
        if self.get_function_protocol(func_name) == APIProtocol.WEBSOCKET {
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
    import from typing { get_type_hints }
    parameters: list[APIParameter] = [];
    # Extract path parameter names from restspec path
    func_obj = self.get_functions()[func_name];
    restspec = func_obj.restspec if func_obj?.restspec else None;
    spec_path = restspec.path if restspec else None;
    path_param_names = _extract_path_param_names(spec_path);
    func_fields = self.introspector.introspect_callable(func_obj)['parameters'];
    try {
        func_type_hints = get_type_hints(func_obj);
    } except Exception {
        func_type_hints = {};
    }
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
        type_obj = func_fields[field_name].get('type_obj')
            if isinstance(func_fields[field_name], dict)
            else None;
        if (type_obj is None) {
            type_obj = func_type_hints.get(field_name);
        }
        parameters.append(
            APIParameter(
                name=field_name,
                data_type=field_type,
                type_obj=type_obj,
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
        username: (str | None) = request.state?.username if request?.state else None;
        if requires_auth and not username {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Unauthorized',
                meta=Meta(extra={'http_status': 401})
            );
        }
        console.print(f"Executing function '{func_name}' with params: {kwargs}");
        result = await self.execution_manager.execute_function(
            self.get_functions()[func_name], kwargs, (username or Con.GUEST.value)
        );
        # Handle streaming responses (generators/async generators).
        # Wrap in sse_frame_stream so each yield becomes a properly
        # framed `data: {json}\n\n` chunk (raw StreamingResponse would
        # emit dict reprs, which is invalid SSE).
        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            import from jac_scale.microservices.gateway_internals.middleware.sse {
                sse_frame_stream
            }
            return StreamingResponse(
                sse_frame_stream(result),
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

"""Get the API protocol for a function by checking its restspec."""
impl JacAPIServerEndpoints.get_function_protocol(func_name: str) -> str {
    functions = self.get_functions();
    if func_name not in functions {
        return APIProtocol.HTTP;
    }
    func_obj = functions[func_name];
    restspec = func_obj.restspec if func_obj?.restspec else None;
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

        walker_kwargs: dict[str, any] = dict(body_data) if body_data else {};

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
    import from jac_scale.ws_backplane { build_backplane }
    if not self._ws_manager {
        ws_cfg = get_scale_config().get_websocket_config();
        backplane = build_backplane(ws_cfg);
        self._ws_manager = WebSocketConnectionManager(
            max_per_target=ws_cfg['max_connections_per_target'],
            max_per_user=ws_cfg['max_connections_per_user'],
            max_anonymous_per_target=ws_cfg['max_anonymous_per_target'],
            send_timeout=SEND_TIMEOUT_SECONDS,
            backplane=backplane
        );
    }
    return self._ws_manager;
}

"""Build the standard {ok:false, error:{...}} frame used over WS."""
def _ws_error_frame(code: str, message: str, reason: (str | None) = None) -> dict {
    err = {'code': code, 'message': message};
    if reason {
        err['reason'] = reason;
    }
    return {'ok': False, 'error': err};
}

"""Validate `?token=...` before accepting the socket. Returns auth detail if
the query param is present, else None. Callers should reject pre-accept on a
non-'ok' status so the client sees a clean handshake rejection."""
def _ws_pre_accept_auth(websocket: WebSocket, user_manager: Any) -> (dict | None) {
    query_token = websocket.query_params.get('token');
    if not query_token {
        return None;
    }
    return user_manager.validate_jwt_token_detail(query_token);
}

"""Reject a connection before accept(). Triggers an HTTP-layer handshake
rejection with the close code, which most clients and proxies surface cleanly
as an auth failure rather than a generic disconnect."""
async def _ws_reject_pre_accept(websocket: WebSocket, auth_detail: dict) {
    status = auth_detail.get('status', 'invalid');
    try {
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason=status);
    } except Exception as e {
        logger.debug(f"WS pre-accept close failed: {e}");
    }
}

"""Read auth from the first frame of an already-accepted WS connection."""
async def _ws_authenticate(
    websocket: WebSocket, user_manager: Any, handshake_timeout: float
) -> (dict, dict | None) {
    try {
        raw = await asyncio.wait_for(
            websocket.receive_text(), timeout=handshake_timeout
        );
    } except asyncio.TimeoutError {
        return (
            {
                'status': 'missing',
                'user_id': None,
                'exp': None,
                'reason': 'Auth handshake timed out'
            },
            None
        );
    }
    try {
        first_data = json.loads(raw);
    } except Exception {
        return (
            {
                'status': 'invalid',
                'user_id': None,
                'exp': None,
                'reason': 'Handshake payload is not valid JSON'
            },
            None
        );
    }
    if not isinstance(first_data, dict) {
        return (
            {
                'status': 'invalid',
                'user_id': None,
                'exp': None,
                'reason': 'Handshake payload must be a JSON object'
            },
            None
        );
    }
    token = first_data.pop('token', None);
    return (user_manager.validate_jwt_token_detail(token), first_data);
}

"""Background heartbeat: send periodic pings; close idle connections."""
async def _ws_heartbeat_loop(
    ctx: ConnectionContext, heartbeat_seconds: float, missed_allowed: int
) -> None {
    try {
        while not ctx.closed {
            await asyncio.sleep(heartbeat_seconds);
            if ctx.closed {
                break;
            }
            now = time.monotonic();
            max_idle = heartbeat_seconds * float(missed_allowed + 1);
            if now - ctx.last_seen > max_idle {
                logger.info(
                    f"WS idle close conn_id={ctx.conn_id}; "
                    f"no message for {now - ctx.last_seen:.1f}s"
                );
                try {
                    await ctx.websocket.close(
                        code=WS_CLOSE_IDLE, reason='idle_timeout'
                    );
                } except Exception as e {
                    logger.debug(f"WS idle close failed: {e}");
                }
                ctx.closed = True;
                break;
            }
            try {
                await ctx.websocket.send_json({'type': 'ping', 'ts': time.time()});
            } except Exception as e {
                logger.debug(f"WS ping send failed conn_id={ctx.conn_id}: {e}");
                break;
            }
        }
    } except asyncio.CancelledError {
        return;
    }
}

"""Reject a failed auth handshake with a structured error then close 4401."""
async def _ws_reject_auth(websocket: WebSocket, auth_detail: dict) {
    status = auth_detail.get('status', 'invalid');
    message_map = {
        'missing': 'Invalid or missing token',
        'expired': 'Token expired',
        'invalid': 'Invalid or missing token',
        'unknown_user': 'User associated with token no longer exists'
    };
    msg = message_map.get(status, 'Invalid or missing token');
    reason = auth_detail.get('reason') or msg;
    try {
        await websocket.send_json(_ws_error_frame('UNAUTHORIZED', msg, reason));
    } except Exception as e {
        logger.debug(f"WS auth-fail send ignored: {e}");
    }
    try {
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason=status);
    } except Exception as e {
        logger.debug(f"WS close after auth failure failed: {e}");
    }
}

"""Reject a connection over capacity caps with a structured error then close 4403."""
async def _ws_reject_capacity(websocket: WebSocket, rejection: str) {
    try {
        await websocket.send_json(
            _ws_error_frame('CAPACITY', 'Connection limit reached', rejection)
        );
    } except Exception as e {
        logger.debug(f"WS capacity-fail send ignored: {e}");
    }
    try {
        await websocket.close(code=WS_CLOSE_FORBIDDEN, reason=rejection);
    } except Exception as e {
        logger.debug(f"WS close after capacity reject failed: {e}");
    }
}

"""Receive one JSON frame from the socket."""
async def _ws_receive_frame(
    websocket: WebSocket, max_bytes: int
) -> (str, dict | None) {
    raw = await websocket.receive_text();
    if len(raw) > max_bytes {
        await websocket.send_json(
            _ws_error_frame('MESSAGE_TOO_LARGE', f'Message exceeds {max_bytes} bytes')
        );
        await websocket.close(code=WS_CLOSE_TOO_LARGE, reason='message_too_large');
        return ('close', None);
    }
    try {
        data = json.loads(raw);
    } except Exception as parse_err {
        await websocket.send_json(
            _ws_error_frame(
                'INVALID_PAYLOAD', 'Payload is not valid JSON', str(parse_err)
            )
        );
        return ('skip', None);
    }
    if not isinstance(data, dict) {
        await websocket.send_json(
            _ws_error_frame('INVALID_PAYLOAD', 'Payload must be a JSON object')
        );
        return ('skip', None);
    }
    return ('ok', data);
}

"""Handle ping/pong, token refresh, expiry enforcement and rate limiting."""
async def _ws_handle_control(
    websocket: WebSocket,
    ctx: ConnectionContext,
    data: dict,
    user_manager: Any,
    requires_auth: bool,
    msgs_per_sec: float,
    rate_capacity: float
) -> str {
    ctrl_type = data.get('type');
    if ctrl_type == 'pong' {
        return 'continue';
    }
    if ctrl_type == 'ping' {
        await websocket.send_json({'type': 'pong', 'ts': time.time()});
        return 'continue';
    }
    if ctrl_type == 'refresh' {
        detail = user_manager.validate_jwt_token_detail(data.get('token'));
        if detail['status'] != 'ok' {
            await websocket.send_json(
                _ws_error_frame(
                    'UNAUTHORIZED', 'Token refresh failed', detail.get('reason')
                )
            );
            await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason=detail['status']);
            return 'break';
        }
        ctx.user_id = detail.get('user_id');
        ctx.exp = detail.get('exp');
        await websocket.send_json({'type': 'refreshed', 'ok': True});
        return 'continue';
    }
    if requires_auth and ctx.exp is not None and time.time() >= float(ctx.exp) {
        await websocket.send_json(
            _ws_error_frame(
                'UNAUTHORIZED', 'Token expired; send a refresh message', 'expired'
            )
        );
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason='expired');
        return 'break';
    }
    if not consume_rate_token(ctx, rate_capacity, msgs_per_sec) {
        await websocket.send_json(
            _ws_error_frame(
                'RATE_LIMITED', f'Rate limit exceeded ({int(msgs_per_sec)} msg/s)'
            )
        );
        return 'continue';
    }
    return 'proceed';
}

"""Cancel the heartbeat task and unregister the connection."""
async def _ws_cleanup(
    heartbeat_task: Any, ws_manager: WebSocketConnectionManager, ctx: ConnectionContext
) {
    heartbeat_task.cancel();
    try {
        await heartbeat_task;
    } except Exception as e {
        logger.debug(f"WS heartbeat task cleanup exception: {e}");
    }
    await ws_manager.unregister(ctx);
}

"""Run an awaitable target (walker spawn or function execute) with a timeout.
Sends a structured EXECUTION_TIMEOUT or INTERNAL_ERROR frame to the client on
failure. Returns (True, result) on success and (False, None) on either error."""
async def _ws_execute_target(
    websocket: WebSocket, label: str, name: str, awaitable: Any, target_timeout: float
) -> (bool, Any) {
    try {
        result = await asyncio.wait_for(awaitable, timeout=target_timeout);
        return (True, result);
    } except asyncio.TimeoutError {
        await websocket.send_json(
            _ws_error_frame(
                'EXECUTION_TIMEOUT',
                f"{label} '{name}' timed out after {int(target_timeout)}s"
            )
        );
        return (False, None);
    } except Exception as e {
        logger.error(f"WS {label.lower()} execution error '{name}': {e}");
        await websocket.send_json(_ws_error_frame('INTERNAL_ERROR', str(e)));
        return (False, None);
    }
}

"""Create a WebSocket handler for a specific walker."""
impl JacAPIServerEndpoints.create_websocket_handler(walker_name: str) -> Callable {
    import from jac_scale.ws_metrics { auth_failure }
    ws_manager = self.get_ws_manager();
    ws_cfg = get_scale_config().get_websocket_config();
    max_bytes = int(ws_cfg['max_message_bytes']);
    target_timeout = float(ws_cfg['target_timeout_seconds']);
    msgs_per_sec = float(ws_cfg['messages_per_second']);
    rate_capacity = max(msgs_per_sec, 1.0);
    requires_auth = self.introspector.is_auth_required_for_walker(walker_name);
    walker_cls = self.get_walkers()[walker_name];
    restspec = walker_cls.restspec
        if walker_cls?.restspec and walker_cls.restspec
        else None;
    is_broadcast = restspec.broadcast if restspec and restspec?.broadcast else False;
    user_manager = self.user_manager;
    execution_manager = self.execution_manager;
    async def websocket_handler(websocket: WebSocket) {
        user_id: (str | None) = None;
        token_exp: (float | None) = None;
        first_data: (dict | None) = None;
        pre_auth: (dict | None) = None;
        if requires_auth {
            pre_auth = _ws_pre_accept_auth(websocket, user_manager);
            if pre_auth is not None and pre_auth['status'] != 'ok' {
                auth_failure(pre_auth['status']);
                await _ws_reject_pre_accept(websocket, pre_auth);
                return;
            }
        }
        await websocket.accept();
        if requires_auth {
            if pre_auth is not None {
                user_id = pre_auth.get('user_id');
                token_exp = pre_auth.get('exp');
            } else {
                (auth_detail, first_data) = await _ws_authenticate(
                    websocket, user_manager, AUTH_HANDSHAKE_TIMEOUT_SECONDS
                );
                if auth_detail['status'] != 'ok' {
                    auth_failure(auth_detail['status']);
                    await _ws_reject_auth(websocket, auth_detail);
                    return;
                }
                user_id = auth_detail.get('user_id');
                token_exp = auth_detail.get('exp');
            }
        }
        ctx = ConnectionContext(
            websocket=websocket,
            target_kind='walker',
            target_name=walker_name,
            user_id=user_id,
            exp=token_exp,
            rate_tokens=rate_capacity
        );
        rejection = await ws_manager.register(ctx);
        if rejection {
            await _ws_reject_capacity(websocket, rejection);
            return;
        }
        heartbeat_task = asyncio.create_task(
            _ws_heartbeat_loop(ctx, HEARTBEAT_SECONDS, HEARTBEAT_MISSED_ALLOWED)
        );
        # broadcast=True fans the result out to every subscriber on
        # `walker:{name}`; otherwise it goes back to the caller only.
        async def send_result(payload: dict) {
            if is_broadcast {
                await ws_manager.broadcast('walker', walker_name, payload);
            } else {
                await websocket.send_json(payload);
            }
        }
        try {
            while True {
                if first_data is not None {
                    data = first_data;
                    first_data = None;
                } else {
                    (status, data) = await _ws_receive_frame(websocket, max_bytes);
                    if status == 'close' {
                        break;
                    }
                    if status == 'skip' {
                        continue;
                    }
                }
                ctx.last_seen = time.monotonic();
                control = await _ws_handle_control(
                    websocket,
                    ctx,
                    data,
                    user_manager,
                    requires_auth,
                    msgs_per_sec,
                    rate_capacity
                );
                if control == 'break' {
                    break;
                }
                if control == 'continue' {
                    continue;
                }
                (ok, result) = await _ws_execute_target(
                    websocket,
                    'Walker',
                    walker_name,
                    execution_manager.spawn_walker(
                        walker_cls, data, (ctx.user_id or Con.GUEST.value)
                    ),
                    target_timeout
                );
                if not ok {
                    continue;
                }
                if isinstance(result, dict) and 'error' in result {
                    # Errors stay private to the caller, even on broadcast targets.
                    await websocket.send_json(
                        _ws_error_frame(
                            'EXECUTION_ERROR',
                            result.get('error', 'Walker execution failed')
                        )
                    );
                } else {
                    await send_result({'ok': True, 'data': result});
                }
            }
        } except WebSocketDisconnect {
            logger.debug(f"WS client disconnected conn_id={ctx.conn_id}");
        } except Exception as e {
            logger.error(f"WS error walker='{walker_name}' conn_id={ctx.conn_id}: {e}");
        } finally {
            await _ws_cleanup(heartbeat_task, ws_manager, ctx);
        }
    }
    return websocket_handler;
}

"""Create a WebSocket handler for a specific def/function."""
impl JacAPIServerEndpoints.create_websocket_function_handler(
    func_name: str
) -> Callable {
    import from jaclang.runtimelib.transport { WebSocketTransport, MessageType }
    import from jac_scale.ws_metrics { auth_failure }
    ws_manager = self.get_ws_manager();
    ws_cfg = get_scale_config().get_websocket_config();
    max_bytes = int(ws_cfg['max_message_bytes']);
    target_timeout = float(ws_cfg['target_timeout_seconds']);
    msgs_per_sec = float(ws_cfg['messages_per_second']);
    rate_capacity = max(msgs_per_sec, 1.0);
    requires_auth = self.introspector.is_auth_required_for_function(func_name);
    func_obj = self.get_functions()[func_name];
    restspec = func_obj.restspec if func_obj?.restspec and func_obj.restspec else None;
    is_broadcast = restspec.broadcast if restspec and restspec?.broadcast else False;
    is_streaming = restspec.streaming if restspec and restspec?.streaming else False;
    user_manager = self.user_manager;
    execution_manager = self.execution_manager;
    async def websocket_handler(websocket: WebSocket) {
        user_id: (str | None) = None;
        token_exp: (float | None) = None;
        first_data: (dict | None) = None;
        pre_auth: (dict | None) = None;
        if requires_auth {
            pre_auth = _ws_pre_accept_auth(websocket, user_manager);
            if pre_auth is not None and pre_auth['status'] != 'ok' {
                auth_failure(pre_auth['status']);
                await _ws_reject_pre_accept(websocket, pre_auth);
                return;
            }
        }
        await websocket.accept();
        if requires_auth {
            if pre_auth is not None {
                user_id = pre_auth.get('user_id');
                token_exp = pre_auth.get('exp');
            } else {
                (auth_detail, first_data) = await _ws_authenticate(
                    websocket, user_manager, AUTH_HANDSHAKE_TIMEOUT_SECONDS
                );
                if auth_detail['status'] != 'ok' {
                    auth_failure(auth_detail['status']);
                    await _ws_reject_auth(websocket, auth_detail);
                    return;
                }
                user_id = auth_detail.get('user_id');
                token_exp = auth_detail.get('exp');
            }
        }
        ctx = ConnectionContext(
            websocket=websocket,
            target_kind='function',
            target_name=func_name,
            user_id=user_id,
            exp=token_exp,
            rate_tokens=rate_capacity
        );
        rejection = await ws_manager.register(ctx);
        if rejection {
            await _ws_reject_capacity(websocket, rejection);
            return;
        }
        heartbeat_task = asyncio.create_task(
            _ws_heartbeat_loop(ctx, HEARTBEAT_SECONDS, HEARTBEAT_MISSED_ALLOWED)
        );
        # broadcast=True fans the result out to every subscriber on
        # `function:{name}`; otherwise it goes back to the caller only.
        async def send_result(payload: dict) {
            if is_broadcast {
                await ws_manager.broadcast('function', func_name, payload);
            } else {
                await websocket.send_json(payload);
            }
        }
        try {
            while True {
                if first_data is not None {
                    data = first_data;
                    first_data = None;
                } else {
                    (status, data) = await _ws_receive_frame(websocket, max_bytes);
                    if status == 'close' {
                        break;
                    }
                    if status == 'skip' {
                        continue;
                    }
                }
                ctx.last_seen = time.monotonic();
                control = await _ws_handle_control(
                    websocket,
                    ctx,
                    data,
                    user_manager,
                    requires_auth,
                    msgs_per_sec,
                    rate_capacity
                );
                if control == 'break' {
                    break;
                }
                if control == 'continue' {
                    continue;
                }
                kwargs = dict(data);
                if is_streaming {
                    kwargs['transport'] = WebSocketTransport(
                        websocket=websocket, sender=send_result
                    );
                }
                (ok, result) = await _ws_execute_target(
                    websocket,
                    'Function',
                    func_name,
                    execution_manager.execute_function(
                        func_obj, kwargs, (ctx.user_id or Con.GUEST.value)
                    ),
                    target_timeout
                );
                if not ok {
                    continue;
                }
                if is_streaming {
                    # Streaming functions emit their payload via the transport;
                    # send a DONE marker so clients know to stop reading.
                    await send_result({'type': MessageType.DONE.value, 'ok': True});
                    continue;
                }
                if isinstance(result, dict) and 'error' in result {
                    # Errors stay private to the caller, even on broadcast targets,
                    # because they typically reflect the caller's bad input.
                    await websocket.send_json(
                        _ws_error_frame(
                            'EXECUTION_ERROR',
                            result.get('error', 'Function execution failed')
                        )
                    );
                } else {
                    await send_result({'ok': True, 'data': result});
                }
            }
        } except WebSocketDisconnect {
            logger.debug(f"WS client disconnected conn_id={ctx.conn_id}");
        } except Exception as e {
            logger.error(f"WS error function='{func_name}' conn_id={ctx.conn_id}: {e}");
        } finally {
            await _ws_cleanup(heartbeat_task, ws_manager, ctx);
        }
    }
    return websocket_handler;
}

"""Register WebSocket endpoints for walkers AND functions with protocol=WEBSOCKET.
Walkers: `/ws/walker/{name}` (canonical) and `/ws/{name}` (legacy, kept for
one release). Functions: `/ws/function/{name}`."""
impl JacAPIServerEndpoints.register_websocket_endpoints -> None {
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBSOCKET {
            handler = self.create_websocket_handler(walker_name);
            self.server.app.websocket(f"/ws/walker/{walker_name}")(handler);
            # Legacy alias; deprecate after clients migrate.
            self.server.app.websocket(f"/ws/{walker_name}")(handler);
            logger.info(
                f"Registered WebSocket walker endpoint: /ws/walker/{walker_name} "
                f"(+ legacy /ws/{walker_name})"
            );
        }
    }
    functions = self.get_functions();
    # Functions with schedule_spec are already filtered by get_functions().
    for func_name in functions {
        protocol = self.get_function_protocol(func_name);
        if protocol == APIProtocol.WEBSOCKET {
            handler = self.create_websocket_function_handler(func_name);
            self.server.app.websocket(f"/ws/function/{func_name}")(handler);
            logger.info(
                f"Registered WebSocket function endpoint: /ws/function/{func_name}"
            );
        }
    }
}
