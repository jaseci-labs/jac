import re;
import from contextvars { ContextVar }

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

    def header(name: str, fallback: (str | None) = None) -> (str | None);
    def link(path: str = '') -> str;
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


def open_exchange(request: Request, public_origin: str = '') -> any;


def close_exchange(token: any);


def request_origin(request: Request) -> str;


def current_request -> (RequestView | None);


def _checked_status(status: int) -> int;


def _checked_header(name: str, value: str) -> tuple[str, str];


def respond(
    status: (int | None) = None, headers: (dict[str, str] | None) = None
) -> bool;


def forget_response_choice;


def refusal_status -> (int | None);


def has_response_choice -> bool;


def apply_response_choice(response: any) -> any;


def settle_envelope(envelope: TransportResponse) -> (TransportResponse | JSONResponse);
