import asyncio;
import os;
import ssl as ssl_lib;
import threading;
import time;
import weakref;
import queue as queue_lib;
import from base64 { b64encode }
import from concurrent.futures { ThreadPoolExecutor }
import from json { dumps, loads }
import from urllib.parse { urlencode, urlsplit }
import from jaclang.runtimelib.serving.datatypes { Headers }
import from jaclang.runtimelib.serving.sse { parse_sse }
import from jaclang.runtimelib.serving.ws { WebSocket, compute_accept_key }


glob DEFAULT_TIMEOUT: float = 30.0,
     DEFAULT_CONNECT_TIMEOUT: float = 10.0,
     MAX_IDLE_PER_HOST: int = 32,
     MAX_IDLE_TOTAL: int = 256,
     IDLE_TIMEOUT: float = 60.0;

glob _POOLS: any = weakref.WeakKeyDictionary(),
     _TLS_CONTEXT: dict[str, any] = {},
     _FRAMING_HEADERS: set[str] = {'content-length', 'transfer-encoding'},
     _POOL_ATTR: str = '_jac_client_pool',
     _IDEMPOTENT_METHODS: set[str] = {
         'DELETE',
         'GET',
         'HEAD',
         'OPTIONS',
         'PUT',
         'TRACE'
     };


obj ClientConnectionError(Exception) {
    has detail: str = 'connection failed',
        status_code: (int | None) = None,
        response: any = None;

    def __str__ -> str {
        return self.detail;
    }
}

obj ClientRequestNotSent(ClientConnectionError) {}

obj ClientRequestSent(ClientConnectionError) {}

obj ClientReadTimeout(ClientRequestSent) {}

def _client_json_default(o: any) -> str {
    return str(o);
}

def _close_writer(writer: any) {
    try {
        writer.close();
    } except Exception {
        ;
    }
}

def _has_buffered_bytes(reader: any) -> bool {
    try {
        return len(reader._buffer) > 0;
    } except Exception {
        return True;
    }
}

def _is_unusable(reader: any, writer: any) -> bool {
    try {
        return (
            bool(writer.is_closing())
            or bool(reader.at_eof())
            or _has_buffered_bytes(reader)
        );
    } except Exception {
        return True;
    }
}

obj ConnectionPool {
    has max_idle_per_host: int = MAX_IDLE_PER_HOST,
        max_idle_total: int = MAX_IDLE_TOTAL,
        idle_timeout: float = IDLE_TIMEOUT,
        _idle: dict[str, list[tuple[any, any, float]]] = {};

    def idle_count -> int {
        return sum([len(bucket) for bucket in self._idle.values()]);
    }

    def _sweep {
        now = time.monotonic();
        for (origin, bucket) in list(self._idle.items()) {
            live = [];
            for idle in bucket {
                (_reader, writer, expires_at) = idle;
                if now >= expires_at {
                    _close_writer(writer);
                } else {
                    live.append(idle);
                }
            }
            if live {
                self._idle[origin] = live;
            } else {
                del self._idle[origin];
            }
        }
    }

    def acquire(origin: str) -> (tuple[any, any] | None) {
        bucket = self._idle.get(origin) or [];
        while bucket {
            (reader, writer, expires_at) = bucket.pop();
            if time.monotonic() >= expires_at or _is_unusable(reader, writer) {
                _close_writer(writer);
                continue;
            }
            return (reader, writer);
        }
        if origin in self._idle and not self._idle[origin] {
            del self._idle[origin];
        }
        return None;
    }

    def release(origin: str, reader: any, writer: any) {
        if _is_unusable(reader, writer) {
            _close_writer(writer);
            return;
        }
        self._sweep();
        bucket = self._idle.get(origin) or [];
        if len(bucket) >= self.max_idle_per_host
            or self.idle_count() >= self.max_idle_total {
            _close_writer(writer);
            return;
        }
        bucket.append((reader, writer, time.monotonic() + self.idle_timeout));
        self._idle[origin] = bucket;
    }

    def close_all {
        for bucket in self._idle.values() {
            for (_reader, writer, _expires_at) in bucket {
                _close_writer(writer);
            }
        }
        self._idle = {};
    }
}

def _loop_pool(loop: any) -> (ConnectionPool | None) {
    return getattr(loop, _POOL_ATTR, None) or _POOLS.get(loop);
}

