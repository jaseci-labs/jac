import mimetypes;
import os;
import from json { dumps, loads }
import from urllib.parse { parse_qs, quote }


obj HTTPError(Exception) {
    has status_code: int,
        detail: str = '';

    def __str__ -> str;
}

obj WebSocketDisconnect(Exception) {
    has code: int = 1000;

    def __str__ -> str;
}

class State {}

obj Headers {
    has raw: list[tuple[str, str]] = [];

    def get(name: str, default_value: (str | None) = None) -> (str | None);
    def getlist(name: str) -> list[str];
    def items -> list[tuple[str, str]];
    def keys -> list[str];
    def set(name: str, value: str);
    def append(name: str, value: str);
    def remove(name: str);
    def add_vary(field: str);
    def __contains__(name: str) -> bool;
    def __getitem__(name: str) -> str;
    def __setitem__(name: str, value: str);
}

obj QueryParams {
    has raw: dict[(str, list[str])] = {};

    def get(name: str, default_value: (str | None) = None) -> (str | None);
    def getlist(name: str) -> list[str];
    def keys -> list[str];
    def items -> list[tuple[str, str]];
    def __contains__(name: str) -> bool;
    def __getitem__(name: str) -> str;
}

obj URL {
    has path: str = '/',
        query: str = '',
        scheme: str = 'http',
        netloc: str = '';

    def full -> str;
}

obj UploadFile {
    has filename: str = '',
        content_type: str = 'application/octet-stream',
        _file: any = None,
        _size: int = 0;

    has size: int { getter; }
    has file: any { getter; }
    has body: bytes { getter; }

    static def from_bytes(filename: str, content_type: str, data: bytes) -> UploadFile;
    async def read(size: int = -1) -> bytes;
    async def seek(offset: int);
    async def close;
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

    async def json -> any;
    def json_sync -> any;
}

def _normalize_headers(headers: any) -> Headers;

def _json_default(o: any) -> str;

class Response {
    def init(
        self: Response,
        content: any = b'',
        status_code: int = 200,
        media_type: str = 'text/plain; charset=utf-8',
        headers: any = None
    );

    def body_bytes(self: Response) -> bytes;

    has body: bytes {
        getter {
            return self.body_bytes();
        }
    }

    def content_type_header(self: Response) -> str;
}

class JSONResponse(Response) {
    def init(
        self: JSONResponse,
        content: any = None,
        status_code: int = 200,
        headers: any = None,
        media_type: str = 'application/json'
    );

    def body_bytes(self: JSONResponse) -> bytes;
}

class HTMLResponse(Response) {
    def init(
        self: HTMLResponse,
        content: any = '',
        status_code: int = 200,
        headers: any = None
    );
}

class RedirectResponse(Response) {
    def init(
        self: RedirectResponse, url: str, status_code: int = 307, headers: any = None
    );
}

class FileResponse(Response) {
    def init(
        self: FileResponse,
        path: str,
        status_code: int = 200,
        media_type: (str | None) = None,
        filename: (str | None) = None,
        headers: any = None
    );

    def body_bytes(self: FileResponse) -> bytes;
}

class StreamingResponse(Response) {
    def init(
        self: StreamingResponse,
        content: any,
        status_code: int = 200,
        media_type: str = 'application/octet-stream',
        headers: any = None
    );

    has body_iterator: any {
        getter {
            return self.stream;
        }
    }
}

def parse_query_string(query: str) -> dict[str, list[str]];
