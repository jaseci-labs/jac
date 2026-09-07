import from jaclang.server.endpoint_contract { check_endpoint_contract }
import json;
import logging;
import from inspect { isgenerator }
import from typing { AsyncGenerator, get_type_hints }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.runtime.builtin { APIProtocol }
import from jaclang.server.serving.datatypes { Request, Response, StreamingResponse }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.outbox {
    remember_response,
    replay_cached,
    scoped_idempotency_key
}
import from jaclang.server.serving.router { path_param_names }
import from jaclang.server.serving.sse { sse_frame_stream }
import from jaclang.server.server {
    JacAPIServer,
    JsonValue,
    target_restspec,
    target_schedule_spec
}
import from jaclang.server.sv_client { IDEMPOTENCY_HEADER, bridge_identity }
import from jaclang.server.transport { Meta, TransportResponse }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def _unauthorized -> TransportResponse {
    return TransportResponse.fail(
        code='UNAUTHORIZED',
        message='Unauthorized',
        meta=Meta(extra={'http_status': 401})
    );
}


def request_caller(server: JacAPIServer, request: Request) -> (str | None) {
    username: (str | None) = request.state?.username;
    if username {
        return username;
    }
    ident = bridge_identity(request.headers.get('Authorization'));
    if not ident {
        return None;
    }
    if not server.user_manager.user_exists(ident) {
        server.user_manager.create_user(ident, '__no_password__');
    }
    return ident;
}


def idempotency_key(request: Request, username: str, app: str, target: str) -> str {
    return scoped_idempotency_key(
        str(request.headers.get(IDEMPOTENCY_HEADER) or ''), username, app, target
    );
}


