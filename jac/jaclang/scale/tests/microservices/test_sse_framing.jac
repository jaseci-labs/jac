import asyncio;
import gzip;
import random;
import threading;


def _run(coro: any) -> any {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


async def _collect(agen: any) -> list[any] {
    out: list[any] = [];
    async for frame in agen {
        out.append(frame);
    }
    return out;
}


async def _drive_blocking_sync(consume: any, item: any) -> tuple[any, list[bool]] {
    loop = asyncio.get_running_loop();
    started = threading.Event();
    release = threading.Event();
    callback_ran = threading.Event();
    resumed: list[bool] = [];

    def producer -> Iterator[any] {
        started.set();
        release.`wait(10);
        resumed.append(callback_ran.is_set());
        yield item;
    }
    def on_loop {
        callback_ran.set();
        release.set();
    }
    def control {
        try {
            if started.`wait(10) {
                loop.call_soon_threadsafe(on_loop);
                release.`wait(10);
            }
        } finally {
            # Release the generator even if the loop is blocked by next().
            release.set();
        }
    }
    controller = threading.Thread(target=control);
    controller.start();
    try {
        result = await consume(producer());
    } finally {
        release.set();
        controller.join(10);
    }
    assert not controller.is_alive();
    return (result, resumed);
}


obj _Writer {
    has chunks: list[bytes] = [];

    def write(chunk: bytes) {
        self.chunks.append(chunk);
    }

    async def drain {}
}


obj _BlockingIterable {
    has source: any;

    def __iter__ -> Iterator[any] {
        return iter([next(self.source)]);
    }
}


async def _async_producer -> AsyncIterator[dict[str, any]] {
    yield {"n": 0};
    yield {"n": 1};
    yield {"n": 2};
}


async def _raising_producer -> AsyncIterator[dict[str, any]] {
    yield {"ok": 1};
    raise ValueError("boom");
}


def _sync_producer -> Iterator[dict[str, any]] {
    yield {"a": 1};
    yield {"a": 2};
}


test "sse_frame_stream frames each async item as a data: line and ends with event: end" {
    frames = _run(_collect(sse_frame_stream(_async_producer())));

    assert len(frames) == 4;
    assert frames[0] == "data: {\"n\": 0}\n\n";
    assert frames[1] == "data: {\"n\": 1}\n\n";
    assert frames[2] == "data: {\"n\": 2}\n\n";
    assert frames[3] == "event: end\ndata: {}\n\n";

    # every data frame is terminated by a blank line per SSE wire format
    for f in frames[0:3] {
        assert f.startswith("data: ");
        assert f.endswith("\n\n");
    }
}


test "sse_frame_stream drives a real sync generator through run_in_executor" {
    frames = _run(_collect(sse_frame_stream(_sync_producer())));

    assert len(frames) == 3;
    assert frames[0] == "data: {\"a\": 1}\n\n";
    assert frames[1] == "data: {\"a\": 2}\n\n";
    assert frames[2] == "event: end\ndata: {}\n\n";
}


test "sse_frame_stream keeps the event loop responsive while a sync producer blocks" {
    async def consume(source: any) -> list[any] {
        return await _collect(sse_frame_stream(source));
    }
    (frames, resumed) = _run(_drive_blocking_sync(consume, {"a": 1}));

    assert resumed == [True];
    assert frames == ["data: {\"a\": 1}\n\n", "event: end\ndata: {}\n\n"];
}


test "direct streaming responses keep the event loop responsive while a sync producer blocks" {
    server = ServingServer(app=ServingApp());
    writer: any = _Writer();
    async def consume(source: any) -> int {
        return await server._write_stream(writer, source, chunked=True);
    }
    (sent, resumed) = _run(_drive_blocking_sync(consume, b'hello'));

    assert resumed == [True];
    assert sent == 5;
    assert writer.chunks == [b'5\r\n', b'hello', b'\r\n'];
}


test "direct streaming responses keep the event loop responsive during iterator setup" {
    server = ServingServer(app=ServingApp());
    writer: any = _Writer();
    async def consume(source: any) -> int {
        return await server._write_stream(
            writer, _BlockingIterable(source=source), chunked=True
        );
    }
    (sent, resumed) = _run(_drive_blocking_sync(consume, b'hello'));

    assert resumed == [True];
    assert sent == 5;
    assert writer.chunks == [b'5\r\n', b'hello', b'\r\n'];
}


test "gzip streaming keeps the event loop responsive while a sync producer blocks" {
    async def consume(source: any) -> list[any] {
        return await _collect(_gzip_stream(source, 4));
    }
    (chunks, resumed) = _run(_drive_blocking_sync(consume, b'hello'));

    assert resumed == [True];
    assert gzip.decompress(b''.join(chunks)) == b'hello';
}


test "discarding a sync stream keeps the event loop responsive" {
    server = ServingServer(app=ServingApp());
    async def consume(source: any) {
        await server._discard_stream(source);
    }
    (_, resumed) = _run(_drive_blocking_sync(consume, b'hello'));

    assert resumed == [True];
}


test "sse_frame_stream preserves errors from a sync producer" {
    def producer -> Iterator[dict[str, any]] {
        yield {"ok": 1};
        raise ValueError("boom");
    }
    frames = _run(_collect(sse_frame_stream(producer())));

    assert len(frames) == 2;
    assert frames[0] == "data: {\"ok\": 1}\n\n";
    assert frames[1].startswith("event: error\ndata: ");
    assert "\"error_type\": \"ValueError\"" in frames[1];
    assert "\"message\": \"boom\"" in frames[1];
}


test "sse_frame_stream emits event: error and no end frame when the producer raises" {
    frames = _run(_collect(sse_frame_stream(_raising_producer())));

    assert len(frames) == 2;
    assert frames[0] == "data: {\"ok\": 1}\n\n";

    err = frames[1];
    assert err.startswith("event: error\ndata: ");
    assert err.endswith("\n\n");
    assert "\"error_type\": \"ValueError\"" in err;
    assert "\"message\": \"boom\"" in err;

    # the success terminator must NOT be emitted on the error path
    for f in frames {
        assert not f.startswith("event: end");
    }
}


test "sse_frame_stream rejects a non-generator argument with TypeError" {
    raised: bool = False;
    try {
        _run(_collect(sse_frame_stream([1, 2, 3])));
    } except TypeError {
        raised = True;
    }
    assert raised;
}


test "gzip cache reuses the packed bytes for a repeat body with the same etag" {
    cache = GzipCache(max_bytes=1 << 20);
    body = b"x" * 5000;
    first = cache.pack(body, 4, 'W/"a"');
    assert gzip.decompress(first) == body;
    assert cache.pack(body, 4, 'W/"a"') is first;
    assert len(cache.entries) == 1;
    assert cache.total == len(first);
}


test "gzip cache keys tell level and etag apart and skip untagged bodies" {
    cache = GzipCache(max_bytes=1 << 20);
    body = b"y" * 5000;
    cache.pack(body, 4, 'W/"a"');
    cache.pack(body, 6, 'W/"a"');
    cache.pack(body, 4, 'W/"b"');
    untagged = cache.pack(body, 4, None);
    assert gzip.decompress(untagged) == body;
    assert len(cache.entries) == 3;
    assert cache.total == sum(len(v) for v in cache.entries.values());
}


test "gzip cache evicts the oldest entries to stay under its byte limit" {
    rng = random.Random(7);
    bodies = [rng.randbytes(2000) for _ in range(4)];
    one = len(gzip.compress(bodies[0], compresslevel=4, mtime=0));
    cache = GzipCache(max_bytes=one * 2 + one // 2);
    for (i, body) in enumerate(bodies) {
        packed = cache.pack(body, 4, f'W/"{i}"');
        assert gzip.decompress(packed) == body;
        assert cache.total <= cache.max_bytes;
    }
    assert len(cache.entries) == 2;
    assert sorted(k[0] for k in cache.entries) == ['W/"2"', 'W/"3"'];
    assert cache.total == sum(len(v) for v in cache.entries.values());
}


test "gzip cache does not keep an entry larger than its limit" {
    cache = GzipCache(max_bytes=100);
    body = random.Random(3).randbytes(2000);
    packed = cache.pack(body, 4, 'W/"big"');
    assert gzip.decompress(packed) == body;
    assert len(cache.entries) == 0;
    assert cache.total == 0;
}


test "compression leaves a partial content response untouched" {
    headers = Headers();
    headers.set("Accept-Encoding", "gzip");
    req = Request(headers=headers);
    raw = b"a" * 4096;
    resp = Response(content=raw, status_code=206, media_type="text/javascript");
    resp.headers.set("Content-Range", "bytes 0-4095/9000");
    out = CompressionPolicy().apply(req, resp, resp.body_bytes());
    assert out == raw;
    assert resp.headers.get("Content-Encoding") is None;
    assert resp.headers.get("Content-Range") == "bytes 0-4095/9000";
}
