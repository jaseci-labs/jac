impl JacAPIServerEndpoints.register_walkers_endpoints -> None {
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBHOOK or protocol == APIProtocol.WEBSOCKET {
            continue;
        }
        walker_cls = self.get_walkers()[walker_name];

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
                description='API Entry',
                forward_undeclared_query_params=False
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
                description='API Root',
                forward_undeclared_query_params=False
            )
        );
    }
}

impl JacAPIServerEndpoints.create_walker_parameters(
    walker_name: str, invoke_on_root: bool, method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    import from typing { get_type_hints }
    parameters: list[APIParameter] = [];

    walker_cls = self.get_walkers()[walker_name];
    restspec = walker_cls.restspec if walker_cls?.restspec else None;
    spec_path = restspec.path if restspec else None;
    path_param_names = _extract_path_param_names(spec_path);
    walker_fields = self.introspector.introspect_walker(self.get_walkers()[walker_name])[
        'fields'
    ];

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

        if field_name == '_jac_spawn_node' or field_name in path_param_names {
            param_type = ParameterType.PATH;
        } elif ('UploadFile' in field_type or 'uploadfile' in field_type.lower()) {
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
            import from jaclang.scale.runtime.middleware.sse { sse_frame_stream }
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
            if result.get('error') == 'User not found' {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized: unknown user',
                    meta=Meta(extra={'http_status': 401})
                );
            }
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

impl JacAPIServerEndpoints.register_functions_endpoints -> None {
    for func_name in self.get_functions() {
        func_obj = self.get_functions()[func_name];

        if func_obj?.schedule_spec {
            continue;
        }
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
                description='This is a description',
                forward_undeclared_query_params=False
            )
        );
    }
}

impl JacAPIServerEndpoints.create_function_parameters(
    func_name: str, method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    import from typing { get_type_hints }
    parameters: list[APIParameter] = [];

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

        if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
            import from jaclang.scale.runtime.middleware.sse { sse_frame_stream }
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
            if result.get('error') == 'User not found' {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Unauthorized: unknown user',
                    meta=Meta(extra={'http_status': 401})
                );
            }
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

