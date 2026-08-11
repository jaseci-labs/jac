import asyncio;
import os;
import ssl as ssl_lib;
import threading;
import queue as queue_lib;
import from base64 { b64encode }
import from concurrent.futures { ThreadPoolExecutor }
import from json { dumps, loads }
import from urllib.parse { urlencode, urlsplit }
import from jaclang.runtimelib.serving.datatypes { Headers }
import from jaclang.runtimelib.serving.sse { parse_sse }
import from jaclang.runtimelib.serving.ws { WebSocket, compute_accept_key }


glob DEFAULT_TIMEOUT: float = 30.0;


obj ClientConnectionError(Exception) {
    has detail: str = 'connection failed',
        status_code: (int | None) = None,
        response: any = None;

    def __str__ -> str {
        return self.detail;
    }
}

def _client_json_default(o: any) -> str {
    return str(o);
}

obj ClientResponse {
    has status_code: int = 0,
        reason: str = '',
        headers: Headers = Headers(),
        body: bytes = b'',
        reader: any = None,
        writer: any = None,
        chunked: bool = False;

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
        if self.writer is not None {
            try {
                self.writer.close();
            } except Exception {
                ;
            }
        }
    }
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
    ssl_ctx = ssl_lib.create_default_context() if use_tls else None;
    open_fn: any = asyncio.open_connection;
    try {
        pair: any = await asyncio.wait_for(
            open_fn(host, port, ssl=ssl_ctx), timeout=timeout
        );
        return (pair[0], pair[1]);
    } except asyncio.TimeoutError {
        raise ClientConnectionError(detail=f"connect timeout: {host}:{port}");
    } except OSError as e {
        raise ClientConnectionError(detail=f"{host}:{port}: {e}");
    }
}

async def _read_response_head(reader: any, timeout: float) -> tuple[int, str, Headers] {
    status_line: bytes = await asyncio.wait_for(reader.readline(), timeout=timeout);
    text = status_line.decode('latin-1').strip();
    parts = text.split(' ', 2);
    if len(parts) < 2 or not parts[1].isdigit() {
        raise ClientConnectionError(detail=f"bad status line: {text!r}");
    }
    status = int(parts[1]);
    reason = parts[2] if len(parts) > 2 else '';
    headers = Headers();
    while True {
        raw: bytes = await asyncio.wait_for(reader.readline(), timeout=timeout);
        if raw in (b'\r\n', b'\n', b'') {
            break;
        }
        line = raw.decode('latin-1').strip();
        if ':' in line {
            (name, _, value) = line.partition(':');
            headers.append(name.strip(), value.strip());
        }
    }
    return (status, reason, headers);
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
        raise ClientConnectionError(detail=f"unsupported scheme: {scheme}");
    }
    body = b'';
    header_list: list[tuple[str, str]] = [];
    seen: set[str] = set();
    for (k, v) in (headers or {}).items() {
        header_list.append((str(k), str(v)));
        seen.add(str(k).lower());
    }
    if json_body is not None {
        body = dumps(json_body, default=_client_json_default).encode('utf-8');
        if 'content-type' not in seen {
            header_list.append(('Content-Type', 'application/json'));
        }
    } elif data is not None {
        body = data if isinstance(data, bytes) else str(data).encode('utf-8');
    }
    (reader, writer) = await _open_stream(scheme, host, port, timeout);
    lines = [f"{method.upper()} {path} HTTP/1.1"];
    if 'host' not in seen {
        default_port = 443 if scheme == 'https' else 80;
        host_value = host if port == default_port else f"{host}:{port}";
        lines.append(f"Host: {host_value}");
    }
    lines.append(f"Content-Length: {len(body)}");
    lines.append('Connection: close');
    for (name, value) in header_list {
        lines.append(f"{name}: {value}");
    }
    blob = ('\r\n'.join(lines) + '\r\n\r\n').encode('latin-1');
    try {
        writer.write(blob + body);
        await writer.drain();
        (status, reason, resp_headers) = await _read_response_head(reader, timeout);
    } except (ConnectionError, OSError, asyncio.IncompleteReadError) as e {
        try {
            writer.close();
        } except Exception {
            ;
        }
        raise ClientConnectionError(detail=str(e));
    }
    transfer = (resp_headers.get('Transfer-Encoding') or '').lower();
    chunked = 'chunked' in transfer;
    response = ClientResponse(
        status_code=status, reason=reason, headers=resp_headers, chunked=chunked
    );
    if stream {
        response.reader = reader;
        response.writer = writer;
        return response;
    }
    collected: list[bytes] = [];
    response.reader = reader;
    async for block in response.aiter_raw() {
        collected.append(block);
    }
    response.reader = None;
    response.body = b''.join(collected);
    try {
        writer.close();
    } except Exception {
        ;
    }
    return response;
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
    (status, reason, resp_headers) = await _read_response_head(reader, timeout);
    if status != 101 {
        try {
            writer.close();
        } except Exception {
            ;
        }
        raise ClientConnectionError(
            detail=f"websocket upgrade failed: {status} {reason}", status_code=status
        );
    }
    accept = resp_headers.get('Sec-WebSocket-Accept') or '';
    if accept != compute_accept_key(key) {
        try {
            writer.close();
        } except Exception {
            ;
        }
        raise ClientConnectionError(detail='Sec-WebSocket-Accept mismatch');
    }
    return WebSocket(reader=reader, writer=writer, is_client_side=True, accepted=True);
}

def run_blocking(coro: any) -> any {
    try {
        asyncio.get_running_loop();
    } except RuntimeError {
        return asyncio.run(coro);
    }
    with ThreadPoolExecutor(max_workers=1) as pool {
        future = pool.submit(asyncio.run, coro);
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
                        ('error', f"HTTP {response.status_code}: {response.text()}")
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
        } finally {
            await response.aclose();
            events.put(sentinel);
        }
    }

    def _runner {
        try {
            asyncio.run(_pump());
        } except Exception as e {
            handshake.put(('error', str(e)));
            events.put(('error', str(e)));
            events.put(sentinel);
        }
    }
    thread = threading.Thread(target=_runner, daemon=True);
    thread.start();
    first: any = handshake.get(timeout=timeout + 5);
    kind = str(first[0]);
    if kind == 'error' {
        raise ClientConnectionError(detail=str(first[1]));
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
