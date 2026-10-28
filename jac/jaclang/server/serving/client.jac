import asyncio;
import os;
import ssl as ssl_lib;
import threading;
import queue as queue_lib;
import from base64 { b64encode }
import from concurrent.futures { ThreadPoolExecutor }
import from json { dumps, loads }
import from urllib.parse { urlencode, urlsplit }


glob DEFAULT_TIMEOUT: float = 30.0;


obj ClientConnectionError(Exception) {
    has detail: str = 'connection failed',
        status_code: (int | None) = None,
        response: any = None;

    def __str__ -> str;
}

obj ClientRequestNotSent(ClientConnectionError) {}

obj ClientRequestSent(ClientConnectionError) {}

obj ClientReadTimeout(ClientRequestSent) {}

def _client_json_default(o: any) -> str;

obj ClientResponse {
    has status_code: int = 0,
        reason: str = '',
        headers: Headers = Headers(),
        body: bytes = b'',
        reader: any = None,
        writer: any = None,
        chunked: bool = False;

    def json -> any;
    def text -> str;
    def ok -> bool;
    async def aiter_raw -> AsyncIterator[bytes];
    async def aiter_lines -> AsyncIterator[bytes];
    async def aclose;
}

def _split_url(url: str) -> tuple[str, str, int, str];

async def _open_stream(
    scheme: str, host: str, port: int, timeout: float
) -> tuple[any, any];

async def _read_response_head(reader: any, timeout: float) -> tuple[int, str, Headers];

async def arequest(
    method: str,
    url: str,
    headers: (dict[str, any] | None) = None,
    json_body: any = None,
    data: (bytes | str | None) = None,
    timeout: float = DEFAULT_TIMEOUT,
    stream: bool = False,
    params: (dict[str, any] | None) = None
) -> ClientResponse;

async def aws_connect(
    url: str, headers: (dict[str, any] | None) = None, timeout: float = DEFAULT_TIMEOUT
) -> WebSocket;

def run_blocking(coro: any) -> any;

def request_sync(
    method: str,
    url: str,
    headers: (dict[str, any] | None) = None,
    json_body: any = None,
    data: (bytes | str | None) = None,
    timeout: float = DEFAULT_TIMEOUT
) -> ClientResponse;

def post_stream_aware_sync(
    url: str,
    json_body: any = None,
    headers: (dict[str, any] | None) = None,
    timeout: float = DEFAULT_TIMEOUT,
    label: str = 'rpc'
) -> tuple[str, any];
