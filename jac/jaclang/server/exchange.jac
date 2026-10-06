import re;
import from contextvars { ContextVar }
import from jaclang.server.serving.datatypes { JSONResponse, Request }
import from jaclang.server.transport { TransportResponse }

glob CREDENTIAL_HEADERS: frozenset[str] = frozenset(
         ['authorization', 'cookie', 'proxy-authorization']
     ),
     SERVER_OWNED_HEADERS: frozenset[str] = frozenset(
         ['connection', 'content-length', 'content-type', 'transfer-encoding']
     ),
     HEADER_NAME: re.Pattern = re.compile(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$"),
     HOST_AND_PORT: re.Pattern = re.compile(
         r"^([A-Za-z0-9._~-]+|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$"
     ),
     _exchange: ContextVar = ContextVar('jac_serve_exchange', `default=None);


obj RequestView {
    has method: str = 'GET',
        path: str = '/',
        query_string: str = '',
        query: dict[str, str] = {},
        headers: dict[str, str] = {},
        origin: str = '',
        public_origin: str = '';

    def header(name: str, fallback: (str | None) = None) -> (str | None) {
        return self.headers.get(name.lower(), fallback);
    }

    def link(path: str = '') -> str {
        base = self.public_origin or self.origin;
        if path and not path.startswith('/') {
            return base + '/' + path;
        }
        return base + path;
    }
}


obj ResponseChoice {
    has status: (int | None) = None,
        headers: dict[str, tuple[str, str]] = {};
}


obj Exchange {
    has request: Request,
        public_origin: str = '',
        choice: ResponseChoice = ResponseChoice();
}


def open_exchange(request: Request, public_origin: str = '') -> any {
    return _exchange.set(
        Exchange(request=request, public_origin=public_origin, choice=ResponseChoice())
    );
}


def close_exchange(token: any) {
    _exchange.reset(token);
}


def request_origin(request: Request) -> str {
    netloc = (request.url.netloc or request.headers.get('Host') or '').strip();
    if not HOST_AND_PORT.match(netloc) {
        return '';
    }
    return request.url.scheme + '://' + netloc;
}


def current_request -> (RequestView | None) {
    exchange = _exchange.get();
    if exchange is None {
        return None;
    }
    request = exchange.request;
    headers: dict[str, str] = {};
    for (name, value) in request.headers.items() {
        low = name.lower();
        if low in CREDENTIAL_HEADERS {
            continue;
        }
        headers[low] = headers[low] + ', ' + value if low in headers else value;
    }
    return RequestView(
        method=request.method,
        path=request.url.path,
        query_string=request.url.query,
        query=dict(request.query_params.items()),
        headers=headers,
        origin=request_origin(request),
        public_origin=exchange.public_origin
    );
}


def _checked_status(status: int) -> int {
    if isinstance(status, bool) or not isinstance(status, int) {
        raise ValueError(f"response status must be an integer, got {status!r}");
    }
    if status < 200 or status > 599 {
        raise ValueError(f"response status must be 200..599, got {status}");
    }
    return status;
}


def _checked_header(name: str, value: str) -> tuple[str, str] {
    header_name = str(name);
    header_value = str(value);
    if not HEADER_NAME.match(header_name) {
        raise ValueError(f"invalid response header name {header_name!r}");
    }
    if header_name.lower() in SERVER_OWNED_HEADERS {
        raise ValueError(f"response header {header_name} is set by the server");
    }
    if '\r' in header_value or '\n' in header_value or '\x00' in header_value {
        raise ValueError(
            f"response header {header_name} must not contain a line break"
        );
    }
    try {
        header_value.encode('latin-1');
    } except UnicodeEncodeError {
        raise ValueError(
            f"response header {header_name} must be latin-1; percent-encode other text"
        );
    }
    return (header_name, header_value);
}


def respond(
    status: (int | None) = None, headers: (dict[str, str] | None) = None
) -> bool {
    checked_status = None if status is None else _checked_status(status);
    checked_headers = [
        _checked_header(name, value) for (name, value) in (headers or {}).items()
    ];
    exchange = _exchange.get();
    if exchange is None {
        return False;
    }
    choice = exchange.choice;
    if checked_status is not None {
        choice.status = checked_status;
    }
    for (name, value) in checked_headers {
        choice.headers[name.lower()] = (name, value);
    }
    return True;
}


def forget_response_choice {
    exchange = _exchange.get();
    if exchange is not None {
        exchange.choice = ResponseChoice();
    }
}


def refusal_status -> (int | None) {
    exchange = _exchange.get();
    if exchange is None or exchange.choice.status is None {
        return None;
    }
    return exchange.choice.status if exchange.choice.status >= 400 else None;
}


def settle_envelope(envelope: TransportResponse) -> (TransportResponse | JSONResponse) {
    exchange = _exchange.get();
    if exchange is None {
        return envelope;
    }
    choice = exchange.choice;
    if choice.status is None and not choice.headers {
        return envelope;
    }
    import from jaclang.server.serving.app { transport_to_response }
    response = transport_to_response(envelope);
    if choice.status is not None {
        response.status_code = choice.status;
        response.content['ok'] = choice.status < 400;
    }
    for (name, value) in choice.headers.values() {
        response.headers.set(name, value);
    }
    return response;
}
