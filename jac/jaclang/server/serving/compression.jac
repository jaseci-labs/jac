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


obj CompressionPolicy {
    has enabled: bool = True,
        min_bytes: int = 1024,
        level: int = 4;

    def _negotiable(request: Request, response: Response) -> bool;
    def apply(
        request: Request, response: Response, body: (bytes | None)
    ) -> (bytes | None);
}
