import asyncio;
import os;
import ssl as ssl_lib;
import threading;
import time;
import queue as queue_lib;
import from base64 { b64encode }
import from concurrent.futures { ThreadPoolExecutor }
import from functools { cache }
import from json { dumps, loads }
import from urllib.parse { urlencode, urlsplit }
import from jaclang.server.serving.datatypes { Headers }
import from jaclang.server.serving.sse { parse_sse }
import from jaclang.server.serving.ws { WebSocket, compute_accept_key }


glob DEFAULT_TIMEOUT: float = 30.0,
     IDLE_TIMEOUT: float = 30.0,
     MAX_CONNECTION_AGE: float = 120.0,
     MAX_IDLE_PER_ORIGIN: int = 32,
     _IDEMPOTENT_METHODS: set[str] = {
         'GET',
         'HEAD',
         'PUT',
         'DELETE',
         'OPTIONS',
         'TRACE'
     },
     _FRAMING_HEADERS: set[str] = {'content-length', 'transfer-encoding'};


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

obj _PooledConn {
    has origin: tuple[str, str, int],
        reader: any,
        writer: any,
        opened: float = 0.0,
        idle_since: float = 0.0;
}

obj ClientResponse {
    has status_code: int = 0,
        reason: str = '',
        headers: Headers = Headers(),
        body: bytes = b'',
        reader: any = None,
        writer: any = None,
        chunked: bool = False,
        bodiless: bool = False,
        reusable: bool = False,
        _conn: (_PooledConn | None) = None,
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

    async def aiter_raw -> AsyncIterator[bytes] {
        if self.reader is None {
            if self.body {
                yield self.body;
            }
            return;
        }
        if self.bodiless {
            self._drained = True;
            return;
        }
        if self.chunked {
            while True {
                size_line: bytes = await self.reader.readline();
                if not size_line {
                    break;
                }
                size_text = size_line.decode('latin-1').strip().split(';')[0];
                int_fn: any = int;
                try {
                    size = int_fn(size_text, 16);
                } except ValueError {
                    break;
                }
                if size == 0 {
                    trailer: bytes = await self.reader.readline();
                    while trailer not in (b'\r\n', b'\n', b'') {
                        trailer = await self.reader.readline();
                    }
                    self._drained = True;
                    break;
                }
                chunk: bytes = await self.reader.readexactly(size);
                await self.reader.readexactly(2);
                yield chunk;
            }
        } else {
            length_header = self.headers.get('Content-Length');
            if length_header {
                remaining = int(length_header);
                while remaining > 0 {
                    block: bytes = await self.reader.read(min(65536, remaining));
                    if not block {
                        break;
                    }
                    remaining -= len(block);
                    yield block;
                }
                self._drained = remaining == 0;
            } else {
                while True {
                    block: bytes = await self.reader.read(65536);
                    if not block {
                        break;
                    }
                    yield block;
                }
            }
        }
    }

    async def aiter_lines -> AsyncIterator[bytes] {
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
        conn = self._conn;
        self._conn = None;
        self.reader = None;
        self.writer = None;
        if conn is None {
            return;
        }
        if self.reusable and self._drained {
            _release(conn);
        } else {
            _discard(conn);
        }
    }
}

def _idle_pool -> dict[tuple[str, str, int], list[_PooledConn]] {
    loop: any = asyncio.get_running_loop();
    if not hasattr(loop, '_jac_idle_conns') {
        loop._jac_idle_conns = {};
    }
    return loop._jac_idle_conns;
}

def _discard(conn: _PooledConn) {
    try {
        conn.writer.close();
    } except Exception {}
}

def _usable(conn: _PooledConn, now: float) -> bool {
    return not conn.writer.is_closing()
        and not conn.reader.at_eof()
        and len(conn.reader._buffer) == 0
        and now - conn.idle_since < IDLE_TIMEOUT
        and now - conn.opened < MAX_CONNECTION_AGE;
}

def _take_idle(origin: tuple[str, str, int]) -> (_PooledConn | None) {
    bucket = _idle_pool().get(origin) or [];
    now = time.monotonic();
    while bucket {
        conn = bucket.pop();
        if _usable(conn, now) {
            return conn;
        }
        _discard(conn);
    }
    return None;
}

def _release(conn: _PooledConn) {
    pool = _idle_pool();
    now = time.monotonic();
    for origin in list(pool) {
        kept: list[_PooledConn] = [];
        for idle in pool[origin] {
            if _usable(idle, now) {
                kept.append(idle);
            } else {
                _discard(idle);
            }
        }
        if kept {
            pool[origin] = kept;
        } else {
            del pool[origin];
        }
    }
    conn.idle_since = now;
    bucket = pool.get(conn.origin, []);
    if not _usable(conn, now) or len(bucket) >= MAX_IDLE_PER_ORIGIN {
        _discard(conn);
        return;
    }
    bucket.append(conn);
    pool[conn.origin] = bucket;
}

def _close_idle {
    pool = _idle_pool();
    for bucket in pool.values() {
        for conn in bucket {
            _discard(conn);
        }
    }
    pool.clear();
}

async def _closing_pool(coro: any) -> any {
    try {
        return await coro;
    } finally {
        _close_idle();
    }
}

