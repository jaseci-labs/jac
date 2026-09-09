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
import from jaclang.server.net { PORT_RETRY_LIMIT, bind_listener }
import from jaclang.server.serving.accesslog { AccessRecord, emit as emit_access }
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.compression { CompressionPolicy }
import from jaclang.server.serving.datatypes {
    Headers,
    QueryParams,
    Request,
    Response,
    URL,
    parse_query_string
}
import from jaclang.server.serving.drain { DrainState, HEALTH_PATHS }
import from jaclang.server.serving.executor { SyncExecutor }
import from jaclang.server.serving.proxy { ProxyResolver }
import from jaclang.server.serving.ws { WebSocket, compute_accept_key }
import from jaclang.server.settings { ServeSettings }


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


def _is_token(text: str) -> bool {
    return bool(text) and all(ch in _TOKEN_CHARS for ch in text);
}


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

    def postinit {
        if not self.host {
            self.host = self.settings.host;
        }
        if self.port is None {
            self.port = self.settings.port;
        }
        self.drain.timeout = self.settings.timeouts.drain;
        self._compression = CompressionPolicy(
            enabled=self.settings.compression.enabled,
            min_bytes=self.settings.compression.min_bytes,
            level=self.settings.compression.level
        );
        self._proxy = ProxyResolver(trusted=list(self.settings.proxy.trusted));
        self.app.state['drain'] = self.drain;
    }

    def scheme -> str {
        return self.settings.scheme();
    }

    async def _serve(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) {
        self._loop = asyncio.get_running_loop();
        self._stop_event = asyncio.Event();
        self._executor = SyncExecutor(threads=self.settings.workers.threads);
        self._executor.install(self._loop);
        listener = self.sock;
        if listener is None {
            listener = bind_listener(
                self.host,
                int(self.port or 0),
                backlog=self.settings.limits.backlog,
                port_retries=port_retries
            );
        }
        ssl_ctx = self.settings.tls.build_context();
        self._server = await asyncio.start_server(
            self._handle_connection,
            sock=listener,
            ssl=ssl_ctx,
            limit=max(4096, self.settings.limits.max_header_bytes),
            backlog=self.settings.limits.backlog
        );
        try {
            self.bound_port = int(listener.getsockname()[1]);
        } except Exception {
            self.bound_port = int(self.port or 0);
        }
        self.port = self.bound_port;
        if self.install_signals {
            self._install_signal_handlers();
        }
        pulse: any = None;
        if self.heartbeat is not None {
            pulse = self._loop.create_task(self._heartbeat_loop());
        }
        if on_ready is not None {
            on_ready(self.bound_port);
        }
        try {
            await self._stop_event.`wait();
        } finally {
            self.drain.start(self.drain.reason or 'shutdown');
            self._server.close();
            await self._drain();
            try {
                await asyncio.wait_for(
                    self._server.wait_closed(), timeout=self.settings.timeouts.close
                );
            } except asyncio.TimeoutError {}
            await self.app.shutdown();
            if pulse is not None {
                pulse.cancel();
            }
            if self._executor is not None {
                self._executor.shutdown(`wait=False);
            }
        }
    }

    def _install_signal_handlers {
        def _on_signal(name: str) {
            self.drain.start(f"signal {name}");
            self.request_stop();
        }
        for sig_name in ('SIGTERM', 'SIGINT') {
            sig = getattr(signal, sig_name, None);
            if sig is None {
                continue;
            }
            try {
                self._loop.add_signal_handler(sig, _on_signal, sig_name);
            } except (NotImplementedError, RuntimeError, ValueError) {}
        }
    }

    async def _heartbeat_loop {
        beat: any = self.heartbeat;
        while not self._stopping {
            try {
                beat();
            } except Exception {
                _logger.debug('heartbeat failed', exc_info=True);
            }
            await asyncio.sleep(HEARTBEAT_SECONDS);
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
                timeout=self.drain.remaining()
            );
        } except asyncio.TimeoutError {
            _logger.warning(
                f"drain: {len(pending)} request(s) still running after "
                f"{self.drain.timeout:.1f}s; cancelling"
            );
            for t in pending {
                t.cancel();
            }
        }
    }

    def request_stop(exit_code: int = EXIT_OK) {
        if exit_code != EXIT_OK {
            self.exit_code = exit_code;
        }
        if self._loop is None or self._stop_event is None {
            return;
        }
        self._loop.call_soon_threadsafe(self._stop_event.set);
    }

    def run(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) -> int {
        main_coro: any = self._serve(on_ready=on_ready, port_retries=port_retries);
        try {
            asyncio.run(main_coro);
        } except KeyboardInterrupt {}
        return self.exit_code;
    }

    def serve_background(
        on_ready: (Callable[[int], None] | None) = None,
        port_retries: int = PORT_RETRY_LIMIT
    ) -> Callable[[], None] {
        ready = threading.Event();
        self.install_signals = False;

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
        ready.`wait(timeout=30);

        def _stop {
            self.request_stop();
            thread.join(timeout=self.drain.timeout + 5);
        }
        return _stop;
    }

    async def _handle_connection(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        task = asyncio.current_task();
        cap = self.settings.limits.max_connections;
        if cap > 0 and len(self._active) >= cap {
            await self._bare_error(
                writer, 503, 'Service Unavailable', extra={'Retry-After': '1'}
            );
            try {
                writer.close();
            } except Exception {}
            return;
        }
        self._active.add(task);
        try {
            await self._connection_loop(reader, writer);
        } except (ConnectionError, asyncio.IncompleteReadError, TimeoutError) {} except asyncio.CancelledError {
            raise;
        } except Exception {
            _logger.exception("connection handler failed");
        } finally {
            self._active.discard(task);
            self._busy.discard(task);
            try {
                writer.close();
            } except Exception {}
        }
    }

    async def _connection_loop(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        keep_alive = True;
        first = True;
        while keep_alive {
            timeout = self.settings.timeouts.header
                if first
                else self.settings.timeouts.keepalive;
            first = False;
            try {
                request_line: bytes = await asyncio.wait_for(
                    reader.readuntil(b'\n'), timeout=timeout
                );
            } except asyncio.TimeoutError {
                return;
            } except asyncio.LimitOverrunError {
                await self._bare_error(writer, 414, 'URI Too Long');
                return;
            } except asyncio.IncompleteReadError as eof {
                if eof.partial.strip() {
                    await self._bare_error(writer, 400, 'Bad Request');
                }
                return;
            }
            if request_line.strip() == b'' {
                continue;
            }
            started = time.perf_counter();
            try {
                request = await self._read_request(reader, writer, request_line);
            } except ProtocolError as pe {
                await self._bare_error(writer, pe.status, pe.reason);
                return;
            } except asyncio.TimeoutError {
                await self._bare_error(writer, 408, 'Request Timeout');
                return;
            }
            if self.drain.draining and request.url.path not in HEALTH_PATHS {
                await self._bare_error(
                    writer, 503, 'Service Unavailable', extra={'Retry-After': '1'}
                );
                self._log_access(request, Response(status_code=503), 0, started);
                self._release_body(request);
                return;
            }
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
            wrote = False;
            bytes_sent = 0;
            try {
                response = await self._dispatch(request);
                keep_alive = self._should_keep_alive(request) and not self._stopping;
                (wrote, bytes_sent) = await self._write_response(
                    writer, request, response, keep_alive
                );
            } finally {
                self._busy.discard(task);
                self._release_body(request);
            }
            self._log_access(request, response, bytes_sent, started);
            self.requests_served += 1;
            if self.request_budget > 0
                and self.requests_served >= self.request_budget {
                _logger.info(
                    f"worker served {self.requests_served} requests; recycling"
                );
                self.request_stop(EXIT_RECYCLE);
                keep_alive = False;
            }
            if not wrote {
                return;
            }
        }
    }

    async def _dispatch(request: Request) -> Response {
        budget = self.settings.workers.request_timeout;
        if budget <= 0 {
            return await self.app.dispatch(request);
        }
        try {
            return await asyncio.wait_for(self.app.dispatch(request), timeout=budget);
        } except asyncio.TimeoutError {
            _logger.warning(
                f"request {request.method} {request.url.path} exceeded "
                f"{budget:.1f}s; answering 504"
            );
            import from jaclang.server.serving.datatypes { JSONResponse }
            resp = JSONResponse(
                status_code=504, content={'detail': f"request exceeded {budget:.0f}s"}
            );
            resp.headers.set('Connection', 'close');
            return resp;
        }
    }

    def _release_body(request: Request) {
        spool = request.body_file;
        if spool is not None {
            try {
                spool.close();
            } except Exception {}
            request.body_file = None;
        }
        for uploads in request.upload_files.values() {
            for upload in uploads {
                try {
                    upload.file.close();
                } except Exception {}
            }
        }
    }

    def _log_access(
        request: Request, response: Response, bytes_sent: int, started: float
    ) {
        record = AccessRecord(
            client=request.client_host or '-',
            method=request.method,
            path=request.url.path,
            query=request.url.query,
            version=request.http_version,
            status=response.status_code,
            bytes_sent=bytes_sent,
            duration_ms=(time.perf_counter() - started) * 1000.0,
            request_id=request.request_id,
            user_agent=request.headers.get('User-Agent') or '',
            referer=request.headers.get('Referer') or '',
            scheme=request.url.scheme,
            ts=time.time()
        );
        emit_access(record);
    }

    async def _read_line(reader: asyncio.StreamReader, timeout: float) -> bytes {
        try {
            return await asyncio.wait_for(reader.readuntil(b'\n'), timeout=timeout);
        } except asyncio.LimitOverrunError {
            raise ProtocolError(status=431, reason='Request Header Fields Too Large');
        } except asyncio.IncompleteReadError {
            raise ProtocolError(status=400, reason='Bad Request');
        }
    }

    async def _read_request(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter, request_line: bytes
    ) -> Request {
        limits = self.settings.limits;
        if len(request_line) > limits.max_request_line_bytes {
            raise ProtocolError(status=414, reason='URI Too Long');
        }
        line = request_line.decode('latin-1').rstrip('\r\n');
        parts = line.split(' ');
        if len(parts) != 3 {
            raise ProtocolError();
        }
        (method, target, http_version) = (parts[0], parts[1], parts[2]);
        if not _is_token(method) or not target {
            raise ProtocolError();
        }
        if http_version not in SUPPORTED_VERSIONS {
            raise ProtocolError(status=505, reason='HTTP Version Not Supported');
        }
        headers = Headers();
        count = 0;
        header_bytes = 0;
        header_timeout = self.settings.timeouts.header;
        while True {
            raw: bytes = await self._read_line(reader, header_timeout);
            if raw in (b'\r\n', b'\n') {
                break;
            }
            count += 1;
            header_bytes += len(raw);
            if count > limits.max_header_count
                or header_bytes > limits.max_header_bytes {
                raise ProtocolError(
                    status=431, reason='Request Header Fields Too Large'
                );
            }
            text = raw.decode('latin-1').rstrip('\r\n');
            if ':' not in text {
                raise ProtocolError();
            }
            (name, _, value) = text.partition(':');
            if not _is_token(name) {
                raise ProtocolError();
            }
            headers.append(name, value.strip());
        }
        if http_version == 'HTTP/1.1' and headers.get('Host') is None {
            raise ProtocolError();
        }
        expect = (headers.get('Expect') or '').lower();
        if expect == '100-continue' {
            writer.write(b'HTTP/1.1 100 Continue\r\n\r\n');
            await writer.drain();
        }
        (body, spool) = await self._read_body(reader, headers);
        split = urlsplit(target);
        peer = writer.get_extra_info('peername');
        peer_host = peer[0] if peer else '';
        forwarded = self._proxy.resolve(peer_host, headers);
        scheme = forwarded.scheme or self.scheme();
        netloc = forwarded.host or (headers.get('Host') or '');
        request_id = (headers.get('X-Request-Id') or '').strip()[:128]
            or uuid.uuid4().hex;
        return Request(
            method=method.upper(),
            url=URL(
                path=unquote(split.path) or '/',
                query=split.query,
                scheme=scheme,
                netloc=netloc
            ),
            headers=headers,
            query_params=QueryParams(raw=parse_query_string(split.query)),
            body=body,
            body_file=spool,
            client_host=forwarded.client,
            http_version=http_version,
            request_id=request_id
        );
    }

    def _declared_length(headers: Headers) -> (int | None) {
        values = headers.getlist('Content-Length');
        if not values {
            return None;
        }
        distinct = {v.strip() for v in values};
        if len(distinct) != 1 {
            raise ProtocolError();
        }
        text = distinct.pop();
        if not text.isdigit() {
            raise ProtocolError();
        }
        return int(text);
    }

    def _spool_sink(headers: Headers) -> any {
        content_type = (headers.get('Content-Type') or '').lower();
        if 'multipart/form-data' not in content_type {
            return None;
        }
        return tempfile.SpooledTemporaryFile(
            max_size=max(0, self.settings.limits.multipart_spool_bytes)
        );
    }

    async def _read_body(
        reader: asyncio.StreamReader, headers: Headers
    ) -> tuple[bytes, any] {
        limits = self.settings.limits;
        body_timeout = self.settings.timeouts.body;
        transfer = [
            t.strip().lower() for raw in headers.getlist('Transfer-Encoding')
            for t in str(raw).split(',')
            if t.strip()
        ];
        length = self._declared_length(headers);
        if transfer {
            if length is not None {
                raise ProtocolError();
            }
            if transfer != ['chunked'] {
                raise ProtocolError(status=501, reason='Not Implemented');
            }
            sink = self._spool_sink(headers);
            chunks: list[bytes] = [];
            total = 0;
            while True {
                size_line: bytes = await self._read_line(reader, body_timeout);
                size_text = size_line.decode('latin-1').strip().split(';')[0];
                int_fn: any = int;
                try {
                    size = int_fn(size_text, 16);
                } except ValueError {
                    raise ProtocolError();
                }
                if size == 0 {
                    while True {
                        trailer: bytes = await self._read_line(reader, body_timeout);
                        if trailer in (b'\r\n', b'\n') {
                            break;
                        }
                    }
                    break;
                }
                total += size;
                if total > limits.max_body_bytes {
                    raise ProtocolError(status=413, reason='Payload Too Large');
                }
                piece: bytes = await asyncio.wait_for(
                    reader.readexactly(size), timeout=body_timeout
                );
                await asyncio.wait_for(reader.readexactly(2), timeout=body_timeout);
                if sink is not None {
                    sink.write(piece);
                } else {
                    chunks.append(piece);
                }
            }
            if sink is not None {
                sink.seek(0);
                return (b'', sink);
            }
            return (b''.join(chunks), None);
        }
        size: int = length if length is not None else 0;
        if size <= 0 {
            return (b'', None);
        }
        if size > limits.max_body_bytes {
            raise ProtocolError(status=413, reason='Payload Too Large');
        }
        sink = self._spool_sink(headers);
        if sink is None {
            data: bytes = await asyncio.wait_for(
                reader.readexactly(size), timeout=body_timeout
            );
            return (data, None);
        }
        remaining: int = size;
        while remaining > 0 {
            step: int = min(65536, remaining);
            piece: bytes = await asyncio.wait_for(
                reader.readexactly(step), timeout=body_timeout
            );
            sink.write(piece);
            remaining -= step;
        }
        sink.seek(0);
        return (b'', sink);
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
        allowed = self.settings.websocket.allowed_origins;
        if '*' in allowed or origin in allowed {
            return True;
        }
        origin_host = urlsplit(origin).netloc.lower();
        request_host = (request.headers.get('Host') or '').strip().lower();
        return bool(origin_host) and origin_host == request_host;
    }

    async def _handle_ws(
        request: Request, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) {
        started = time.perf_counter();
        if not self._ws_origin_allowed(request) {
            await self._bare_error(writer, 403, 'Forbidden');
            self._log_access(request, Response(status_code=403), 0, started);
            return;
        }
        (ep, path_params) = self.app.router.resolve_ws(request.url.path);
        key = request.headers.get('Sec-WebSocket-Key') or '';
        if ep is None or not key {
            await self._bare_error(writer, 404, 'Not Found');
            self._log_access(request, Response(status_code=404), 0, started);
            return;
        }
        self._log_access(request, Response(status_code=101), 0, started);
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
        ws_settings = self.settings.websocket;
        if ws_settings.max_message_bytes > 0 {
            ws.max_message_bytes = ws_settings.max_message_bytes;
        }
        ws.start_keepalive(ws_settings.ping_interval, ws_settings.ping_timeout);
        handler_fn: any = ep.handler;
        try {
            result = handler_fn(ws);
            if inspect.isawaitable(result) {
                await result;
            }
        } except Exception {
            _logger.exception(f"websocket handler failed: {ep.path}");
        } finally {
            ws.stop_keepalive();
            if not ws.closed {
                await ws.close(1000);
            }
        }
    }

    def _should_keep_alive(request: Request) -> bool {
        connection = (request.headers.get('Connection') or '').lower();
        if 'close' in connection {
            return False;
        }
        if request.http_version == 'HTTP/1.0' {
            return 'keep-alive' in connection;
        }
        return True;
    }

    def _standard_headers(request: Request, response: Response) -> list[str] {
        lines: list[str] = [];
        if response.headers.get('Date') is None {
            lines.append(f"Date: {formatdate(usegmt=True)}");
        }
        if response.headers.get('Server') is None {
            lines.append(f"Server: {SERVER_HEADER}");
        }
        if request.request_id and response.headers.get('X-Request-Id') is None {
            lines.append(f"X-Request-Id: {request.request_id}");
        }
        return lines;
    }

    async def _write_response(
        writer: asyncio.StreamWriter,
        request: Request,
        response: Response,
        keep_alive: bool
    ) -> tuple[bool, int] {
        is_head = request.method == 'HEAD';
        bodiless = response.status_code in (204, 304)
            or 100 <= response.status_code < 200;
        body: (bytes | None) = None;
        if not bodiless and response.stream is None {
            body = response.body_bytes();
        }
        if not bodiless {
            body = self._compression.apply(request, response, body);
        }
        stream = response.stream;
        legacy = request.http_version == 'HTTP/1.0';
        chunked = stream is not None and not is_head and not bodiless and not legacy;
        if stream is not None and legacy {
            keep_alive = False;
        }
        reason = _REASONS.get(response.status_code, 'OK');
        head_lines = [f"HTTP/1.1 {response.status_code} {reason}"];
        head_lines.extend(self._standard_headers(request, response));
        if response.headers.get('Content-Type') is None and not bodiless {
            head_lines.append(f"Content-Type: {response.content_type_header()}");
        }
        if chunked {
            head_lines.append('Transfer-Encoding: chunked');
        } elif bodiless {
            if response.headers.get('Content-Length') is None {
                head_lines.append('Content-Length: 0');
            }
        } elif stream is None {
            response.headers.remove('Content-Length');
            head_lines.append(f"Content-Length: {len(body or b'')}");
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
        sent = 0;
        try {
            writer.write(blob);
            if chunked {
                sent = await self._write_stream(writer, stream, chunked=True);
                writer.write(b'0\r\n\r\n');
            } elif bodiless or is_head {
                if stream is not None {
                    await self._discard_stream(stream);
                }
            } elif stream is not None {
                sent = await self._write_stream(writer, stream, chunked=False);
            } else {
                writer.write(body or b'');
                sent = len(body or b'');
            }
            await writer.drain();
            return (keep_alive and conn_override != 'close', sent);
        } except (ConnectionError, OSError) {
            return (False, sent);
        }
    }

    async def _discard_stream(stream: any) {
        try {
            if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
                async for _chunk in stream {
                    continue;
                }
            } else {
                for _chunk in stream {
                    continue;
                }
            }
        } except Exception {}
    }

    async def _write_stream(
        writer: asyncio.StreamWriter, stream: any, chunked: bool
    ) -> int {
        sent = 0;
        if inspect.isasyncgen(stream) or hasattr(stream, '__aiter__') {
            async for chunk in stream {
                sent += self._write_chunk(writer, chunk, chunked);
                await writer.drain();
            }
        } else {
            for chunk in stream {
                sent += self._write_chunk(writer, chunk, chunked);
                await writer.drain();
            }
        }
        return sent;
    }

    def _write_chunk(writer: asyncio.StreamWriter, chunk: any, chunked: bool) -> int {
        data = chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
        if not data {
            return 0;
        }
        if chunked {
            writer.write(f"{len(data):X}\r\n".encode('latin-1'));
            writer.write(data);
            writer.write(b'\r\n');
        } else {
            writer.write(data);
        }
        return len(data);
    }

    async def _bare_error(
        writer: asyncio.StreamWriter,
        status: int,
        reason: str,
        extra: (dict[str, str] | None) = None
    ) {
        body = f'{{"detail": "{reason}"}}'.encode('utf-8');
        lines = [
            f"HTTP/1.1 {status} {reason}",
            f"Date: {formatdate(usegmt=True)}",
            f"Server: {SERVER_HEADER}",
            "Content-Type: application/json",
            f"Content-Length: {len(body)}",
            "Connection: close"
        ];
        for (k, v) in (extra or {}).items() {
            lines.append(f"{k}: {v}");
        }
        blob = ('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1');
        try {
            writer.write(blob + body);
            await writer.drain();
        } except (ConnectionError, OSError) {}
    }
}
