import logging;
import os;
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.project.config { get_config }
import from jaclang.server.endpoints.walkers { idempotency_key, request_caller }
import from jaclang.server.outbox { remember_response, replay_cached }
import from jaclang.server.serving.datatypes { Request, Response }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.server { JacAPIServer, JsonValue, ModuleIntrospector }
import from jaclang.server.sv_client { _local_providers }
import from jaclang.server.transport { Meta, TransportResponse }

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def colocated_providers -> dict[str, any] {
    return dict(_local_providers);
}


def provider_route(config: any, provider_app: str) -> str {
    provider_cfg = config.app(provider_app) if config is not None else None;
    route: str = str(provider_cfg.effective_route())
        if provider_cfg is not None
        else f"/api/{provider_app}";
    return route.rstrip('/');
}


def _body(request: Request) -> (dict | None) {
    if not request.body {
        return {};
    }
    try {
        parsed = request.json_sync();
    } except Exception {
        return None;
    }
    return parsed if isinstance(parsed, dict) else {};
}


def _fail(code: str, message: str, status: int) -> TransportResponse {
    return TransportResponse.fail(
        code=code, message=message, meta=Meta(extra={'http_status': status})
    );
}


def _outcome(result: any, fallback: str) -> TransportResponse {
    if isinstance(result, dict) and 'error' in result {
        if result.get('error') == 'User not found' {
            return _fail('UNAUTHORIZED', 'Unauthorized: unknown user', 401);
        }
        return TransportResponse.fail(
            code=str(result.get('error_code') or 'EXECUTION_ERROR').upper(),
            message=result.get('error', fallback),
            details=result.get('traceback') if 'traceback' in result else None,
            meta=Meta(extra={'http_status': int(result.get('http_status') or 500)})
        );
    }
    return TransportResponse.success(
        data=result, meta=Meta(extra={'http_status': 200})
    );
}


def _walker_callback(
    server: JacAPIServer,
    provider_app: str,
    walker_name: str,
    walker_cls: any,
    requires_auth: bool
) -> Callable[..., (TransportResponse | Response)] {
    async def callback(
        request: Request, nd: (str | None) = None, **kwargs: JsonValue
    ) -> (TransportResponse | Response) {
        username = request_caller(server, request);
        if requires_auth and not username {
            return _fail('UNAUTHORIZED', 'Unauthorized', 401);
        }
        fields = _body(request);
        if fields is None {
            return _fail('INVALID_JSON', 'Invalid JSON', 400);
        }
        if nd {
            fields['_jac_spawn_node'] = nd;
        }
        caller = username or Con.GUEST.value;
        key = idempotency_key(request, caller, provider_app, walker_name);
        replay = replay_cached(key);
        if replay is not None {
            return replay;
        }
        result = await server.execution_manager.spawn_walker(
            walker_cls, fields, caller
        );
        return remember_response(key, _outcome(result, 'Walker execution failed'));
    }
    return callback;
}


def _function_callback(
    server: JacAPIServer,
    provider_app: str,
    func_name: str,
    func_obj: any,
    requires_auth: bool
) -> Callable[..., (TransportResponse | Response)] {
    async def callback(
        request: Request, **kwargs: JsonValue
    ) -> (TransportResponse | Response) {
        username = request_caller(server, request);
        if requires_auth and not username {
            return _fail('UNAUTHORIZED', 'Unauthorized', 401);
        }
        args = _body(request);
        if args is None {
            return _fail('INVALID_JSON', 'Invalid JSON', 400);
        }
        caller = username or Con.GUEST.value;
        key = idempotency_key(request, caller, provider_app, func_name);
        replay = replay_cached(key);
        if replay is not None {
            return replay;
        }
        result = await server.execution_manager.execute_function(
            func_obj, args, caller
        );
        return remember_response(key, _outcome(result, 'Function execution failed'));
    }
    return callback;
}


