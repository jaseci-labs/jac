import mimetypes;
import os;
import from email.utils { formatdate, parsedate_to_datetime }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }

glob DEFAULT_CACHE_CONTROL: str = 'public, max-age=3600';


def guess_media_type(name: str) -> str {
    lowered = name.lower();
    if lowered.endswith('.css') {
        return 'text/css; charset=utf-8';
    }
    if lowered.endswith('.js') or lowered.endswith('.mjs') {
        return 'text/javascript; charset=utf-8';
    }
    if lowered.endswith('.map') {
        return 'application/json';
    }
    if lowered.endswith('.wasm') {
        return 'application/wasm';
    }
    return mimetypes.guess_type(name)[0] or 'application/octet-stream';
}


def _etag(stat: any) -> str {
    return f'W/"{int(stat.st_mtime)}-{stat.st_size}"';
}


def _not_modified(request: Request, etag: str, mtime: float) -> bool {
    inm = request.headers.get('If-None-Match');
    if inm is not None {
        tags = [t.strip() for t in inm.split(',')];
        return '*' in tags or etag in tags;
    }
    ims = request.headers.get('If-Modified-Since');
    if ims is not None {
        try {
            since = parsedate_to_datetime(ims).timestamp();
        } except (TypeError, ValueError) {
            return False;
        }
        return int(mtime) <= int(since);
    }
    return False;
}


def _parse_range(header: str, size: int) -> (tuple[int, int] | None) {
    spec = header.strip();
    if not spec.lower().startswith('bytes=') {
        return None;
    }
    spec = spec[6:];
    if ',' in spec {
        return None;
    }
    (start_text, _, end_text) = spec.partition('-');
    try {
        if start_text == '' {
            length = int(end_text);
            if length <= 0 {
                return None;
            }
            start = max(0, size - length);
            end = size - 1;
        } else {
            start = int(start_text);
            end = int(end_text) if end_text else size - 1;
        }
    } except ValueError {
        return None;
    }
    if start >= size or end < start {
        return None;
    }
    return (start, min(end, size - 1));
}


def file_response(
    request: Request,
    path: str,
    cache_control: str = DEFAULT_CACHE_CONTROL,
    media_type: (str | None) = None,
    extra_headers: (dict[str, str] | None) = None
) -> Response {
    try {
        stat = os.stat(path);
    } except OSError {
        return JSONResponse(
            content={'error': 'Static file not found'}, status_code=404
        );
    }
    etag = _etag(stat);
    last_modified = formatdate(stat.st_mtime, usegmt=True);
    headers: dict[str, str] = {
        'Cache-Control': cache_control,
        'ETag': etag,
        'Last-Modified': last_modified,
        'Accept-Ranges': 'bytes'
    };
    for (k, v) in (extra_headers or {}).items() {
        headers[k] = v;
    }
    mime = media_type or guess_media_type(path);
    if request.method in ('GET', 'HEAD')
        and _not_modified(request, etag, stat.st_mtime) {
        resp = Response(content=b'', status_code=304, media_type=mime, headers=headers);
        return resp;
    }
    size = stat.st_size;
    range_header = request.headers.get('Range');
    if range_header is not None and request.method == 'GET' {
        span = _parse_range(range_header, size);
        if span is None {
            resp = Response(
                content=b'', status_code=416, media_type=mime, headers=headers
            );
            resp.headers.set('Content-Range', f"bytes */{size}");
            return resp;
        }
        (start, end) = span;
        with open(path, 'rb') as fh {
            fh.seek(start);
            chunk = fh.read(end - start + 1);
        }
        resp = Response(
            content=chunk, status_code=206, media_type=mime, headers=headers
        );
        resp.headers.set('Content-Range', f"bytes {start}-{end}/{size}");
        return resp;
    }
    with open(path, 'rb') as fh {
        data = fh.read();
    }
    return Response(content=data, status_code=200, media_type=mime, headers=headers);
}
