import from socket { create_connection }
import from ssl { create_default_context, SSLError }
import from http.client { HTTPResponse }
import from urllib.error { HTTPError, URLError }


obj:pub Request {
    has url: str,
        data: bytes = b"",
        headers: dict[str, str] = {},
        method: str = "GET";

    def postinit;
}


obj _Url {
    has scheme: str,
        host: str,
        port: int,
        path: str;
}


def _parse_url(u: str) -> _Url;


def _request_bytes(host: str, path: str, request: Request) -> bytes;


def _fetch_raw(pu: _Url, request: Request, timeout: (float | None)) -> bytes;


def _find_header_end(raw: bytes) -> int;


def _parse_response(raw: bytes, url: str) -> HTTPResponse;


def _resolve_redirect(pu: _Url, loc: str) -> str;
def _urlopen_request(request: Request, timeout: (float | None)) -> HTTPResponse;


def:pub urlopen(
    url: (str | Request), data: (bytes | None) = None, timeout: (float | None) = None
) -> HTTPResponse;
