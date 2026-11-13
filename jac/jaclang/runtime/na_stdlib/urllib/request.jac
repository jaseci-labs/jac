import from socket { create_connection, socket as Socket }
import from ssl { create_default_context, SSLError, SSLSocket }
import from http.client { HTTPHeaders, HTTPResponse }
import from urllib.error { HTTPError, URLError }


obj:pub Request {
    has url: str,
        data: bytes = b"",
        headers: dict[str, str] = {},
        method: (str | None) = None;
}


obj _Url {
    has scheme: str,
        host: str,
        port: int,
        path: str;
}


def _parse_url(u: str) -> _Url;


def _request_bytes(host: str, path: str, request: Request) -> bytes;


def _request_method(request: Request) -> str;


def _replace_content_length(headers: dict[str, str]) -> dict[str, str];


def _fetch_raw(pu: _Url, request: Request, timeout: (float | None)) -> bytes;


def _find_header_end(raw: bytes) -> int;


def _parse_response(raw: bytes, url: str) -> HTTPResponse;


def _resolve_redirect(pu: _Url, loc: str) -> str;
def _urlopen_request(request: Request, timeout: (float | None)) -> HTTPResponse;


def:pub urlopen(
    url: (str | Request), data: (bytes | None) = None, timeout: (float | None) = None
) -> HTTPResponse;
