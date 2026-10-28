import from socket { create_connection }
import from ssl { create_default_context }


obj _Url {
    has scheme: str,
        host: str,
        port: int,
        path: str;
}


def _parse_url(u: str) -> _Url;


def _request_text(host: str, path: str) -> str;


def _fetch_raw(pu: _Url) -> bytes;


def _find_header_end(raw: bytes) -> int;


def _parse_response(raw: bytes, url: str) -> HTTPResponse;


def _resolve_redirect(pu: _Url, loc: str) -> str;


def:pub urlopen(url: str) -> HTTPResponse;
