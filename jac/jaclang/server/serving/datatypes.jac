import mimetypes;
import os;
import from json { dumps, loads }
import from urllib.parse { parse_qs, quote }


obj HTTPError(Exception) {
    has status_code: int,
        detail: str = '';

    def __str__ -> str {
        return self.detail or f"HTTP {self.status_code}";
    }
}

obj WebSocketDisconnect(Exception) {
    has code: int = 1000;

    def __str__ -> str {
        return f"WebSocket disconnected: {self.code}";
    }
}

class State {}

obj Headers {
    has raw: list[tuple[str, str]] = [];

    def get(name: str, default_value: (str | None) = None) -> (str | None) {
        low = name.lower();
        for (k, v) in self.raw {
            if k.lower() == low {
                return v;
            }
        }
        return default_value;
    }

    def getlist(name: str) -> list[str] {
        low = name.lower();
        return [
            v
            for (k, v) in self.raw
            if k.lower() == low
        ];
    }

    def items -> list[tuple[str, str]] {
        return list(self.raw);
    }

    def keys -> list[str] {
        return [k for (k, v) in self.raw];
    }

    def set(name: str, value: str) {
        low = name.lower();
        self.raw = [
            (k, v)
            for (k, v) in self.raw
            if k.lower() != low
        ];
        self.raw.append((name, value));
    }

    def append(name: str, value: str) {
        self.raw.append((name, value));
    }

    def remove(name: str) {
        low = name.lower();
        self.raw = [
            (k, v)
            for (k, v) in self.raw
            if k.lower() != low
        ];
    }

    def __contains__(name: str) -> bool {
        return self.get(name) is not None;
    }

    def __getitem__(name: str) -> str {
        found = self.get(name);
        if found is None {
            raise KeyError(name);
        }
        return found;
    }

    def __setitem__(name: str, value: str) {
        self.set(name, value);
    }
}

obj QueryParams {
    has raw: dict[(str, list[str])] = {};

    def get(name: str, default_value: (str | None) = None) -> (str | None) {
        values = self.raw.get(name);
        return values[0] if values else default_value;
    }

    def getlist(name: str) -> list[str] {
        return list(self.raw.get(name, []));
    }

    def keys -> list[str] {
        return list(self.raw.keys());
    }

    def items -> list[tuple[str, str]] {
        return [
            (k, v[0])
            for (k, v) in self.raw.items()
            if v
        ];
    }

    def __contains__(name: str) -> bool {
        return name in self.raw;
    }

    def __getitem__(name: str) -> str {
        found = self.get(name);
        if found is None {
            raise KeyError(name);
        }
        return found;
    }
}

obj URL {
    has path: str = '/',
        query: str = '',
        scheme: str = 'http',
        netloc: str = '';

    def full -> str {
        base = f"{self.scheme}://{self.netloc}" if self.netloc else '';
        qs = f"?{self.query}" if self.query else '';
        return f"{base}{self.path}{qs}";
    }
}

obj UploadFile {
    has filename: str = '',
        content_type: str = 'application/octet-stream',
        _file: any = None,
        _size: int = 0;

    has size: int { getter; }
    has file: any { getter; }
    has body: bytes { getter; }

    static def from_bytes(filename: str, content_type: str, data: bytes) -> UploadFile {
        import io;
        return UploadFile(
            filename=filename,
            content_type=content_type,
            _file=io.BytesIO(data),
            _size=len(data)
        );
    }

    async def read(size: int = -1) -> bytes {
        return self.file.read(size);
    }

    async def seek(offset: int) {
        self.file.seek(offset);
    }

    async def close {
        self.file.close();
    }
}

impl UploadFile.size.getter -> int {
    return self._size;
}

impl UploadFile.file.getter -> any {
    if self._file is None {
        import io;
        self._file = io.BytesIO(b'');
    }
    return self._file;
}

impl UploadFile.body.getter -> bytes {
    handle = self.file;
    try {
        here = handle.tell();
    } except Exception {
        here = 0;
    }
    handle.seek(0);
    data = handle.read();
    handle.seek(here);
    return data;
}

obj Request {
    has method: str = 'GET',
        url: URL = URL(),
        headers: Headers = Headers(),
        query_params: QueryParams = QueryParams(),
        path_params: dict[(str, str)] = {},
        body: bytes = b'',
        body_file: any = None,
        state: State = State(),
        client_host: str = '',
        http_version: str = 'HTTP/1.1',
        request_id: str = '',
        form_fields: dict[(str, list[str])] = {},
        upload_files: dict[(str, list[UploadFile])] = {};

    async def json -> any {
        return self.json_sync();
    }

    def json_sync -> any {
        if not self.body {
            return None;
        }
        return loads(self.body);
    }
}

def _normalize_headers(headers: any) -> Headers {
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

def _json_default(o: any) -> str {
    return str(o);
}

class Response {
    def init(
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

    def body_bytes(self: Response) -> bytes {
        if isinstance(self.content, bytes) {
            return self.content;
        }
        if self.content is None {
            return b'';
        }
        return str(self.content).encode('utf-8');
    }

    has body: bytes {
        getter {
            return self.body_bytes();
        }
    }

    def content_type_header(self: Response) -> str {
        mt = self.media_type;
        if mt.startswith('text/') and 'charset=' not in mt {
            return f"{mt}; charset=utf-8";
        }
        return mt;
    }
}

class JSONResponse(Response) {
    def init(
        self: JSONResponse,
        content: any = None,
        status_code: int = 200,
        headers: any = None,
        media_type: str = 'application/json'
    ) {
        super.init(
            content=content,
            status_code=status_code,
            media_type=media_type,
            headers=headers
        );
    }

    def body_bytes(self: JSONResponse) -> bytes {
        return dumps(self.content, `default=_json_default).encode('utf-8');
    }
}

class HTMLResponse(Response) {
    def init(
        self: HTMLResponse,
        content: any = '',
        status_code: int = 200,
        headers: any = None
    ) {
        super.init(
            content=content,
            status_code=status_code,
            media_type='text/html; charset=utf-8',
            headers=headers
        );
    }
}

class RedirectResponse(Response) {
    def init(
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
}

class FileResponse(Response) {
    def init(
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
            self.headers.set(
                'Content-Disposition', f'attachment; filename="{filename}"'
            );
        }
    }

    def body_bytes(self: FileResponse) -> bytes {
        if not os.path.isfile(self.path) {
            self.status_code = 404;
            return b'';
        }
        with open(self.path, 'rb') as fh {
            return fh.read();
        }
    }
}

class StreamingResponse(Response) {
    def init(
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

    has body_iterator: any {
        getter {
            return self.stream;
        }
    }
}

def parse_query_string(query: str) -> dict[str, list[str]] {
    if not query {
        return {};
    }
    return parse_qs(query, keep_blank_values=True);
}
