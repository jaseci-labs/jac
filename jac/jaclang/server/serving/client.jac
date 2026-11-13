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

    def __str__ -> str;
}

obj ClientRequestNotSent(ClientConnectionError) {}

obj ClientRequestSent(ClientConnectionError) {}

obj ClientReadTimeout(ClientRequestSent) {}

def _client_json_default(o: any) -> str;

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

    def json -> any;
    def text -> str;
    def ok -> bool;
    async def aiter_raw -> AsyncIterator[bytes];
    async def aiter_lines -> AsyncIterator[bytes];
    async def aclose;
}

def _idle_pool -> dict[tuple[str, str, int], list[_PooledConn]];

def _discard(conn: _PooledConn);

def _usable(conn: _PooledConn, now: float) -> bool;

def _take_idle(origin: tuple[str, str, int]) -> (_PooledConn | None);

def _release(conn: _PooledConn);

def _close_idle;

async def _closing_pool(coro: any) -> any;

@cache
def _tls_context -> any;

def _split_url(url: str) -> tuple[str, str, int, str];

async def _open_stream(
    scheme: str, host: str, port: int, timeout: float
) -> tuple[any, any];

async def _connect(origin: tuple[str, str, int], timeout: float) -> _PooledConn;

async def _read_response_head(
    reader: any, timeout: float
) -> tuple[str, int, str, Headers];

async def _exchange(
    conn: _PooledConn, payload: bytes, timeout: float
) -> tuple[str, int, str, Headers];

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