def _stream(result: any) -> StreamingResponse {
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


def _failure(result: dict, fallback: str) -> TransportResponse {
    if result.get('error') == 'User not found' {
        return TransportResponse.fail(
            code='UNAUTHORIZED',
            message='Unauthorized: unknown user',
            meta=Meta(extra={'http_status': 401})
        );
    }
    return TransportResponse.fail(
        code=str(result.get('error_code') or 'EXECUTION_ERROR').upper(),
        message=result.get('error', fallback),
        details=result.get('traceback') if 'traceback' in result else None,
        meta=Meta(extra={'http_status': int(result.get('http_status') or 500)})
    );
}


def _param_kind(
    field_name: str, field_type: str, path_names: list[str], method: HTTPMethod
) -> ParameterType {
    if field_name in path_names {
        return ParameterType.PATH;
    }
    if 'UploadFile' in field_type or 'uploadfile' in field_type.lower() {
        return ParameterType.FILE;
    }
    if method == HTTPMethod.GET {
        return ParameterType.QUERY;
    }
    return ParameterType.BODY;
}


def walker_parameters(
    server: JacAPIServer,
    walker_name: str,
    invoke_on_root: bool,
    method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    walker_cls = server.get_walkers()[walker_name];
    restspec: any = target_restspec(walker_cls);
    path_names = path_param_names(str(restspec.path) if restspec?.path else None);
    fields = server.introspector.introspect_walker(walker_cls)['fields'];
    try {
        hints = get_type_hints(walker_cls.init);
    } except Exception {
        hints = {};
    }
    parameters: list[APIParameter] = [];
    for field_name in fields {
        if field_name == '_jac_spawn_node' and invoke_on_root {
            continue;
        }
        field_type = fields[field_name]['type'];
        kind = ParameterType.PATH
            if field_name == '_jac_spawn_node'
            else _param_kind(field_name, field_type, path_names, method);
        type_obj = fields[field_name].get('type_obj')
            if isinstance(fields[field_name], dict)
            else None;
        if type_obj is None {
            type_obj = hints.get(field_name);
        }
        parameters.append(
            APIParameter(
                name='nd' if field_name == '_jac_spawn_node' else field_name,
                data_type=field_type,
                type_obj=type_obj,
                required=fields[field_name]['required'],
                default_value=fields[field_name]['default'],
                description=f"Field {field_name} for walker {walker_name}",
                kind=kind
            )
        );
    }
    return parameters;
}


def walker_callback(
    server: JacAPIServer, walker_name: str
) -> Callable[..., (TransportResponse | StreamingResponse | Response)] {
    requires_auth = server.introspector.is_auth_required_for_walker(walker_name);

    async def callback(
        request: Request, nd: (str | None) = None, **kwargs: JsonValue
    ) -> (TransportResponse | StreamingResponse | Response) {
        username = request_caller(server, request);
        if requires_auth and not username {
            return _unauthorized();
        }
        if nd {
            kwargs['_jac_spawn_node'] = nd;
        }
        import from jaclang.server.sv_client { consumer_app }
        mismatch = check_endpoint_contract(
            request,
            server.get_walkers()[walker_name],
            "walker",
            walker_name,
            consumer_app()
        );
        if mismatch is not None {
            return mismatch;
        }
        caller = username or Con.GUEST.value;
        idem = idempotency_key(request, caller, server.module_name, walker_name);
        replay = replay_cached(idem);
        if replay is not None {
            return replay;
        }
        result = await server.execution_manager.spawn_walker(
            server.get_walkers()[walker_name], kwargs, caller
        );
        if isgenerator(result) or isinstance(result, AsyncGenerator) {
            return _stream(result);
        }
        if isinstance(result, dict) and 'error' in result {
            return _failure(result, 'Walker execution failed');
        }
        return remember_response(
            idem,
            TransportResponse.success(
                data=result, meta=Meta(extra={'http_status': 200})
            )
        );
    }
    return callback;
}


def register_walker_endpoints(server: JacAPIServer) {
    for walker_name in list(server.get_walkers()) {
        walker_cls = server.get_walkers()[walker_name];
        protocol = server.introspector.walker_protocol(walker_name);
        if protocol in (APIProtocol.WEBHOOK, APIProtocol.WEBSOCKET) {
            continue;
        }
        if target_schedule_spec(walker_cls) is not None {
            continue;
        }
        restspec: any = target_restspec(walker_cls);
        method: HTTPMethod = (
            HTTPMethod(restspec.method) if restspec?.method else HTTPMethod.POST
        );
        path: str = str(restspec.path) if restspec?.path else f"/walker/{walker_name}";
        requires_auth = server.introspector.is_auth_required_for_walker(walker_name);
        callback = walker_callback(server, walker_name);
        server.add_endpoint(
            JEndPoint(
                method=method,
                path=f"{path}/{{nd}}",
                callback=callback,
                parameters=walker_parameters(
                    server, walker_name, invoke_on_root=False, method=method
                ),
                tags=['Walkers'],
                summary=f"Spawn {walker_name} on a node",
                description=f"Spawn the {walker_name} walker on the node named by `nd`.",
                requires_auth=requires_auth,
                forward_undeclared_query_params=False
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=method,
                path=path,
                callback=callback,
                parameters=walker_parameters(
                    server, walker_name, invoke_on_root=True, method=method
                ),
                tags=['Walkers'],
                summary=f"Spawn {walker_name}",
                description=f"Spawn the {walker_name} walker on the caller's root.",
                requires_auth=requires_auth,
                forward_undeclared_query_params=False
            )
        );
    }
}


def function_parameters(
    server: JacAPIServer, func_name: str, method: HTTPMethod = HTTPMethod.POST
) -> list[APIParameter] {
    func_obj = server.get_functions()[func_name];
    restspec: any = target_restspec(func_obj);
    path_names = path_param_names(str(restspec.path) if restspec?.path else None);
    fields = server.introspector.introspect_callable(func_obj)['parameters'];
    try {
        hints = get_type_hints(func_obj);
    } except Exception {
        hints = {};
    }
    parameters: list[APIParameter] = [];
    for field_name in fields {
        field_type = fields[field_name]['type'];
        type_obj = fields[field_name].get('type_obj')
            if isinstance(fields[field_name], dict)
            else None;
        if type_obj is None {
            type_obj = hints.get(field_name);
        }
        parameters.append(
            APIParameter(
                name=field_name,
                data_type=field_type,
                type_obj=type_obj,
                required=fields[field_name]['required'],
                default_value=fields[field_name]['default'],
                description=f"Field {field_name} for function {func_name}",
                kind=_param_kind(field_name, field_type, path_names, method)
            )
        );
    }
    return parameters;
}


def function_callback(
    server: JacAPIServer, func_name: str
) -> Callable[..., (TransportResponse | StreamingResponse | Response)] {
    requires_auth = server.introspector.is_auth_required_for_function(func_name);
    func_obj = server.get_functions()[func_name];
    restspec: any = target_restspec(func_obj);
    raw_body: bool = restspec is not None and not restspec.envelope;
    raw_media: str = str(restspec.produces or 'text/plain')
        if restspec
        else 'text/plain';

    async def callback(
        request: Request, **kwargs: JsonValue
    ) -> (TransportResponse | StreamingResponse | Response) {
        username = request_caller(server, request);
        if requires_auth and not username {
            return _unauthorized();
        }
        import from jaclang.server.sv_client { consumer_app }
        mismatch = check_endpoint_contract(
            request, func_obj, "func", func_name, consumer_app()
        );
        if mismatch is not None {
            return mismatch;
        }
        caller = username or Con.GUEST.value;
        idem = idempotency_key(request, caller, server.module_name, func_name);
        replay = replay_cached(idem);
        if replay is not None {
            return replay;
        }
        logger.debug(f"function {func_name}: {sorted(kwargs)}");
        result = await server.execution_manager.execute_function(
            server.get_functions()[func_name], kwargs, caller
        );
        if isgenerator(result) or isinstance(result, AsyncGenerator) {
            return _stream(result);
        }
        if isinstance(result, dict) and 'error' in result {
            return _failure(result, 'Function execution failed');
        }
        if raw_body {
            payload = result.get('result') if isinstance(result, dict) else result;
            if isinstance(payload, bytes) {
                body = payload;
            } elif isinstance(payload, str) {
                body = payload.encode('utf-8');
            } elif payload is None {
                body = b"";
            } else {
                body = json.dumps(payload).encode('utf-8');
            }
            return Response(content=body, media_type=raw_media);
        }
        return remember_response(
            idem,
            TransportResponse.success(
                data=result, meta=Meta(extra={'http_status': 200})
            )
        );
    }
    return callback;
}


def register_function_endpoints(server: JacAPIServer) {
    for func_name in list(server.get_functions()) {
        func_obj = server.get_functions()[func_name];
        if target_schedule_spec(func_obj) is not None {
            continue;
        }
        if server.introspector.function_protocol(func_name) == APIProtocol.WEBSOCKET {
            continue;
        }
        restspec: any = target_restspec(func_obj);
        method: HTTPMethod = (
            HTTPMethod(restspec.method) if restspec?.method else HTTPMethod.POST
        );
        path: str = str(restspec.path) if restspec?.path else f"/function/{func_name}";
        raw_body: bool = restspec is not None and not restspec.envelope;
        raw_media: (str | None) = (
            str(restspec.produces or 'text/plain') if raw_body else None
        );
        server.add_endpoint(
            JEndPoint(
                method=method,
                path=path,
                callback=function_callback(server, func_name),
                parameters=function_parameters(server, func_name, method=method),
                media_type=raw_media,
                tags=['Functions'],
                summary=f"Call {func_name}",
                description=f"Call the {func_name} function.",
                requires_auth=server.introspector.is_auth_required_for_function(
                    func_name
                ),
                forward_undeclared_query_params=False
            )
        );
    }
}
