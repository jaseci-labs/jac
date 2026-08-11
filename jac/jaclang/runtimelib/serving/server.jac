import asyncio;
import inspect;
import logging;
import threading;
import from urllib.parse { unquote, urlsplit }
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.datatypes {
    Headers,
    QueryParams,
    Request,
    Response,
    URL,
    parse_query_string
}
import from jaclang.runtimelib.serving.ws { WebSocket, compute_accept_key }


glob ACCESS_LOGGER_NAME: str = "jaclang.serving.access";

glob _logger: logging.Logger = logging.getLogger(
         "jaclang.runtimelib.serving.server"
     ),
     _access_logger: logging.Logger = logging.getLogger(ACCESS_LOGGER_NAME),
     MAX_HEADER_COUNT: int = 100,
     MAX_BODY_BYTES: int = 104857600,
     HEADER_TIMEOUT_SECONDS: float = 30.0,
     KEEPALIVE_TIMEOUT_SECONDS: float = 65.0,
     CLOSE_TIMEOUT_SECONDS: float = 5.0,
     PORT_RETRY_LIMIT: int = 10,
     ERRNO_ADDR_IN_USE: tuple[int, int, int] = (98, 48, 10048);

glob _REASONS: dict[int, str] = {
         100: 'Continue',
         101: 'Switching Protocols',
         200: 'OK',
         201: 'Created',
         202: 'Accepted',
         204: 'No Content',
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
         409: 'Conflict',
         413: 'Payload Too Large',
         422: 'Unprocessable Entity',
         429: 'Too Many Requests',
         431: 'Request Header Fields Too Large',
         500: 'Internal Server Error',
         502: 'Bad Gateway',
         503: 'Service Unavailable',
         504: 'Gateway Timeout'
     };


