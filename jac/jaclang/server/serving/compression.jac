import gzip;
import inspect;
import zlib;

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


def _quality(token: str) -> float;


def accepts_gzip(headers: Headers) -> bool;


def is_compressible(media_type: str) -> bool;


async def _gzip_stream(source: any, level: int) -> AsyncIterator[bytes];


obj GzipCache {
    has max_bytes: int = 32 * 1024 * 1024,
        entries: dict[tuple[str, int, int, int], bytes] = {},
        total: int = 0;

    def pack(body: bytes, level: int, etag: (str | None)) -> bytes;
}

glob GZIP_CACHE: GzipCache = GzipCache();


obj CompressionPolicy {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;

    def _negotiable(request: Request, response: Response) -> bool;
    def apply(
        request: Request, response: Response, body: (bytes | None)
    ) -> (bytes | None);
}