def _bind_loop_pool(loop: any, pool: ConnectionPool) {
    try {
        setattr(loop, _POOL_ATTR, pool);
    } except (AttributeError, TypeError) {
        _POOLS[loop] = pool;
    }
}

def _unbind_loop_pool(loop: any) -> (ConnectionPool | None) {
    pool = getattr(loop, _POOL_ATTR, None);
    if pool is not None {
        try {
            delattr(loop, _POOL_ATTR);
        } except (AttributeError, TypeError) {
            ;
        }
        return pool;
    }
    return _POOLS.pop(loop, None);
}

def connection_pool -> ConnectionPool {
    loop = asyncio.get_running_loop();
    pool = _loop_pool(loop);
    if pool is None {
        pool = ConnectionPool();
        _bind_loop_pool(loop, pool);
    }
    return pool;
}

def close_connection_pool {
    try {
        loop = asyncio.get_running_loop();
    } except RuntimeError {
        return;
    }
    pool = _unbind_loop_pool(loop);
    if pool is not None {
        pool.close_all();
    }
}

obj ClientResponse {
    has status_code: int = 0,
        reason: str = '',
        headers: Headers = Headers(),
        body: bytes = b'',
        reader: any = None,
        writer: any = None,
        chunked: bool = False,
        has_body: bool = True,
        _pool: any = None,
        _origin: str = '',
        _reusable: bool = False,
        _drained: bool = False;

    def json -> any {
        return loads(self.body) if self.body else None;
    }

    def text -> str {
        return self.body.decode('utf-8', errors='replace');
    }

    def ok -> bool {
        return 200 <= self.status_code < 400;
    }

    async def aiter_raw -> any {
        if self.reader is None {
            if self.body {
                yield self.body;
            }
            return;
        }
        if not self.has_body {
            self._drained = True;
            return;
        }
        if self.chunked {
            async for chunk in self._iter_chunked() {
                yield chunk;
            }
        } else {
            async for chunk in self._iter_sized() {
                yield chunk;
            }
        }
    }

    async def _iter_chunked -> any {
        while True {
            size_line: bytes = await self.reader.readline();
            if not size_line {
                return;
            }
            size_text = size_line.decode('latin-1').strip().split(';')[0];
            int_fn: any = int;
            try {
                size = int_fn(size_text, 16);
            } except ValueError {
                return;
            }
            if size == 0 {
                break;
            }
            chunk: bytes = await self.reader.readexactly(size);
            await self.reader.readexactly(2);
            yield chunk;
        }
        while True {
            trailer: bytes = await self.reader.readline();
            if trailer in (b'\r\n', b'\n', b'') {
                break;
            }
        }
        self._drained = True;
    }

    async def _iter_sized -> any {
        length = _content_length(self.headers);
        if length is None {
            while True {
                block: bytes = await self.reader.read(65536);
                if not block {
                    break;
                }
                yield block;
            }
            self._drained = True;
            return;
        }
        remaining: int = length;
        while remaining > 0 {
            block: bytes = await self.reader.read(min(65536, remaining));
            if not block {
                return;
            }
            remaining -= len(block);
            yield block;
        }
        self._drained = True;
    }

    async def aiter_lines -> any {
        buffer = b'';
        async for block in self.aiter_raw() {
            buffer += block;
            while b'\n' in buffer {
                (line, _, buffer) = buffer.partition(b'\n');
                yield line.rstrip(b'\r');
            }
        }
        if buffer {
            yield buffer.rstrip(b'\r');
        }
    }

    async def aclose {
        (reader, writer) = (self.reader, self.writer);
        self.reader = None;
        self.writer = None;
        if writer is None {
            return;
        }
        if self._drained and self._reusable and self._pool is not None {
            self._pool.release(self._origin, reader, writer);
        } else {
            _close_writer(writer);
        }
    }
}

def _content_length(headers: Headers) -> (int | None) {
    raw = headers.get('Content-Length');
    if raw is None {
        return None;
    }
    try {
        return int(raw);
    } except ValueError {
        return None;
    }
}

def _expects_body(method: str, status: int) -> bool {
    if method.upper() == 'HEAD' {
        return False;
    }
    return status >= 200 and status not in (204, 304);
}