impl JacAPIServerEndpoints.create_webhook_callback(
    walker_name: str
) -> Callable[..., TransportResponse] {
    async def _process(request: Request, **kwargs: JsonValue) -> TransportResponse {
        import time;

        webhook_config = get_scale_config().get_webhook_config();
        signature_header = webhook_config.get(
            'signature_header', 'X-Webhook-Signature'
        );
        timestamp_header = webhook_config.get(
            'timestamp_header', 'X-Webhook-Timestamp'
        );
        verify_signature = webhook_config.get('verify_signature', True);
        replay_tolerance = int(webhook_config.get('replay_tolerance_seconds', 300));
        max_body_bytes = int(webhook_config.get('max_body_bytes', 1048576));
        rate_limit = int(webhook_config.get('rate_limit_per_minute', 0));

        api_key = request.headers.get('X-API-Key');
        if not api_key {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Missing X-API-Key header',
                meta=Meta(extra={'http_status': 401})
            );
        }

        key_doc = self.get_api_key_manager().resolve_key(api_key);
        user_id = key_doc.get('user_id') if key_doc else None;

        if not user_id or not self.user_manager.user_exists(user_id) {
            return TransportResponse.fail(
                code='UNAUTHORIZED',
                message='Invalid or expired API key',
                meta=Meta(extra={'http_status': 401})
            );
        }

        allowed_walkers = key_doc.get('allowed_walkers') or [];
        if allowed_walkers and walker_name not in allowed_walkers {
            return TransportResponse.fail(
                code='FORBIDDEN',
                message='API key is not permitted to call this webhook',
                meta=Meta(extra={'http_status': 403})
            );
        }

        if not self.get_api_key_manager().check_rate_limit(
            key_doc.get('_id', ''), rate_limit
        ) {
            return TransportResponse.fail(
                code='RATE_LIMITED',
                message='Rate limit exceeded',
                meta=Meta(extra={'http_status': 429})
            );
        }

        def _too_large -> TransportResponse {
            return TransportResponse.fail(
                code='PAYLOAD_TOO_LARGE',
                message='Request body too large',
                meta=Meta(extra={'http_status': 413})
            );
        }
        content_length = request.headers.get('content-length');
        if content_length {
            try {
                if int(content_length) > max_body_bytes {
                    return _too_large();
                }
            } except Exception { }
        }

        raw_body = await request.body();
        if len(raw_body) > max_body_bytes {
            return _too_large();
        }

        if verify_signature {
            signature = request.headers.get(signature_header);
            if not signature {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message=f"Missing {signature_header} header",
                    meta=Meta(extra={'http_status': 401})
                );
            }

            timestamp = request.headers.get(timestamp_header);
            if not timestamp {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message=f"Missing {timestamp_header} header",
                    meta=Meta(extra={'http_status': 401})
                );
            }
            try {
                request_ts = int(timestamp);
            } except Exception {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Invalid webhook timestamp',
                    meta=Meta(extra={'http_status': 401})
                );
            }
            if abs(int(time.time()) - request_ts) > replay_tolerance {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Webhook timestamp outside allowed window',
                    meta=Meta(extra={'http_status': 401})
                );
            }
            signing_secret = key_doc.get('signing_secret');
            if not signing_secret {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Invalid webhook signature',
                    meta=Meta(extra={'http_status': 401})
                );
            }

            signed_payload = f"{timestamp}.".encode('utf-8') + raw_body;
            extracted_signature = WebhookUtils.extract_signature(signature);
            if not WebhookUtils.verify_signature(
                signed_payload, extracted_signature, signing_secret
            ) {
                return TransportResponse.fail(
                    code='UNAUTHORIZED',
                    message='Invalid webhook signature',
                    meta=Meta(extra={'http_status': 401})
                );
            }
        }

        try {
            body_data = json.loads(raw_body) if raw_body else {};
        } except Exception {
            body_data = {};
        }

        walker_fields = self.introspector.introspect_walker(
            self.get_walkers()[walker_name]
        )['fields'];
        walker_kwargs: dict[str, any] = {};
        if isinstance(body_data, dict) {
            for (field_name, value) in body_data.items() {
                if field_name in walker_fields and field_name != '_jac_spawn_node' {
                    walker_kwargs[field_name] = value;
                }
            }
        }

        result = await self.execution_manager.spawn_walker(
            self.get_walkers()[walker_name], walker_kwargs, user_id
        );

        if 'error' in result {
            logger.error(
                f"Webhook walker '{walker_name}' failed: "
                f"{result.get('error')} {result.get('traceback', '')}"
            );
            return TransportResponse.fail(
                code='EXECUTION_ERROR',
                message='Webhook processing failed',
                meta=Meta(extra={'http_status': 500})
            );
        }

        return TransportResponse.success(
            data=result, meta=Meta(extra={'http_status': 200})
        );
    }
    async def callback(request: Request, **kwargs: JsonValue) -> TransportResponse {
        client_ip = request.client.host if request?.client else '-';
        resp = await _process(request, **kwargs);
        status = resp.meta.extra.get('http_status') if resp?.meta else None;
        outcome = 'ok' if resp.ok else (resp.error.code if resp?.error else 'error');
        audit_line = (
            f"webhook audit walker={walker_name} ip={client_ip} "
            f"status={status} outcome={outcome}"
        );
        if resp.ok {
            logger.info(audit_line);
        } else {
            logger.warning(audit_line);
        }
        return resp;
    }
    return callback;
}

