impl _test_json_default(o: any) -> str {
    return str(o);
}

impl TestResponse.json -> any {
    return loads(self.content) if self.content else None;
}

impl SyncWebSocket._ensure_loop {
    if self._loop is not None {
        return;
    }
    self._loop = asyncio.new_event_loop();

    def _spin {
        asyncio.set_event_loop(self._loop);
        self._loop.run_forever();
    }
    self._thread = threading.Thread(target=_spin, daemon=True);
    self._thread.start();
}

impl SyncWebSocket._run(coro: any) -> any {
    future: any = asyncio.run_coroutine_threadsafe(coro, self._loop);
    return future.result(timeout=30);
}

impl SyncWebSocket.connect {
    self._ensure_loop();
    self._ws = self._run(aws_connect(self.url, headers=self.extra_headers));
}

impl SyncWebSocket.send_json(data: any) {
    self._run(self._ws.send_json(data));
}

impl SyncWebSocket.send_text(text: str) {
    self._run(self._ws.send_text(text));
}

impl SyncWebSocket.send_bytes(data: bytes) {
    self._run(self._ws.send_bytes(data));
}

impl SyncWebSocket.receive_json -> any {
    return self._run(self._ws.receive_json());
}

impl SyncWebSocket.receive_text -> str {
    return self._run(self._ws.receive_text());
}

impl SyncWebSocket.receive -> dict[str, any] {
    return self._run(self._ws.receive());
}

impl SyncWebSocket.close(code: int = 1000) {
    if self._ws is not None {
        try {
            self._run(self._ws.close(code));
        } except Exception {}
    }
    if self._loop is not None {
        self._loop.call_soon_threadsafe(self._loop.stop);
        self._thread.join(timeout=5);
        if not self._loop.is_running() {
            self._loop.close();
        }
        self._loop = None;
    }
}

impl SyncWebSocket.__enter__ -> SyncWebSocket {
    self.connect();
    return self;
}

impl SyncWebSocket.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    self.close();
    return False;
}