def _is_reusable(
    version: str, headers: Headers, chunked: bool, has_body: bool
) -> bool {
    connection = (headers.get('Connection') or '').lower();
    if 'close' in connection {
        return False;
    }
    if version.upper() != 'HTTP/1.1' and 'keep-alive' not in connection {
        return False;
    }
    return not has_body or chunked or _content_length(headers) is not None;
}

def _split_url(url: str) -> tuple[str, str, int, str] {
    split = urlsplit(url);
    scheme = (split.scheme or 'http').lower();
    host = split.hostname or 'localhost';
    if split.port is not None {
        port = split.port;
    } elif scheme in ('https', 'wss') {
        port = 443;
    } else {
        port = 80;
    }
    path = split.path or '/';
    if split.query {
        path = f"{path}?{split.query}";
    }
    return (scheme, host, port, path);
}

def _tls_context -> any {
    context = _TLS_CONTEXT.get('default');
    if context is None {
        context = ssl_lib.create_default_context();
        _TLS_CONTEXT['default'] = context;
    }
    return context;
}

async def _open_stream(
    scheme: str, host: str, port: int, timeout: float
) -> tuple[any, any] {
    use_tls = scheme in ('https', 'wss');
    open_fn: any = asyncio.open_connection;
    try {
        ssl_ctx = _tls_context() if use_tls else None;
        pair: any = await asyncio.wait_for(
            open_fn(host, port, ssl=ssl_ctx), timeout=timeout
        );
        return (pair[0], pair[1]);
    } except asyncio.TimeoutError {
        raise ClientRequestNotSent(detail=f"connect timeout: {host}:{port}");
    } except OSError as e {
        raise ClientRequestNotSent(detail=f"{host}:{port}: {e}");
    }
}

async def _read_response_head(
    reader: any, timeout: float
) -> tuple[str, int, str, Headers] {
    try {
        status_line: bytes = await asyncio.wait_for(reader.readline(), timeout=timeout);
    } except asyncio.TimeoutError {
        raise ClientReadTimeout(detail=f"no response head within {timeout}s");
    }
    text = status_line.decode('latin-1').strip();
    parts = text.split(' ', 2);
    if len(parts) < 2 or not parts[1].isdigit() {
        raise ClientRequestSent(detail=f"bad status line: {text!r}");
    }
    version = parts[0];
    status = int(parts[1]);
    reason = parts[2] if len(parts) > 2 else '';
    headers = Headers();
    while True {
        try {
            raw: bytes = await asyncio.wait_for(reader.readline(), timeout=timeout);
        } except asyncio.TimeoutError {
            raise ClientReadTimeout(
                detail=f"response headers stalled beyond {timeout}s"
            );
        }
        if raw in (b'\r\n', b'\n', b'') {
            break;
        }
        line = raw.decode('latin-1').strip();
        if ':' in line {
            (name, _, value) = line.partition(':');
            headers.append(name.strip(), value.strip());
        }
    }
    return (version, status, reason, headers);
}

