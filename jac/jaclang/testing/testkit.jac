import asyncio;
import secrets;
import threading;
import from json { dumps, loads }
import from urllib.parse { urlencode }


def _test_json_default(o: any) -> str;

obj TestResponse {
    has status_code: int = 200,
        headers: Headers = Headers(),
        content: bytes = b'';

    has text: str { getter; }
    has ok: bool { getter; }

    def json -> any;
}

impl TestResponse.text.getter -> str {
    return self.content.decode('utf-8', errors='replace');
}

impl TestResponse.ok.getter -> bool {
    return 200 <= self.status_code < 300;
}

obj SyncWebSocket {
    has url: str = '',
        extra_headers: dict[str, str] = {},
        _loop: any = None,
        _thread: any = None,
        _ws: any = None;

    def _ensure_loop;
    def _run(coro: any) -> any;
    def connect;
    def send_json(data: any);
    def send_text(text: str);
    def send_bytes(data: bytes);
    def receive_json -> any;
    def receive_text -> str;
    def receive -> dict[str, any];
    def close(code: int = 1000);
    def __enter__ -> SyncWebSocket;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}

obj ServingTestClient {
    has app: ServingApp,
        base_headers: dict[str, str] = {},
        raise_server_exceptions: bool = False,
        follow_redirects: bool = True,
        _server: any = None,
        _stop_server: any = None;

    def request(
        method: str,
        path: str,
        json: any = None,
        data: any = None,
        content: any = None,
        files: (dict[str, any] | list[tuple[str, any]] | None) = None,
        params: (dict[str, any] | None) = None,
        headers: (dict[str, any] | None) = None,
        follow_redirects: (bool | None) = None
    ) -> TestResponse;

    async def _dispatch_chain(
        request: Request, follow_redirects: bool
    ) -> tuple[Response, bytes];

    def get(path: str, **kwargs: any) -> TestResponse;
    def post(path: str, **kwargs: any) -> TestResponse;
    def put(path: str, **kwargs: any) -> TestResponse;
    def patch(path: str, **kwargs: any) -> TestResponse;
    def delete(path: str, **kwargs: any) -> TestResponse;
    def options(path: str, **kwargs: any) -> TestResponse;
    def head(path: str, **kwargs: any) -> TestResponse;
    def _ensure_live_server -> int;
    def websocket_connect(
        path: str, headers: (dict[str, any] | None) = None
    ) -> SyncWebSocket;

    def close;
}

async def collect_response_stream(response: any) -> bytes;

async def dispatch_and_collect(app: any, request: any) -> tuple[any, bytes];

def _build_multipart(files: any, data: any = None) -> tuple[bytes, str];
