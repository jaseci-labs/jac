"""The native HTTP client keeps connections alive and reuses them."""

import asyncio;
import gc;
import weakref;
import from jaclang.server.serving.client {
    ClientConnectionError,
    ConnectionPool,
    _has_buffered_bytes,
    arequest,
    close_connection_pool,
    connection_pool
}


obj _FakeReader {
    has _buffer: bytes = b"";

    def at_eof -> bool {
        return False;
    }
}

obj _FakeWriter {
    has closing: bool = False;

    def is_closing -> bool {
        return self.closing;
    }

    def close {
        self.closing = True;
    }
}


glob _RESPONSES: dict[str, bytes] = {
         "/hello": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
         "/close": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nclose",
         "/chunked": b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
         b"5\r\nalpha\r\n4\r\nbeta\r\n0\r\n\r\n",
         "/nocontent": b"HTTP/1.1 204 No Content\r\n\r\n",
         "/overlong": b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhelloEXTRA"
     };


async def _read_request(reader: any) -> tuple[(str | None), list[str]] {
    names: list[str] = [];
    line: bytes = await reader.readline();
    if not line or line.strip() == b"" {
        return (None, names);
    }
    parts = line.decode("latin-1").strip().split(" ");
    length: int = 0;
    while True {
        raw: bytes = await reader.readline();
        if raw in (b"\r\n", b"\n", b"") {
            break;
        }
        (name, _, value) = raw.decode("latin-1").strip().partition(":");
        lowered = name.strip().lower();
        names.append(lowered);
        if lowered == "content-length" {
            length = int(value.strip());
        }
    }
    if length {
        await reader.readexactly(length);
    }
    return (parts[1] if len(parts) > 1 else "/", names);
}