impl JacAPIServerEndpoints.create_webhook_parameters(
    walker_name: str
) -> list[APIParameter] {
    parameters: list[APIParameter] = [];
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

    parameters.append(
        APIParameter(
            name='x_webhook_signature',
            data_type='string',
            required=False,
            default=None,
            description='HMAC-SHA256 signature of "<timestamp>." + body, signed with the signing_secret (X-Webhook-Signature header)',
            type=ParameterType.HEADER
        )
    );

    parameters.append(
        APIParameter(
            name='x_webhook_timestamp',
            data_type='string',
            required=False,
            default=None,
            description='Unix timestamp (seconds) of the request, bound into the signature (X-Webhook-Timestamp header)',
            type=ParameterType.HEADER
        )
    );

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

impl JacAPIServerEndpoints.register_webhook_endpoints -> None {
    has_webhook_walkers = False;
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);

        if protocol == APIProtocol.WEBHOOK {
            has_webhook_walkers = True;
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
    if has_webhook_walkers {
        self.get_api_key_manager();
    }
}

impl JacAPIServerEndpoints.get_ws_manager -> WebSocketConnectionManager {
    if not self._ws_manager {
        ws_cfg = get_scale_config().get_websocket_config();
        backplane = build_backplane(ws_cfg);
        manager = WebSocketConnectionManager(
            max_per_target=int(ws_cfg['max_connections_per_target']),
            max_per_user=int(ws_cfg['max_connections_per_user']),
            max_anonymous_per_target=int(ws_cfg['max_anonymous_per_target']),
            send_timeout=SEND_TIMEOUT_SECONDS,
            backplane=backplane,
            metrics=self._metrics
        );
        self._ws_manager = manager;
        async def _shutdown_ws_manager {
            await manager.shutdown();
        }
        self.server.app.router.on_shutdown.append(_shutdown_ws_manager);
    }
    return self._ws_manager;
}

async def _ws_serve_connection(
    websocket: WebSocket,
    ws_manager: WebSocketConnectionManager,
    user_manager: any,
    requires_auth: bool,
    target_kind: str,
    target_name: str,
    is_broadcast: bool,
    label: str,
    max_bytes: int,
    target_timeout: float,
    msgs_per_sec: float,
    make_awaitable: any
) {
    rate_capacity = max(msgs_per_sec, 1.0);
    user_id: (str | None) = None;
    token_exp: (float | None) = None;
    first_data: (dict | None) = None;
    pre_auth: (dict | None) = None;
    if requires_auth {
        pre_auth = ws_pre_accept_auth(websocket, user_manager);
        if pre_auth is not None and pre_auth['status'] != 'ok' {
            await ws_reject_pre_accept(websocket, pre_auth);
            return;
        }
    }
    await websocket.accept();
    if requires_auth {
        if pre_auth is not None {
            user_id = pre_auth.get('user_id');
            token_exp = pre_auth.get('exp');
        } else {
            (auth_detail, first_data) = await ws_authenticate(
                websocket, user_manager, AUTH_HANDSHAKE_TIMEOUT_SECONDS, max_bytes
            );
            if auth_detail['status'] != 'ok' {
                await ws_reject_auth(websocket, auth_detail);
                return;
            }
            user_id = auth_detail.get('user_id');
            token_exp = auth_detail.get('exp');
        }
    }
    ctx = ConnectionContext(
        websocket=websocket,
        target_kind=target_kind,
        target_name=target_name,
        user_id=user_id,
        exp=token_exp,
        rate_tokens=rate_capacity
    );
    rejection = await ws_manager.register(ctx);
    if rejection {
        await ws_reject_registration(websocket, rejection);
        return;
    }
    heartbeat_task = asyncio.create_task(
        ws_heartbeat_loop(ctx, HEARTBEAT_SECONDS, HEARTBEAT_MISSED_ALLOWED)
    );
    async def send_result(payload: dict) {
        if is_broadcast {
            await ws_manager.broadcast_target(target_kind, target_name, payload);
        } else {
            await websocket.send_json(payload);
        }
    }
    try {
        while True {
            if first_data {
                data = first_data;
                first_data = None;
            } else {
                (status, data) = await ws_receive_frame(websocket, max_bytes);
                if status == 'close' {
                    break;
                }
                if status == 'skip' {
                    continue;
                }
            }
            ctx.last_seen = time.monotonic();
            control = await ws_handle_control(
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
            data.pop('token', None);
            (ok, result) = await ws_execute_target(
                websocket,
                label,
                target_name,
                make_awaitable(data, (ctx.user_id or Con.GUEST.value)),
                target_timeout
            );
            if not ok {
                continue;
            }
            if (isgenerator(result) or isinstance(result, AsyncGenerator)) {
                await _ws_stream_result(send_result, result);
            } elif isinstance(result, dict) and 'error' in result {
                await websocket.send_json(
                    ws_error_frame(
                        'EXECUTION_ERROR',
                        result.get('error', f"{label} execution failed")
                    )
                );
            } else {
                await send_result({'ok': True, 'data': result});
            }
        }
    } except WebSocketDisconnect {
        logger.debug(f"WS client disconnected conn_id={ctx.conn_id}");
    } except Exception as e {
        logger.error(
            f"WS error {label.lower()}='{target_name}' conn_id={ctx.conn_id}: {e}"
        );
    } finally {
        heartbeat_task.cancel();
        try {
            await heartbeat_task;
        } except Exception as e {
            logger.debug(f"WS heartbeat cleanup exception: {e}");
        }
        await ws_manager.unregister(ctx);
    }
}

impl JacAPIServerEndpoints._create_websocket_target_handler(
    target_kind: str,
    target_name: str,
    target: any,
    requires_auth: bool,
    execute: Callable
) -> Callable {
    ws_manager = self.get_ws_manager();
    ws_cfg = get_scale_config().get_websocket_config();
    restspec = target.restspec if target?.restspec and target.restspec else None;
    is_broadcast = restspec.broadcast if restspec and restspec?.broadcast else False;
    user_manager = self.user_manager;
    async def websocket_handler(websocket: WebSocket) {
        def make_awaitable(data: dict, user: str) -> any {
            return execute(target, data, user);
        }
        await _ws_serve_connection(
            websocket,
            ws_manager,
            user_manager,
            requires_auth,
            target_kind,
            target_name,
            bool(is_broadcast),
            target_kind.capitalize(),
            int(ws_cfg['max_message_bytes']),
            float(ws_cfg['target_timeout_seconds']),
            float(ws_cfg['messages_per_second']),
            make_awaitable
        );
    }
    return websocket_handler;
}

impl JacAPIServerEndpoints.create_websocket_handler(walker_name: str) -> Callable {
    return self._create_websocket_target_handler(
        'walker',
        walker_name,
        self.get_walkers()[walker_name],
        self.introspector.is_auth_required_for_walker(walker_name),
        self.execution_manager.spawn_walker
    );
}

impl JacAPIServerEndpoints.create_websocket_function_handler(
    func_name: str
) -> Callable {
    return self._create_websocket_target_handler(
        'function',
        func_name,
        self.get_functions()[func_name],
        self.introspector.is_auth_required_for_function(func_name),
        self.execution_manager.execute_function
    );
}

impl JacAPIServerEndpoints.register_websocket_endpoints -> None {
    for walker_name in self.get_walkers() {
        protocol = self.get_walker_protocol(walker_name);
        if protocol == APIProtocol.WEBSOCKET {
            handler = self.create_websocket_handler(walker_name);
            self.server.app.websocket(f"/ws/walker/{walker_name}")(handler);
            self.server.app.websocket(f"/ws/{walker_name}")(handler);
            logger.info(
                f"Registered WebSocket walker endpoint: /ws/walker/{walker_name} "
                f"(+ legacy /ws/{walker_name})"
            );
        }
    }
    for func_name in self.get_functions() {
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
