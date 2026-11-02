import asyncio;
import inspect;
import logging;
import signal;
import tempfile;
import threading;
import time;
import uuid;
import from email.utils { formatdate }
import from urllib.parse { unquote, urlsplit }


glob _logger: logging.Logger = logging.getLogger("jaclang.server.serving.server"),
     SERVER_HEADER: str = 'jac',
     EXIT_OK: int = 0,
     EXIT_RECYCLE: int = 3,
     HEARTBEAT_SECONDS: float = 1.0,
     SUPPORTED_VERSIONS: tuple[str, str] = ('HTTP/1.1', 'HTTP/1.0'),
     _TOKEN_CHARS: str = "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

glob _REASONS: dict[int, str] = {
         100: 'Continue',
         101: 'Switching Protocols',
         200: 'OK',
         201: 'Created',
         202: 'Accepted',
         204: 'No Content',
         206: 'Partial Content',
         301: 'Moved Permanently',
         302: 'Found',
         303: 'See Other',
         304: 'Not Modified',
         307: 'Temporary Redirect',
         308: 'Permanent Redirect',
         400: 'Bad Request',
         401: 'Unauthorized',
         403: 'Forbidden',
         404: 'Not Found',
         405: 'Method Not Allowed',
         408: 'Request Timeout',
         409: 'Conflict',
         411: 'Length Required',
         413: 'Payload Too Large',
         414: 'URI Too Long',
         416: 'Range Not Satisfiable',
         422: 'Unprocessable Entity',
         429: 'Too Many Requests',
         431: 'Request Header Fields Too Large',
         500: 'Internal Server Error',
         501: 'Not Implemented',
         502: 'Bad Gateway',
         503: 'Service Unavailable',
         504: 'Gateway Timeout',
         505: 'HTTP Version Not Supported'
     };


obj ProtocolError(Exception) {
    has status: int = 400,
        reason: str = 'Bad Request';
}


def _is_token(text: str) -> bool;


obj ServingServer {
    has app: ServingApp,
        settings: ServeSettings = ServeSettings(),
        host: str = '',
        port: (int | None) = None,
        sock: any = None,
        drain: DrainState = DrainState(),
        install_signals: bool = True,
        request_budget: int = 0,
        heartbeat: (Callable[[], None] | None) = None,
        bound_port: int = 0,
        exit_code: int = EXIT_OK,
        requests_served: int = 0,
        _compression: CompressionPolicy = CompressionPolicy(),
        _proxy: ProxyResolver = ProxyResolver(),
        _executor: (SyncExecutor | None) = None,
        _server: any = None,
        _loop: any = None,
        _stop_event: any = None,
        _active: set[any] = set(),
        _busy: set[any] = set(),
        _stopping: bool = False;

    def postinit;
    def scheme -> str;
    async def _serve(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    );

    def _install_signal_handlers;
    async def _heartbeat_loop;
    async def _drain;
    def request_stop(exit_code: int = EXIT_OK);
    def run(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) -> int;

    def serve_background(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) -> Callable[[], None];

    async def _handle_connection(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    );

    async def _connection_loop(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    );

    async def _dispatch(request: Request) -> Response;
    def _release_body(request: Request);
    def _log_access(
        request: Request, response: Response, bytes_sent: int, started: float
    );

    async def _read_line(reader: asyncio.StreamReader, timeout: float) -> bytes;
    async def _read_request(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter, request_line: bytes
    ) -> Request;

    def _declared_length(headers: Headers) -> (int | None);
    def _spool_sink(headers: Headers) -> any;
    async def _read_body(
        reader: asyncio.StreamReader, headers: Headers
    ) -> tuple[bytes, any];

    def _is_ws_upgrade(request: Request) -> bool;
    def _ws_origin_allowed(request: Request) -> bool;
    async def _handle_ws(
        request: Request, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    );

    def _should_keep_alive(request: Request) -> bool;
    def _standard_headers(request: Request, response: Response) -> list[str];
    async def _write_response(
        writer: asyncio.StreamWriter,
        request: Request,
        response: Response,
        keep_alive: bool
    ) -> tuple[bool, int];

    async def _discard_stream(stream: any);
    async def _write_stream(
        writer: asyncio.StreamWriter, stream: any, chunked: bool
    ) -> int;

    def _write_chunk(writer: asyncio.StreamWriter, chunk: any, chunked: bool) -> int;
    async def _bare_error(
        writer: asyncio.StreamWriter,
        status: int,
        reason: str,
        extra: (dict[str, str] | None) = None
    );
}
