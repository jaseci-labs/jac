impl cors_middleware(
    allow_origins: (list[str] | None) = None,
    allow_credentials: bool = False,
    allow_methods: (list[str] | None) = None,
    allow_headers: (list[str] | None) = None,
    expose_headers: (list[str] | None) = None,
    max_age: int = 600
) -> Callable[..., any] {
    origins = allow_origins if allow_origins is not None else ['*'];
    problem = cors_pair_problem(origins, allow_credentials);
    if problem {
        raise ValueError(problem);
    }
    methods = allow_methods
        if allow_methods is not None
        else ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'];
    any_method = '*' in methods;
    listed_methods = [
        m
        for m in methods
        if m != '*'
    ];
    headers_allowed = allow_headers
        if allow_headers is not None
        else ['Content-Type', 'Authorization'];
    any_header = '*' in headers_allowed;
    exposed = expose_headers if expose_headers is not None else [];
    any_origin = '*' in origins;

    def _origin_value(request: Request) -> str {
        if any_origin {
            return '*';
        }
        req_origin = request.headers.get('Origin') or '';
        return req_origin if req_origin in origins else '';
    }

    def _apply(response: Response, origin: str) {
        if not any_origin {
            response.headers.add_vary('Origin');
        }
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
            allowed_methods = list(listed_methods);
            if any_method {
                wanted = str(request.headers.get('Access-Control-Request-Method'));
                if wanted not in allowed_methods {
                    allowed_methods.append(wanted);
                }
                preflight.headers.add_vary('Access-Control-Request-Method');
            }
            preflight.headers.set(
                'Access-Control-Allow-Methods', ', '.join(allowed_methods)
            );
            allowed_headers = ', '.join(headers_allowed);
            if any_header {
                allowed_headers = str(
                    request.headers.get('Access-Control-Request-Headers') or ''
                );
                preflight.headers.add_vary('Access-Control-Request-Headers');
            }
            if allowed_headers {
                preflight.headers.set('Access-Control-Allow-Headers', allowed_headers);
            }
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

impl cors_pair_problem(
    origins: list[str],
    allow_credentials: bool,
    origins_key: str = 'allow_origins',
    credentials_key: str = 'allow_credentials'
) -> str {
    if not allow_credentials or '*' not in origins {
        return '';
    }
    return (
        f"{credentials_key} = true cannot be used with '*' in {origins_key}: "
        "browsers reject a response that allows every origin together with "
        f"credentials. List the origins that send credentials in {origins_key}, "
        f"or set {credentials_key} = false."
    );
}

impl custom_headers_middleware(
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
