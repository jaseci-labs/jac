impl HTTPError.__str__ -> str {
    return self.detail or f"HTTP {self.status_code}";
}

impl WebSocketDisconnect.__str__ -> str {
    return f"WebSocket disconnected: {self.code}";
}

impl Headers.get(name: str, default_value: (str | None) = None) -> (str | None) {
    low = name.lower();
    for (k, v) in self.raw {
        if k.lower() == low {
            return v;
        }
    }
    return default_value;
}

impl Headers.getlist(name: str) -> list[str] {
    low = name.lower();
    return [
        v
        for (k, v) in self.raw
        if k.lower() == low
    ];
}

impl Headers.items -> list[tuple[str, str]] {
    return list(self.raw);
}

impl Headers.keys -> list[str] {
    return [k for (k, v) in self.raw];
}

impl Headers.set(name: str, value: str) {
    low = name.lower();
    self.raw = [
        (k, v)
        for (k, v) in self.raw
        if k.lower() != low
    ];
    self.raw.append((name, value));
}

impl Headers.append(name: str, value: str) {
    self.raw.append((name, value));
}

impl Headers.remove(name: str) {
    low = name.lower();
    self.raw = [
        (k, v)
        for (k, v) in self.raw
        if k.lower() != low
    ];
}

impl Headers.add_vary(field: str) {
    existing = [
        v.strip() for raw in self.getlist('Vary')
        for v in str(raw).split(',')
        if v.strip()
    ];
    if any(v.lower() == field.lower() for v in existing) {
        return;
    }
    self.set('Vary', ', '.join(existing + [field]));
}

impl Headers.__contains__(name: str) -> bool {
    return self.get(name) is not None;
}

impl Headers.__getitem__(name: str) -> str {
    found = self.get(name);
    if found is None {
        raise KeyError(name);
    }
    return found;
}

impl Headers.__setitem__(name: str, value: str) {
    self.set(name, value);
}

impl QueryParams.get(name: str, default_value: (str | None) = None) -> (str | None) {
    values = self.raw.get(name);
    return values[0] if values else default_value;
}

impl QueryParams.getlist(name: str) -> list[str] {
    return list(self.raw.get(name, []));
}

impl QueryParams.keys -> list[str] {
    return list(self.raw.keys());
}

impl QueryParams.items -> list[tuple[str, str]] {
    return [
        (k, v[0])
        for (k, v) in self.raw.items()
        if v
    ];
}

impl QueryParams.__contains__(name: str) -> bool {
    return name in self.raw;
}

impl QueryParams.__getitem__(name: str) -> str {
    found = self.get(name);
    if found is None {
        raise KeyError(name);
    }
    return found;
}

impl URL.full -> str {
    base = f"{self.scheme}://{self.netloc}" if self.netloc else '';
    qs = f"?{self.query}" if self.query else '';
    return f"{base}{self.path}{qs}";
}

impl UploadFile.from_bytes(
    filename: str, content_type: str, data: bytes
) -> UploadFile {
    import io;
    return UploadFile(
        filename=filename,
        content_type=content_type,
        _file=io.BytesIO(data),
        _size=len(data)
    );
}

impl UploadFile.read(size: int = -1) -> bytes {
    return self.file.read(size);
}

impl UploadFile.seek(offset: int) {
    self.file.seek(offset);
}

impl UploadFile.close {
    self.file.close();
}

impl Request.json -> any {
    return self.json_sync();
}

impl Request.json_sync -> any {
    if not self.body {
        return None;
    }
    return loads(self.body);
}

impl _normalize_headers(headers: any) -> Headers {
    if isinstance(headers, Headers) {
        return headers;
    }
    result = Headers();
    if isinstance(headers, dict) {
        for (k, v) in headers.items() {
            result.append(str(k), str(v));
        }
    } elif isinstance(headers, list) {
        for (k, v) in headers {
            result.append(str(k), str(v));
        }
    }
    return result;
}

impl _json_default(o: any) -> str {
    return str(o);
}

impl Response.init(
    self: Response,
    content: any = b'',
    status_code: int = 200,
    media_type: str = 'text/plain; charset=utf-8',
    headers: any = None
) {
    self.content = content;
    self.status_code = status_code;
    self.media_type = media_type;
    self.headers = _normalize_headers(headers);
    self.stream: any = None;
}

impl Response.body_bytes(self: Response) -> bytes {
    if isinstance(self.content, bytes) {
        return self.content;
    }
    if self.content is None {
        return b'';
    }
    return str(self.content).encode('utf-8');
}

impl Response.content_type_header(self: Response) -> str {
    mt = self.media_type;
    if mt.startswith('text/') and 'charset=' not in mt {
        return f"{mt}; charset=utf-8";
    }
    return mt;
}

impl JSONResponse.init(
    self: JSONResponse,
    content: any = None,
    status_code: int = 200,
    headers: any = None,
    media_type: str = 'application/json'
) {
    super.init(
        content=content, status_code=status_code, media_type=media_type, headers=headers
    );
}

impl JSONResponse.body_bytes(self: JSONResponse) -> bytes {
    return dumps(self.content, `default=_json_default).encode('utf-8');
}

impl HTMLResponse.init(
    self: HTMLResponse, content: any = '', status_code: int = 200, headers: any = None
) {
    super.init(
        content=content,
        status_code=status_code,
        media_type='text/html; charset=utf-8',
        headers=headers
    );
}

impl RedirectResponse.init(
    self: RedirectResponse, url: str, status_code: int = 307, headers: any = None
) {
    super.init(
        content=b'',
        status_code=status_code,
        media_type='text/plain; charset=utf-8',
        headers=headers
    );
    self.headers.set('Location', quote(url, safe=":/%#?=@[]!$&'()*+,;"));
}

impl FileResponse.init(
    self: FileResponse,
    path: str,
    status_code: int = 200,
    media_type: (str | None) = None,
    filename: (str | None) = None,
    headers: any = None
) {
    guessed = media_type
        or (mimetypes.guess_type(path)[0] or 'application/octet-stream');
    super.init(
        content=b'', status_code=status_code, media_type=guessed, headers=headers
    );
    self.path = path;
    if filename {
        self.headers.set('Content-Disposition', f'attachment; filename="{filename}"');
    }
}

impl FileResponse.body_bytes(self: FileResponse) -> bytes {
    if not os.path.isfile(self.path) {
        self.status_code = 404;
        return b'';
    }
    with open(self.path, 'rb') as fh {
        return fh.read();
    }
}

impl StreamingResponse.init(
    self: StreamingResponse,
    content: any,
    status_code: int = 200,
    media_type: str = 'application/octet-stream',
    headers: any = None
) {
    super.init(
        content=b'', status_code=status_code, media_type=media_type, headers=headers
    );
    self.stream = content;
}

impl parse_query_string(query: str) -> dict[str, list[str]] {
    if not query {
        return {};
    }
    return parse_qs(query, keep_blank_values=True);
}