obj ServingServer {
    has app: ServingApp,
        host: str = '0.0.0.0',
        port: int = 8000,
        drain_timeout: float = 10.0,
        max_body_bytes: int = MAX_BODY_BYTES,
        ws_allowed_origins: list[str] = [],
        ws_max_message_bytes: int = 0,
        bound_port: int = 0,
        _server: any = None,
        _loop: any = None,
        _stop_event: any = None,
        _active: set[any] = set(),
        _busy: set[any] = set(),
        _stopping: bool = False;

    async def _serve(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) {
        self._loop = asyncio.get_running_loop();
        self._stop_event = asyncio.Event();
        start_fn: any = asyncio.start_server;
        chosen = self.port;
        attempt = 0;
        while True {
            try {
                self._server = await start_fn(
                    self._handle_connection, host=self.host, port=chosen, limit=1048576
                );
                break;
            } except OSError as e {
                if e.errno in ERRNO_ADDR_IN_USE and attempt < port_retries {
                    attempt += 1;
                    chosen += 1;
                    continue;
                }
                raise;
            }
        }
        sockets = self._server.sockets;
        if sockets {
            chosen = sockets[0].getsockname()[1];
        }
        self.bound_port = chosen;
        self.port = chosen;
        if on_ready is not None {
            on_ready(chosen);
        }
        try {
            await self._stop_event.wait();
        } finally {
            self._server.close();
            await self._drain();

            try {
                await asyncio.wait_for(
                    self._server.wait_closed(), timeout=CLOSE_TIMEOUT_SECONDS
                );
            } except asyncio.TimeoutError {
                ;
            }
            await self.app.shutdown();
        }
    }

    async def _drain {
        self._stopping = True;

        for t in list(self._active) {
            if t not in self._busy and not t.done() {
                t.cancel();
            }
        }
        pending = [
            t
            for t in self._busy
            if not t.done()
        ];
        if not pending {
            return;
        }
        try {
            await asyncio.wait_for(
                asyncio.gather(*pending, return_exceptions=True),
                timeout=self.drain_timeout
            );
        } except asyncio.TimeoutError {
            for t in pending {
                t.cancel();
            }
        }
    }

    def request_stop {
        if self._loop is None or self._stop_event is None {
            return;
        }
        self._loop.call_soon_threadsafe(self._stop_event.set);
    }

    def run(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) {
        main_coro: any = self._serve(on_ready=on_ready, port_retries=port_retries);
        try {
            asyncio.run(main_coro);
        } except KeyboardInterrupt {
            ;
        }
    }

    def serve_background(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) -> Callable[[], None] {
        ready = threading.Event();

        def _notify(port: int) {
            ready.set();
            if on_ready is not None {
                on_ready(port);
            }
        }

        notify_fn: any = _notify;

        def _target {
            self.run(on_ready=notify_fn, port_retries=port_retries);
        }
        thread = threading.Thread(target=_target, daemon=True);
        thread.start();
        ready.wait(timeout=30);

        def _stop {
            self.request_stop();
            thread.join(timeout=self.drain_timeout + 5);
        }
        return _stop;
    }

    async def _handle_connection(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        task = asyncio.current_task();
        self._active.add(task);
        try {
            await self._connection_loop(reader, writer);
        } except (ConnectionError, asyncio.IncompleteReadError, TimeoutError) {
            ;
        } except Exception {
            _logger.exception("connection handler failed");
        } finally {
            self._active.discard(task);
            self._busy.discard(task);
            try {
                writer.close();
            } except Exception {
                ;
            }
        }
    }

    async def _connection_loop(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        keep_alive = True;
        first = True;
        while keep_alive {
            timeout = HEADER_TIMEOUT_SECONDS if first else KEEPALIVE_TIMEOUT_SECONDS;
            first = False;
            try {
                request_line: bytes = await asyncio.wait_for(
                    reader.readline(), timeout=timeout
                );
            } except asyncio.TimeoutError {
                return;
            }
            if not request_line or request_line.strip() == b'' {
                return;
            }
            parsed = await self._read_request(reader, writer, request_line);
            if parsed is None {
                return;
            }
            (request, http_version) = parsed;
            if self._is_ws_upgrade(request) {
                ws_task = asyncio.current_task();
                self._busy.add(ws_task);
                try {
                    await self._handle_ws(request, reader, writer);
                } finally {
                    self._busy.discard(ws_task);
                }
                return;
            }
            task = asyncio.current_task();
            self._busy.add(task);
            try {
                response = await self.app.dispatch(request);
                keep_alive = self._should_keep_alive(request, http_version)
                    and not self._stopping;
                wrote = await self._write_response(
                    writer, request, response, keep_alive
                );
            } finally {
                self._busy.discard(task);
            }
            _access_logger.info(
                f'{request.client_host or "-"} - '
                f'"{request.method} {request.url.path} {http_version}" '
                f'{response.status_code}'
            );
            if not wrote {
                return;
            }
        }
    }

    async def _read_request(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter, request_line: bytes
    ) -> (tuple[Request, str] | None) {
        try {
            line = request_line.decode('latin-1').strip();
            parts = line.split(' ');
            if len(parts) != 3 {
                await self._bare_error(writer, 400, 'Bad Request');
                return None;
            }
            (method, target, http_version) = (parts[0], parts[1], parts[2]);
            headers = Headers();
            count = 0;
            while True {
                raw: bytes = await asyncio.wait_for(
                    reader.readline(), timeout=HEADER_TIMEOUT_SECONDS
                );
                if raw in (b'\r\n', b'\n', b'') {
                    break;
                }
                count += 1;
                if count > MAX_HEADER_COUNT {
                    await self._bare_error(
                        writer, 431, 'Request Header Fields Too Large'
                    );
                    return None;
                }
                text = raw.decode('latin-1').strip();
                if ':' in text {
                    (name, _, value) = text.partition(':');
                    headers.append(name.strip(), value.strip());
                }
            }
            expect = (headers.get('Expect') or '').lower();
            if expect == '100-continue' {
                writer.write(b'HTTP/1.1 100 Continue\r\n\r\n');
                await writer.drain();
            }
            body = await self._read_body(reader, writer, headers);
            if body is None {
                return None;
            }
            split = urlsplit(target);
            peer = writer.get_extra_info('peername');
            request = Request(
                method=method.upper(),
                url=URL(path=unquote(split.path) or '/', query=split.query),
                headers=headers,
                query_params=QueryParams(raw=parse_query_string(split.query)),
                body=body,
                client_host=peer[0] if peer else ''
            );
            return (request, http_version);
        } except asyncio.TimeoutError {
            return None;
        }
    }

    async def _read_body(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter, headers: Headers
    ) -> (bytes | None) {
        transfer = (headers.get('Transfer-Encoding') or '').lower();
        if 'chunked' in transfer {
            chunks: list[bytes] = [];
            total = 0;
            while True {
                size_line: bytes = await asyncio.wait_for(
                    reader.readline(), timeout=HEADER_TIMEOUT_SECONDS
                );
                size_text = size_line.decode('latin-1').strip().split(';')[0];
                int_fn: any = int;
                try {
                    size = int_fn(size_text, 16);
                } except ValueError {
                    await self._bare_error(writer, 400, 'Bad Request');
                    return None;
                }
                if size == 0 {
                    while True {
                        trailer: bytes = await reader.readline();
                        if trailer in (b'\r\n', b'\n', b'') {
                            break;
                        }
                    }
                    break;
                }
                total += size;
                if total > self.max_body_bytes {
                    await self._bare_error(writer, 413, 'Payload Too Large');
                    return None;
                }
                chunks.append(await reader.readexactly(size));
                await reader.readexactly(2);
            }
            return b''.join(chunks);
        }
        length_header = headers.get('Content-Length');
        if not length_header {
            return b'';
        }
        try {
            length = int(length_header);
        } except ValueError {
            await self._bare_error(writer, 400, 'Bad Request');
            return None;
        }
        if length > self.max_body_bytes {
            await self._bare_error(writer, 413, 'Payload Too Large');
            return None;
        }
        return await reader.readexactly(length) if length else b'';
    }

    def _is_ws_upgrade(request: Request) -> bool {
        upgrade = (request.headers.get('Upgrade') or '').lower();
        connection = (request.headers.get('Connection') or '').lower();
        return upgrade == 'websocket' and 'upgrade' in connection;
    }

    def _ws_origin_allowed(request: Request) -> bool {
        origin = (request.headers.get('Origin') or '').strip();
        if not origin {
            return True;
        }
        if '*' in self.ws_allowed_origins or origin in self.ws_allowed_origins {
            return True;
        }
        origin_host = urlsplit(origin).netloc.lower();
        request_host = (request.headers.get('Host') or '').strip().lower();
        return bool(origin_host) and origin_host == request_host;
    }

    async def _handle_ws(
        request: Request, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        if not self._ws_origin_allowed(request) {
            _access_logger.info(
                f'{request.client_host or "-"} - '
                f'"WS {request.url.path}" 403 (cross-origin refused)'
            );
            await self._bare_error(writer, 403, 'Forbidden');
            return;
        }
        (ep, path_params) = self.app.router.resolve_ws(request.url.path);
        key = request.headers.get('Sec-WebSocket-Key') or '';
        if ep is None or not key {
            await self._bare_error(writer, 404, 'Not Found');
            return;
        }
        _access_logger.info(
            f'{request.client_host or "-"} - "WS {request.url.path}" 101'
        );
        ws = WebSocket(
            reader=reader,
            writer=writer,
            headers=request.headers,
            url=request.url,
            query_params=request.query_params,
            path_params=path_params,
            client_host=request.client_host,
            accept_key=compute_accept_key(key)
        );
        if self.ws_max_message_bytes > 0 {
            ws.max_message_bytes = self.ws_max_message_bytes;
        }
        handler_fn: any = ep.handler;
        try {
            result = handler_fn(ws);
            if inspect.isawaitable(result) {
                await result;
            }
        } except Exception {
            _logger.exception(f"websocket handler failed: {ep.path}");
        } finally {
            if not ws.closed {
                await ws.close(1000);
            }
        }
    }

    def _should_keep_alive(request: Request, http_version: str) -> bool {
        connection = (request.headers.get('Connection') or '').lower();
        if 'close' in connection {
            return False;
        }
        if http_version.upper() == 'HTTP/1.0' {
            return 'keep-alive' in connection;
        }
        return True;
    }

    async def _write_response(
        writer: asyncio.StreamWriter,
        request: Request,
        response: Response,
        keep_alive: bool
    ) -> bool {
        is_head = request.method == 'HEAD';
        stream = response.stream;
        chunked = stream is not None and not is_head;
        body = b'';
        if not chunked and not (is_head and stream is not None) {
            body = response.body_bytes();
        }
        reason = _REASONS.get(response.status_code, 'OK');
        head_lines = [f"HTTP/1.1 {response.status_code} {reason}"];
        if response.headers.get('Content-Type') is None {
            head_lines.append(f"Content-Type: {response.content_type_header()}");
        }
        if chunked {
            head_lines.append('Transfer-Encoding: chunked');
        } else {
            head_lines.append(f"Content-Length: {len(body)}");
        }
        conn_override = (response.headers.get('Connection') or '').lower();
        if not conn_override {
            head_lines.append(
                'Connection: keep-alive' if keep_alive else 'Connection: close'
            );
        }
        for (name, value) in response.headers.items() {
            head_lines.append(f"{name}: {value}");
        }
        blob = ('\r\n'.join(head_lines) + '\r\n\r\n').encode('latin-1');
        try {
            writer.write(blob);
            if chunked {
                await self._write_stream(writer, stream);
                writer.write(b'0\r\n\r\n');
            } elif not is_head {
                writer.write(body);
            }
            await writer.drain();
            return conn_override != 'close';
        } except (ConnectionError, OSError) {
            return False;
        }
    }

    async def _write_stream(writer: asyncio.StreamWriter, stream: any) {
        if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
            async for chunk in stream {
                self._write_chunk(writer, chunk);
                await writer.drain();
            }
        } else {
            for chunk in stream {
                self._write_chunk(writer, chunk);
                await writer.drain();
            }
        }
    }

    def _write_chunk(writer: asyncio.StreamWriter, chunk: any) {
        data = chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
        if not data {
            return;
        }
        writer.write(f"{len(data):X}\r\n".encode('latin-1'));
        writer.write(data);
        writer.write(b'\r\n');
    }

    async def _bare_error(writer: asyncio.StreamWriter, status: int, reason: str) {
        body = f'{{"detail": "{reason}"}}'.encode('utf-8');
        blob = (
            f"HTTP/1.1 {status} {reason}\r\n"
            "Content-Type: application/json\r\n"
            f"Content-Length: {len(body)}\r\n"
            "Connection: close\r\n\r\n"
        ).encode(
            'latin-1'
        );
        try {
            writer.write(blob + body);
            await writer.drain();
        } except (ConnectionError, OSError) {
            ;
        }
    }
}