obj _ProbeUpstream {
    has connections: int = 0,
        port: int = 0,
        drop_next: bool = False,
        drop_reused: bool = False,
        header_names: list[list[str]] = [],
        _server: any = None,
        _writers: list[any] = [];

    def base -> str {
        return f"http://127.0.0.1:{self.port}";
    }

    async def start {
        start_fn: any = asyncio.start_server;
        self._server = await start_fn(self._handle, host="127.0.0.1", port=0);
        self.port = self._server.sockets[0].getsockname()[1];
    }

    async def stop {
        self._server.close();
        try {
            await asyncio.wait_for(self._server.wait_closed(), timeout=5);
        } except asyncio.TimeoutError {}
    }

    def drop_connections {
        for writer in list(self._writers) {
            try {
                writer.transport.abort();
            } except Exception {}
        }
        self._writers = [];
    }

    async def _handle(reader: any, writer: any) {
        self.connections += 1;
        self._writers.append(writer);
        served: int = 0;
        try {
            while True {
                (path, names) = await _read_request(reader);
                if path is None {
                    break;
                }
                self.header_names.append(names);
                if self.drop_next or (self.drop_reused and served > 0) {
                    self.drop_next = False;
                    writer.transport.abort();
                    break;
                }
                served += 1;
                writer.write(_RESPONSES.get(path, _RESPONSES["/hello"]));
                await writer.drain();
                if path == "/close" {
                    break;
                }
            }
        } except Exception {}
        try {
            writer.close();
        } except Exception {}
    }
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


def _with_upstream(work: any) -> any {
    async def body -> any {
        upstream = _ProbeUpstream();
        await upstream.start();
        try {
            return await work(upstream);
        } finally {
            close_connection_pool();
            await upstream.stop();
        }
    }
    return _run(body());
}


def _fetch_sequence(paths: list[str]) -> dict {
    async def work(upstream: any) -> dict {
        seen: list[tuple[int, str]] = [];
        for path in paths {
            resp = await arequest("GET", f"{upstream.base()}{path}");
            seen.append((resp.status_code, resp.text()));
        }
        return {"seen": seen, "connections": upstream.connections};
    }
    return _with_upstream(work);
}


def _fetch_after_drop(method: str, payload: any) -> dict {
    async def work(upstream: any) -> dict {
        await arequest("GET", f"{upstream.base()}/hello");
        upstream.drop_next = True;
        text: (str | None) = None;
        try {
            resp = await arequest(
                method, f"{upstream.base()}/hello", json_body=payload
            );
            text = resp.text();
        } except ClientConnectionError {
            text = None;
        }
        return {"text": text, "connections": upstream.connections};
    }
    return _with_upstream(work);
}


test "connection reuse follows the response framing" {
    cases = [
        (
            ["/hello", "/hello", "/hello"],
            [(200, "hello"), (200, "hello"), (200, "hello")],
            1
        ),
        (["/nocontent", "/hello"], [(204, ""), (200, "hello")], 1),
        (["/close", "/hello"], [(200, "close"), (200, "hello")], 2),
        (["/overlong", "/hello"], [(200, "hello"), (200, "hello")], 2)
    ];
    for (paths, expected, expected_connections) in cases {
        result = _fetch_sequence(paths);
        assert result["seen"] == expected;
        assert result["connections"] == expected_connections;
    }
}


test "a dead pooled connection is retried only for idempotent methods" {
    cases = [("GET", None, "hello", 2), ("POST", {"n": 1}, None, 1)];
    for (method, payload, expected_text, expected_connections) in cases {
        result = _fetch_after_drop(method, payload);
        assert result["text"] == expected_text;
        assert result["connections"] == expected_connections;
    }
}


test "the retry opens a fresh connection instead of taking another dead one" {
    async def work(upstream: any) -> dict {
        await asyncio.gather(
            *[arequest("GET", f"{upstream.base()}/hello") for _ in range(2)]
        );
        pooled = connection_pool().idle_count();
        upstream.drop_reused = True;
        resp = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "pooled": pooled,
            "text": resp.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["pooled"] == 2;
    assert result["text"] == "hello";
    assert result["connections"] == 3;
}


test "a drained streaming response hands its connection back to the pool" {
    async def work(upstream: any) -> dict {
        streamed = await arequest("GET", f"{upstream.base()}/chunked", stream=True);
        collected = b"";
        async for chunk in streamed.aiter_raw() {
            collected += chunk;
        }
        await streamed.aclose();
        follow_up = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "streamed": collected.decode("utf-8"),
            "follow_up": follow_up.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["streamed"] == "alphabeta";
    assert result["follow_up"] == "hello";
    assert result["connections"] == 1;
}


test "a pooled connection dropped by the upstream is replaced transparently" {
    async def work(upstream: any) -> dict {
        first = await arequest("GET", f"{upstream.base()}/hello");
        upstream.drop_connections();
        await asyncio.sleep(0.05);
        second = await arequest("GET", f"{upstream.base()}/hello");
        return {
            "first": first.text(),
            "second": second.text(),
            "connections": upstream.connections
        };
    }
    result = _with_upstream(work);
    assert result["first"] == "hello";
    assert result["second"] == "hello";
    assert result["connections"] == 2;
}


test "the pool bounds how many idle connections it keeps per host" {
    async def work(upstream: any) -> int {
        pool = connection_pool();
        pool.max_idle_per_host = 1;
        await asyncio.gather(
            *[arequest("GET", f"{upstream.base()}/hello") for _ in range(3)]
        );
        return pool.idle_count();
    }
    assert _with_upstream(work) == 1;
}


test "a caller supplied content length does not reach the upstream" {
    async def work(upstream: any) -> dict {
        response = await arequest(
            "POST",
            f"{upstream.base()}/hello",
            headers={"Content-Length": "9999", "Transfer-Encoding": "chunked"},
            json_body={"n": 1}
        );
        return {"text": response.text(), "headers": upstream.header_names};
    }
    result = _with_upstream(work);
    assert result["text"] == "hello";
    sent = result["headers"][0];
    assert sent.count("content-length") == 1;
    assert "transfer-encoding" not in sent;
}


test "the buffered byte check reads asyncio's real buffer" {
    async def work -> list[bool] {
        reader_cls: any = asyncio.StreamReader;
        filled = reader_cls();
        filled.feed_data(b"leftover");
        return [
            _has_buffered_bytes(reader_cls()),
            _has_buffered_bytes(filled),
            _has_buffered_bytes(object())
        ];
    }
    assert _run(work()) == [False, True, True];
}


test "the pool keeps no empty or expired buckets" {
    expiring = ConnectionPool(idle_timeout=0.0);
    expiring.release("http://a:80", _FakeReader(), _FakeWriter());
    assert expiring.idle_count() == 1;
    expiring.release("http://b:80", _FakeReader(), _FakeWriter());
    assert "http://a:80" not in expiring._idle;
    assert expiring.idle_count() == 1;
    rejecting = ConnectionPool();
    rejecting.release("http://a:80", _FakeReader(), _FakeWriter(closing=True));
    assert rejecting._idle == {};
    assert rejecting.acquire("http://b:80") is None;
    assert rejecting._idle == {};
}


test "a loop with pooled connections is still collectable" {
    async def body -> any {
        upstream = _ProbeUpstream();
        await upstream.start();
        try {
            await arequest("GET", f"{upstream.base()}/hello");
            assert connection_pool().idle_count() == 1;
        } finally {
            await upstream.stop();
        }
        return None;
    }
    loop = asyncio.new_event_loop();
    loop.run_until_complete(body());
    ref = weakref.ref(loop);
    loop.close();
    del loop;
    gc.collect();
    gc.collect();
    assert ref() is None;
}