@cache
def _tls_context -> any {
    return ssl_lib.create_default_context();
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

async def _connect(origin: tuple[str, str, int], timeout: float) -> _PooledConn {
    (reader, writer) = await _open_stream(origin[0], origin[1], origin[2], timeout);
    now = time.monotonic();
    return _PooledConn(
        origin=origin, reader=reader, writer=writer, opened=now, idle_since=now
    );
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
    return (parts[0], status, reason, headers);
}

async def _exchange(
    conn: _PooledConn, payload: bytes, timeout: float
) -> tuple[str, int, str, Headers] {
    try {
        conn.writer.write(payload);
        await conn.writer.drain();
        head = await _read_response_head(conn.reader, timeout);
        while 100 <= head[1] < 200 and head[1] != 101 {
            head = await _read_response_head(conn.reader, timeout);
        }
        return head;
    } except ClientRequestSent {
        _discard(conn);
        raise;
    } except (ConnectionError, OSError, asyncio.IncompleteReadError) as e {
        _discard(conn);
        raise ClientRequestSent(detail=f"connection lost during or after send: {e!r}");
    }
}

async def arequest(
    method: str,
    url: str,
    headers: (dict[str, any] | None) = None,
    json_body: any = None,
    data: (bytes | str | None) = None,
    timeout: float = DEFAULT_TIMEOUT,
    stream: bool = False,
    params: (dict[str, any] | None) = None
) -> ClientResponse {
    if params {
        sep = '&' if '?' in url else '?';
        url = f"{url}{sep}{urlencode(params, doseq=True)}";
    }
    (scheme, host, port, path) = _split_url(url);
    if scheme not in ('http', 'https') {
        raise ClientRequestNotSent(detail=f"unsupported scheme: {scheme}");
    }
    body = b'';
    header_list: list[tuple[str, str]] = [];
    seen: set[str] = set();
    for (k, v) in (headers or {}).items() {
        if str(k).lower() in _FRAMING_HEADERS {
            continue;
        }
        header_list.append((str(k), str(v)));
        seen.add(str(k).lower());
    }
    if json_body is not None {
        body = dumps(json_body, `default=_client_json_default).encode('utf-8');
        if 'content-type' not in seen {
            header_list.append(('Content-Type', 'application/json'));
        }
    } elif data is not None {
        body = data if isinstance(data, bytes) else str(data).encode('utf-8');
    }
    verb = method.upper();
    lines = [f"{verb} {path} HTTP/1.1"];
    if 'host' not in seen {
        default_port = 443 if scheme == 'https' else 80;
        host_value = host if port == default_port else f"{host}:{port}";
        lines.append(f"Host: {host_value}");
    }
    lines.append(f"Content-Length: {len(body)}");
    for (name, value) in header_list {
        lines.append(f"{name}: {value}");
    }
    payload = ('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1') + body;
    origin = (scheme, host, port);
    idle = _take_idle(origin);
    reused = idle is not None;
    conn: _PooledConn = idle if idle is not None else await _connect(origin, timeout);
    try {
        (version, status, reason, resp_headers) = await _exchange(
            conn, payload, timeout
        );
    } except ClientRequestSent as e {
        if not reused
            or isinstance(e, ClientReadTimeout)
            or verb not in _IDEMPOTENT_METHODS {
            raise;
        }
        conn = await _connect(origin, timeout);
        (version, status, reason, resp_headers) = await _exchange(
            conn, payload, timeout
        );
    }
    chunked = 'chunked' in (resp_headers.get('Transfer-Encoding') or '').lower();
    bodiless = verb == 'HEAD' or status in (204, 304);
    reusable = version == 'HTTP/1.1'
        and 'close' not in (resp_headers.get('Connection') or '').lower()
        and (bodiless or chunked or resp_headers.get('Content-Length') is not None);
    response = ClientResponse(
        status_code=status,
        reason=reason,
        headers=resp_headers,
        reader=conn.reader,
        writer=conn.writer,
        chunked=chunked,
        bodiless=bodiless,
        reusable=reusable,
        _conn=conn
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
        raise ClientRequestSent(detail=f"connection lost mid-body: {e!r}");
    } finally {
        await response.aclose();
    }
    response.body = b''.join(collected);
    return response;
}

async def aws_connect(
    url: str, headers: (dict[str, any] | None) = None, timeout: float = DEFAULT_TIMEOUT
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
    (_, status, reason, resp_headers) = await _read_response_head(reader, timeout);
    if status != 101 {
        try {
            writer.close();
        } except Exception {}
        raise ClientConnectionError(
            detail=f"websocket upgrade failed: {status} {reason}", status_code=status
        );
    }
    accept = resp_headers.get('Sec-WebSocket-Accept') or '';
    if accept != compute_accept_key(key) {
        try {
            writer.close();
        } except Exception {}
        raise ClientConnectionError(detail='Sec-WebSocket-Accept mismatch');
    }
    return WebSocket(
        reader=reader,
        writer=writer,
        is_client_side=True,
        accepted=True,
        subprotocol=str(resp_headers.get('Sec-WebSocket-Protocol') or '').strip()
    );
}

def run_blocking(coro: any) -> any {
    try {
        asyncio.get_running_loop();
    } except RuntimeError {
        return asyncio.run(_closing_pool(coro));
    }
    with ThreadPoolExecutor(max_workers=1) as pool {
        future = pool.submit(asyncio.run, _closing_pool(coro));
        return future.result();
    }
}

def request_sync(
    method: str,
    url: str,
    headers: (dict[str, any] | None) = None,
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
    headers: (dict[str, any] | None) = None,
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
            asyncio.run(_closing_pool(_pump()));
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
            } except Exception {}
        }
    }
    return ('sse', _generator());
}