def _prepare_payload(
    headers: (dict | None), json_body: any, data: (bytes | str | None)
) -> tuple[bytes, list[tuple[str, str]], set[str]] {
    body = b'';
    header_list: list[tuple[str, str]] = [];
    seen: set[str] = set();
    for (k, v) in (headers or {}).items() {
        name = str(k);
        lowered = name.lower();
        if lowered in _FRAMING_HEADERS {
            continue;
        }
        header_list.append((name, str(v)));
        seen.add(lowered);
    }
    if json_body is not None {
        body = dumps(json_body, `default=_client_json_default).encode('utf-8');
        if 'content-type' not in seen {
            header_list.append(('Content-Type', 'application/json'));
        }
    } elif data is not None {
        body = data if isinstance(data, bytes) else str(data).encode('utf-8');
    }
    return (body, header_list, seen);
}

def _host_header(scheme: str, host: str, port: int) -> str {
    default_port = 443 if scheme == 'https' else 80;
    return host if port == default_port else f"{host}:{port}";
}

def _request_blob(
    method: str,
    path: str,
    host_header: (str | None),
    header_list: list[tuple[str, str]],
    body: bytes
) -> bytes {
    lines = [f"{method.upper()} {path} HTTP/1.1"];
    if host_header is not None {
        lines.append(f"Host: {host_header}");
    }
    lines.append(f"Content-Length: {len(body)}");
    for (name, value) in header_list {
        lines.append(f"{name}: {value}");
    }
    return ('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1') + body;
}

async def _read_response(
    pool: ConnectionPool,
    origin: str,
    reader: any,
    writer: any,
    head: tuple[str, int, str, Headers],
    method: str,
    stream: bool
) -> ClientResponse {
    (version, status, reason, resp_headers) = head;
    chunked = 'chunked' in (resp_headers.get('Transfer-Encoding') or '').lower();
    has_body = _expects_body(method, status);
    response = ClientResponse(
        status_code=status,
        reason=reason,
        headers=resp_headers,
        reader=reader,
        writer=writer,
        chunked=chunked,
        has_body=has_body,
        _pool=pool,
        _origin=origin,
        _reusable=status >= 200
            and _is_reusable(version, resp_headers, chunked, has_body)
    );
    if stream {
        return response;
    }
    collected: list[bytes] = [];
    try {
        async for block in response.aiter_raw() {
            collected.append(block);
        }
    } except (ConnectionError, OSError, asyncio.IncompleteReadError) as e {
        _close_writer(writer);
        raise ClientRequestSent(detail=f"connection lost mid-body: {e!r}");
    }
    response.body = b''.join(collected);
    await response.aclose();
    return response;
}

async def arequest(
    method: str,
    url: str,
    headers: (dict | None) = None,
    json_body: any = None,
    data: (bytes | str | None) = None,
    timeout: float = DEFAULT_TIMEOUT,
    stream: bool = False,
    params: (dict | None) = None
) -> ClientResponse {
    if params {
        sep = '&' if '?' in url else '?';
        url = f"{url}{sep}{urlencode(params, doseq=True)}";
    }
    (scheme, host, port, path) = _split_url(url);
    if scheme not in ('http', 'https') {
        raise ClientRequestNotSent(detail=f"unsupported scheme: {scheme}");
    }
    (body, header_list, seen) = _prepare_payload(headers, json_body, data);
    blob = _request_blob(
        method,
        path,
        None if 'host' in seen else _host_header(scheme, host, port),
        header_list,
        body
    );
    connect_timeout = min(DEFAULT_CONNECT_TIMEOUT, timeout);
    origin = f"{scheme}://{host}:{port}";
    pool = connection_pool();
    retried = False;
    replayable = method.upper() in _IDEMPOTENT_METHODS;
    while True {
        pooled = pool.acquire(origin);
        (reader, writer) = pooled
            if pooled is not None
            else await _open_stream(scheme, host, port, connect_timeout);
        try {
            writer.write(blob);
            await writer.drain();
            head = await _read_response_head(reader, timeout);
        } except (asyncio.TimeoutError, ClientReadTimeout) {
            _close_writer(writer);
            raise;
        } except (
            ConnectionError,
            OSError,
            asyncio.IncompleteReadError,
            ClientConnectionError
        ) as e {
            _close_writer(writer);
            if pooled is not None and not retried and replayable {
                retried = True;
                continue;
            }
            if isinstance(e, ClientConnectionError) {
                raise;
            }
            raise ClientRequestSent(
                detail=f"connection lost during or after send: {e!r}"
            );
        }
        return await _read_response(pool, origin, reader, writer, head, method, stream);
    }
}

async def aws_connect(
    url: str, headers: (dict | None) = None, timeout: float = DEFAULT_TIMEOUT
) -> WebSocket {
    (scheme, host, port, path) = _split_url(url);
    if scheme in ('http', 'ws') {
        scheme = 'ws';
    } elif scheme in ('https', 'wss') {
        scheme = 'wss';
    } else {
        raise ClientConnectionError(detail=f"unsupported scheme: {scheme}");
    }
    (reader, writer) = await _open_stream(scheme, host, port, timeout);
    key = b64encode(os.urandom(16)).decode('ascii');
    lines = [
        f"GET {path} HTTP/1.1",
        f"Host: {host}:{port}",
        'Upgrade: websocket',
        'Connection: Upgrade',
        f"Sec-WebSocket-Key: {key}",
        'Sec-WebSocket-Version: 13'
    ];
    for (k, v) in (headers or {}).items() {
        lines.append(f"{k}: {v}");
    }
    writer.write(('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1'));
    await writer.drain();
    (_version, status, reason, resp_headers) = await _read_response_head(
        reader, timeout
    );
    if status != 101 {
        _close_writer(writer);
        raise ClientConnectionError(
            detail=f"websocket upgrade failed: {status} {reason}", status_code=status
        );
    }
    accept = resp_headers.get('Sec-WebSocket-Accept') or '';
    if accept != compute_accept_key(key) {
        _close_writer(writer);
        raise ClientConnectionError(detail='Sec-WebSocket-Accept mismatch');
    }
    return WebSocket(reader=reader, writer=writer, is_client_side=True, accepted=True);
}

async def _with_pool_cleanup(coro: any) -> any {
    try {
        return await coro;
    } finally {
        close_connection_pool();
    }
}

def run_blocking(coro: any) -> any {
    wrapped: any = _with_pool_cleanup(coro);
    try {
        asyncio.get_running_loop();
    } except RuntimeError {
        return asyncio.run(wrapped);
    }
    with ThreadPoolExecutor(max_workers=1) as executor {
        future = executor.submit(asyncio.run, wrapped);
        return future.result();
    }
}

def request_sync(
    method: str,
    url: str,
    headers: (dict | None) = None,
    json_body: any = None,
    data: (bytes | str | None) = None,
    timeout: float = DEFAULT_TIMEOUT
) -> ClientResponse {
    return run_blocking(
        arequest(
            method,
            url,
            headers=headers,
            json_body=json_body,
            data=data,
            timeout=timeout
        )
    );
}

def post_stream_aware_sync(
    url: str,
    json_body: any = None,
    headers: (dict | None) = None,
    timeout: float = DEFAULT_TIMEOUT,
    label: str = 'rpc'
) -> tuple[str, any] {
    handshake: queue_lib.Queue = queue_lib.Queue();
    events: queue_lib.Queue = queue_lib.Queue();
    sentinel = object();

    async def _pump {
        response = await arequest(
            'POST',
            url,
            headers=headers,
            json_body=json_body,
            timeout=timeout,
            stream=True
        );
        try {
            ct = (response.headers.get('Content-Type') or '').lower();
            if not ct.startswith('text/event-stream') {
                collected: list[bytes] = [];
                async for block in response.aiter_raw() {
                    collected.append(block);
                }
                response.body = b''.join(collected);
                if response.status_code >= 400 {
                    handshake.put(
                        (
                            'exc',
                            ClientRequestSent(
                                detail=f"HTTP {response.status_code}: {response.text()}",
                                status_code=response.status_code
                            )
                        )
                    );
                } else {
                    handshake.put(('json', response.json()));
                }
                return;
            }
            handshake.put(('sse', None));
            lines: list[bytes] = [];
            async for line in response.aiter_lines() {
                lines.append(line);
                if line == b'' {
                    for item in parse_sse(lines) {
                        events.put(item);
                    }
                    lines = [];
                }
            }
            if lines {
                for item in parse_sse(lines + [b'']) {
                    events.put(item);
                }
            }
        } except Exception as e {
            events.put(('error', repr(e)));
            raise;
        } finally {
            await response.aclose();
            events.put(sentinel);
        }
    }

    def _runner {
        try {
            asyncio.run(_with_pool_cleanup(_pump()));
        } except Exception as e {
            handshake.put(('exc', e));
            events.put(sentinel);
        }
    }
    thread = threading.Thread(target=_runner, daemon=True);
    thread.start();
    try {
        first: any = handshake.get(timeout=timeout + 5);
    } except queue_lib.Empty {
        raise ClientRequestSent(
            detail=f"stream '{label}': no response within {timeout + 5}s"
        );
    }
    kind = str(first[0]);
    if kind == 'exc' {
        exc = first[1];
        if isinstance(exc, ClientConnectionError) {
            raise exc;
        }
        raise ClientRequestSent(detail=f"stream '{label}' failed: {exc!r}");
    }
    if kind == 'json' {
        return ('json', first[1]);
    }

    def _generator -> any {
        while True {
            item = events.get();
            if item is sentinel {
                return;
            }
            event_name = str(item[0]);
            payload_text = str(item[1]);
            if event_name == 'end' {
                return;
            }
            if event_name == 'error' {
                raise RuntimeError(f"stream '{label}' raised: {payload_text}");
            }
            try {
                yield loads(payload_text);
            } except Exception {
                ;
            }
        }
    }
    return ('sse', _generator());
}
