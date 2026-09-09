import gzip;
import inspect;
import zlib;
import from jaclang.server.serving.datatypes { Headers, Request, Response }

glob COMPRESSIBLE_TYPES: list[str] = [
         'text/',
         'application/json',
         'text/javascript',
         'application/javascript',
         'application/xml',
         'image/svg+xml',
         'application/wasm',
         'application/manifest+json'
     ],
     GZIP_WBITS: int = 31;


def _quality(token: str) -> float {
    for param in token.split(';')[1:] {
        piece = param.strip().lower();
        if piece.startswith('q=') {
            try {
                return float(piece[2:]);
            } except ValueError {
                return 0.0;
            }
        }
    }
    return 1.0;
}


def accepts_gzip(headers: Headers) -> bool {
    for raw in headers.getlist('Accept-Encoding') {
        for token in str(raw).split(',') {
            name = token.split(';')[0].strip().lower();
            if name in ('gzip', '*') {
                return _quality(token) > 0.0;
            }
        }
    }
    return False;
}


def is_compressible(media_type: str) -> bool {
    mt = (media_type or '').split(';')[0].strip().lower();
    if not mt {
        return False;
    }
    for candidate in COMPRESSIBLE_TYPES {
        if candidate.endswith('/') {
            if mt.startswith(candidate) {
                return True;
            }
        } elif mt == candidate {
            return True;
        }
    }
    return False;
}


def _append_vary(headers: Headers) {
    existing = [
        v.strip() for raw in headers.getlist('Vary')
        for v in str(raw).split(',')
        if v.strip()
    ];
    if any(v.lower() == 'accept-encoding' for v in existing) {
        return;
    }
    if existing {
        headers.set('Vary', ', '.join(existing + ['Accept-Encoding']));
    } else {
        headers.append('Vary', 'Accept-Encoding');
    }
}


async def _gzip_stream(source: any, level: int) -> AsyncIterator[bytes] {
    comp = zlib.compressobj(level, zlib.DEFLATED, GZIP_WBITS);
    if inspect.isasyncgen(source) or hasattr(source, '__aiter__') {
        async for chunk in source {
            data = chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
            if not data {
                continue;
            }
            out = comp.compress(data) + comp.flush(zlib.Z_SYNC_FLUSH);
            if out {
                yield out;
            }
        }
    } else {
        for chunk in source {
            data = chunk if isinstance(chunk, bytes) else str(chunk).encode('utf-8');
            if not data {
                continue;
            }
            out = comp.compress(data) + comp.flush(zlib.Z_SYNC_FLUSH);
            if out {
                yield out;
            }
        }
    }
    tail = comp.flush(zlib.Z_FINISH);
    if tail {
        yield tail;
    }
}


obj CompressionPolicy {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;

    def _negotiable(request: Request, response: Response) -> bool {
        if not self.enabled or request.method == 'HEAD' {
            return False;
        }
        if response.status_code in (204, 304) or response.status_code < 200 {
            return False;
        }
        if response.headers.get('Content-Encoding') is not None {
            return False;
        }
        cache_control = (response.headers.get('Cache-Control') or '').lower();
        if 'no-transform' in cache_control {
            return False;
        }
        media = response.headers.get('Content-Type') or response.content_type_header();
        return is_compressible(media);
    }

    def apply(
        request: Request, response: Response, body: (bytes | None)
    ) -> (bytes | None) {
        if not self._negotiable(request, response) {
            return body;
        }
        _append_vary(response.headers);
        if not accepts_gzip(request.headers) {
            return body;
        }
        if response.stream is not None {
            response.stream = _gzip_stream(response.stream, self.level);
            response.headers.remove('Content-Length');
            response.headers.set('Content-Encoding', 'gzip');
            return None;
        }
        if body is None or len(body) < self.min_bytes {
            return body;
        }
        packed = gzip.compress(body, compresslevel=self.level, mtime=0);
        response.headers.remove('Content-Length');
        response.headers.set('Content-Encoding', 'gzip');
        return packed;
    }
}
