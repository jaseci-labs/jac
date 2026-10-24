import hashlib;
import mimetypes;
import os;
import from email.utils { formatdate, parsedate_to_datetime }

glob DEFAULT_CACHE_CONTROL: str = 'public, max-age=3600',
     _DIGESTS: dict[str, tuple[tuple[int, int, int], str]] = {};


def guess_media_type(name: str) -> str;


def _etag(path: str, stat: os.stat_result) -> str;


def _not_modified(request: Request, etag: str, mtime: float) -> bool;


def _parse_range(header: str, size: int) -> (tuple[int, int] | None);


def file_response(
    request: Request,
    path: str,
    cache_control: str = DEFAULT_CACHE_CONTROL,
    media_type: (str | None) = None,
    extra_headers: (dict[str, str] | None) = None
) -> Response;