impl ServingTestClient.request(
    method: str,
    path: str,
    json: any = None,
    data: any = None,
    content: any = None,
    files: (dict[str, any] | list[tuple[str, any]] | None) = None,
    params: (dict[str, any] | None) = None,
    headers: (dict[str, any] | None) = None,
    follow_redirects: (bool | None) = None
) -> TestResponse {
    if follow_redirects is None {
        follow_redirects = self.follow_redirects;
    }
    target = path;
    if params {
        sep = '&' if '?' in target else '?';
        target = f"{target}{sep}{urlencode(params, doseq=True)}";
    }
    header_obj = Headers();
    for (k, v) in self.base_headers.items() {
        header_obj.append(str(k), str(v));
    }
    for (k, v) in (headers or {}).items() {
        header_obj.set(str(k), str(v));
    }
    body = b'';
    if files {
        (body, content_type) = _build_multipart(files, data);
        header_obj.set('Content-Type', content_type);
    } elif json is not None {
        body = dumps(json, `default=_test_json_default).encode('utf-8');
        if header_obj.get('Content-Type') is None {
            header_obj.set('Content-Type', 'application/json');
        }
    } elif content is not None {
        body = content if isinstance(content, bytes) else str(content).encode('utf-8');
    } elif isinstance(data, dict) {
        body = urlencode(data, doseq=True).encode('utf-8');
        header_obj.set('Content-Type', 'application/x-www-form-urlencoded');
    } elif data is not None {
        body = data if isinstance(data, bytes) else str(data).encode('utf-8');
    }
    split_path = target.split('?', 1);
    query = split_path[1] if len(split_path) > 1 else '';
    request = Request(
        method=method.upper(),
        url=URL(path=split_path[0], query=query),
        headers=header_obj,
        query_params=QueryParams(raw=parse_query_string(query)),
        body=body,
        client_host='testclient'
    );
    outcome: tuple[Response, bytes] = run_blocking(
        self._dispatch_chain(request, follow_redirects)
    );
    response = outcome[0];
    content = outcome[1];
    if response.headers.get('Content-Type') is None {
        response.headers.set('Content-Type', response.content_type_header());
    }
    return TestResponse(
        status_code=response.status_code, headers=response.headers, content=content
    );
}

impl ServingTestClient._dispatch_chain(
    request: Request, follow_redirects: bool
) -> tuple[Response, bytes] {
    response = await self.app.dispatch(request);
    hops = 0;
    while follow_redirects
        and response.status_code in (301, 302, 303, 307, 308)
        and hops < 5 {
        location = response.headers.get('Location');
        if not location or '://' in location {
            break;
        }
        hops += 1;
        next_method = request.method;
        next_body = request.body;
        if response.status_code == 303
            or (response.status_code in (301, 302) and next_method == 'POST') {
            next_method = 'GET';
            next_body = b'';
        }
        loc_split = location.split('?', 1);
        loc_query = loc_split[1] if len(loc_split) > 1 else '';
        request = Request(
            method=next_method,
            url=URL(path=loc_split[0], query=loc_query),
            headers=request.headers,
            query_params=QueryParams(raw=parse_query_string(loc_query)),
            body=next_body,
            client_host='testclient'
        );
        response = await self.app.dispatch(request);
    }
    content = await collect_response_stream(response);
    return (response, content);
}

impl ServingTestClient.get(path: str, **kwargs: any) -> TestResponse {
    return self.request('GET', path, **kwargs);
}

impl ServingTestClient.post(path: str, **kwargs: any) -> TestResponse {
    return self.request('POST', path, **kwargs);
}

impl ServingTestClient.put(path: str, **kwargs: any) -> TestResponse {
    return self.request('PUT', path, **kwargs);
}

impl ServingTestClient.patch(path: str, **kwargs: any) -> TestResponse {
    return self.request('PATCH', path, **kwargs);
}

impl ServingTestClient.delete(path: str, **kwargs: any) -> TestResponse {
    return self.request('DELETE', path, **kwargs);
}

impl ServingTestClient.options(path: str, **kwargs: any) -> TestResponse {
    return self.request('OPTIONS', path, **kwargs);
}

impl ServingTestClient.head(path: str, **kwargs: any) -> TestResponse {
    return self.request('HEAD', path, **kwargs);
}

impl ServingTestClient._ensure_live_server -> int {
    if self._server is None {
        self._server = ServingServer(app=self.app, host='127.0.0.1', port=0);
        self._stop_server = self._server.serve_background();
    }
    return self._server.bound_port;
}

impl ServingTestClient.websocket_connect(
    path: str, headers: (dict[str, any] | None) = None
) -> SyncWebSocket {
    port = self._ensure_live_server();
    merged: dict[str, str] = {};
    for (k, v) in self.base_headers.items() {
        merged[str(k)] = str(v);
    }
    for (k, v) in (headers or {}).items() {
        merged[str(k)] = str(v);
    }
    return SyncWebSocket(url=f"ws://127.0.0.1:{port}{path}", extra_headers=merged);
}

impl ServingTestClient.close {
    if self._stop_server is not None {
        stop_fn: any = self._stop_server;
        stop_fn();
        self._server = None;
        self._stop_server = None;
    }
}

impl collect_response_stream(response: any) -> bytes {
    if response.stream is None {
        return response.body_bytes();
    }
    stream = response.stream;
    collected: list[bytes] = [];
    if hasattr(stream, '__aiter__') {
        async for chunk in stream {
            collected.append(
                chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8')
            );
        }
    } else {
        for chunk in stream {
            collected.append(
                chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8')
            );
        }
    }
    return b''.join(collected);
}

impl dispatch_and_collect(app: any, request: any) -> tuple[any, bytes] {
    response = await app.dispatch(request);
    content = await collect_response_stream(response);
    return (response, content);
}

impl _build_multipart(files: any, data: any = None) -> tuple[bytes, str] {
    boundary = f"jactest{secrets.token_hex(16)}";
    parts: list[bytes] = [];
    pairs = list(files.items()) if isinstance(files, dict) else list(files);
    for (field, spec) in pairs {
        filename = str(field);
        content: bytes = b'';
        ctype = 'application/octet-stream';
        if isinstance(spec, tuple) {
            if len(spec) >= 1 and spec[0] {
                filename = str(spec[0]);
            }
            if len(spec) >= 2 {
                raw = spec[1];
                if hasattr(raw, 'read') {
                    content = raw.read();
                } else {
                    content = raw
                        if isinstance(raw, bytes)
                        else str(raw).encode('utf-8');
                }
            }
            if len(spec) >= 3 and spec[2] {
                ctype = str(spec[2]);
            }
        } elif hasattr(spec, 'read') {
            content = spec.read();
        } else {
            content = spec if isinstance(spec, bytes) else str(spec).encode('utf-8');
        }
        head = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{field}"; '
            f'filename="{filename}"\r\n'
            f"Content-Type: {ctype}\r\n\r\n"
        ).encode(
            'utf-8'
        );
        parts.append(head + content + b'\r\n');
    }
    if isinstance(data, dict) {
        for (field, value) in data.items() {
            head = (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="{field}"\r\n\r\n'
            ).encode(
                'utf-8'
            );
            parts.append(head + str(value).encode('utf-8') + b'\r\n');
        }
    }
    body = b''.join(parts) + f"--{boundary}--\r\n".encode('utf-8');
    return (body, f"multipart/form-data; boundary={boundary}");
}

impl TestResponse.text.getter -> str {
    return self.content.decode('utf-8', errors='replace');
}

impl TestResponse.ok.getter -> bool {
    return 200 <= self.status_code < 300;
}
