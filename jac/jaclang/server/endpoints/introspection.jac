import from jaclang.server.middleware { unauthorized }
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.endpoint {
    APIParameter,
    HTTPMethod,
    JEndPoint,
    ParameterType
}
import from jaclang.server.server { JacAPIServer }
import from jaclang.server.transport { Meta, TransportResponse }


def _not_found(kind: str, name: str) -> TransportResponse {
    return TransportResponse.fail(
        code='NOT_FOUND',
        message=f"{kind} '{name}' not found",
        meta=Meta(extra={'http_status': 404})
    );
}


def register_introspection_endpoints(server: JacAPIServer) {
    name_param = [
        APIParameter(
            name='name', data_type='string', required=True, kind=ParameterType.PATH
        )
    ];

    def list_functions(request: Request) -> TransportResponse {
        return TransportResponse.success(
            data={'functions': list(server.get_functions().keys())},
            meta=Meta(extra={'http_status': 200})
        );
    }

    def list_walkers(request: Request) -> TransportResponse {
        return TransportResponse.success(
            data={'walkers': list(server.get_walkers().keys())},
            meta=Meta(extra={'http_status': 200})
        );
    }

    def function_info(request: Request, name: str) -> TransportResponse {
        functions = server.get_functions();
        if name not in functions {
            return _not_found('Function', name);
        }
        if server.introspector.is_auth_required_for_function(name)
            and not request.state?.username {
            return unauthorized();
        }
        return TransportResponse.success(
            data={
                'name': name,
                'signature': server.introspector.introspect_callable(functions[name])
            },
            meta=Meta(extra={'http_status': 200})
        );
    }

    def walker_info(request: Request, name: str) -> TransportResponse {
        walkers = server.get_walkers();
        if name not in walkers {
            return _not_found('Walker', name);
        }
        if server.introspector.is_auth_required_for_walker(name)
            and not request.state?.username {
            return unauthorized();
        }
        return TransportResponse.success(
            data={
                'name': name,
                'info': server.introspector.introspect_walker(walkers[name])
            },
            meta=Meta(extra={'http_status': 200})
        );
    }

    for (method, path, cb, params, summary) in [
        (HTTPMethod.GET, '/functions', list_functions, [], 'List functions'),
        (HTTPMethod.GET, '/walkers', list_walkers, [], 'List walkers'),
        (
            HTTPMethod.GET,
            '/function/{name}',
            function_info,
            name_param,
            'Function signature'
        ),
        (HTTPMethod.GET, '/walker/{name}', walker_info, name_param, 'Walker fields')
    ] {
        server.add_endpoint(
            JEndPoint(
                method=method,
                path=path,
                callback=cb,
                parameters=params,
                tags=['Introspection'],
                summary=summary,
                forward_undeclared_query_params=False
            )
        );
    }
}
