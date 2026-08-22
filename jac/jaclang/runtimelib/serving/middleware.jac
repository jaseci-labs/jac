import from jaclang.runtimelib.serving.datatypes { Request, Response }


def cors_middleware(
    allow_origins: (list[str] | None) = None,
    allow_credentials: bool = True,
    allow_methods: (list[str] | None) = None,
    allow_headers: (list[str] | None) = None,
    expose_headers: (list[str] | None) = None,
    max_age: int = 600
) -> Callable[..., any] {
    origins = allow_origins if allow_origins is not None else ['*'];
    methods = allow_methods
        if allow_methods is not None
        else ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'];
    headers_allowed = allow_headers
        if allow_headers is not None
        else ['Content-Type', 'Authorization'];
    exposed = expose_headers if expose_headers is not None else [];

    def _origin_value(request: Request) -> str {
        if '*' in origins {
            return '*';
        }
        req_origin = request.headers.get('Origin') or '';
        return req_origin if req_origin in origins else '';
    }

    def _apply(response: Response, origin: str) {
        if not origin {
            return;
        }
        response.headers.set('Access-Control-Allow-Origin', origin);
        if allow_credentials {
            response.headers.set('Access-Control-Allow-Credentials', 'true');
        }
        if exposed {
            response.headers.set('Access-Control-Expose-Headers', ', '.join(exposed));
        }
    }

    async def _middleware(request: Request, call_next: any) -> Response {
        origin = _origin_value(request);
        if request.method == 'OPTIONS'
            and request.headers.get('Access-Control-Request-Method') is not None {
            preflight = Response(content=b'', status_code=200);
            _apply(preflight, origin);
            preflight.headers.set('Access-Control-Allow-Methods', ', '.join(methods));
            preflight.headers.set(
                'Access-Control-Allow-Headers', ', '.join(headers_allowed)
            );
            preflight.headers.set('Access-Control-Max-Age', str(max_age));
            return preflight;
        }
        next_fn: any = call_next;
        response: Response = await next_fn(request);
        _apply(response, origin);
        return response;
    }
    return _middleware;
}

def custom_headers_middleware(
    header_pairs: list[tuple[str, str]]
) -> Callable[..., any] {
    async def _middleware(request: Request, call_next: any) -> Response {
        next_fn: any = call_next;
        response: Response = await next_fn(request);
        for (name, value) in header_pairs {
            response.headers.set(name, value);
        }
        return response;
    }
    return _middleware;
}