def _listing(names: list[str], key: str) -> Callable[..., TransportResponse] {
    async def callback(request: Request, **kwargs: JsonValue) -> TransportResponse {
        return TransportResponse.success(
            data={key: list(names)}, meta=Meta(extra={'http_status': 200})
        );
    }
    return callback;
}


def _mount_provider(
    server: JacAPIServer, provider_app: str, route: str, intro: ModuleIntrospector
) {
    walkers = intro.get_walkers();
    functions = intro.get_functions();
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path=f"{route}/walkers",
            callback=_listing(list(walkers.keys()), 'walkers'),
            parameters=[],
            tags=['Colocated'],
            summary=f"Walkers of {provider_app}",
            description=f"Walkers served for the colocated app {provider_app}.",
            forward_undeclared_query_params=False
        )
    );
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path=f"{route}/functions",
            callback=_listing(list(functions.keys()), 'functions'),
            parameters=[],
            tags=['Colocated'],
            summary=f"Functions of {provider_app}",
            description=f"Functions served for the colocated app {provider_app}.",
            forward_undeclared_query_params=False
        )
    );
    for (walker_name, walker_cls) in walkers.items() {
        walker_auth = intro.is_auth_required_for_walker(walker_name);
        cb = _walker_callback(
            server, provider_app, walker_name, walker_cls, walker_auth
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"{route}/walker/{walker_name}/{{nd}}",
                callback=cb,
                parameters=[APIParameter(name='nd', kind=ParameterType.PATH)],
                tags=['Colocated'],
                summary=f"{provider_app}.{walker_name}",
                description=f"Spawn {walker_name} in the colocated app {provider_app} on a node.",
                requires_auth=walker_auth,
                forward_undeclared_query_params=False
            )
        );
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"{route}/walker/{walker_name}",
                callback=cb,
                parameters=[],
                tags=['Colocated'],
                summary=f"{provider_app}.{walker_name}",
                description=f"Spawn {walker_name} in the colocated app {provider_app}.",
                requires_auth=walker_auth,
                forward_undeclared_query_params=False
            )
        );
    }
    for (func_name, func_obj) in functions.items() {
        func_auth = intro.is_auth_required_for_function(func_name);
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path=f"{route}/function/{func_name}",
                callback=_function_callback(
                    server, provider_app, func_name, func_obj, func_auth
                ),
                parameters=[],
                tags=['Colocated'],
                summary=f"{provider_app}.{func_name}",
                description=f"Call {func_name} in the colocated app {provider_app}.",
                requires_auth=func_auth,
                forward_undeclared_query_params=False
            )
        );
    }
}


def served_app_route(server: JacAPIServer) -> tuple[str, str, any] {
    import from jaclang.project.config { get_config_for_dir }
    import from jaclang.server.sv_client { consumer_app }
    served = consumer_app();
    if not served {
        return ('', '', None);
    }
    config = get_config_for_dir(server.base_path) if server.base_path else None;
    if config is None {
        config = get_config();
    }
    if config is None or served not in (config.apps or {}) {
        return ('', '', config);
    }
    return (served, provider_route(config, served), config);
}

def register_colocated_endpoints(server: JacAPIServer) {
    (served, served_route, config) = served_app_route(server);
    if served and served_route {
        _mount_provider(server, served, served_route, server.introspector);
    }
    providers = colocated_providers();
    if not providers {
        return;
    }
    if config is None {
        config = get_config();
    }
    for (provider_app, provider_module) in providers.items() {
        mod_file = provider_module?.__file__;
        intro = ModuleIntrospector(
            module_name=str(provider_module?.__name__ or provider_app),
            base_path=(os.path.dirname(mod_file) if mod_file else server.base_path),
            module_file=mod_file
        );
        try {
            intro.load();
        } except Exception as exc {
            logger.warning(
                f"Colocated app '{provider_app}' could not be introspected: {exc}"
            );
            continue;
        }
        _mount_provider(
            server, provider_app, provider_route(config, provider_app), intro
        );
    }
}
