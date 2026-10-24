import logging;

glob _logger = logging.getLogger(__name__),
     _HOP_BY_HOP: set[str] = {
         "host",
         "transfer-encoding",
         "connection",
         "keep-alive",
         "content-length"
     };


def _filtered_headers(resp: any) -> dict[str, str];

async def raw_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> tuple[int, dict[str, str], bytes] | None;


obj ForwardResult {
    has status: int,
        headers: dict[str, str],
        _resp: any;

    def to_response -> StreamingResponse;
    async def cleanup -> None;
}


impl ForwardResult.to_response -> StreamingResponse {
    resp = self._resp;

    async def body_iter {
        try {
            async for chunk in resp.aiter_raw() {
                yield chunk;
            }
        } finally {
            await resp.aclose();
        }
    }

    return StreamingResponse(
        body_iter(), status_code=self.status, headers=self.headers
    );
}


impl ForwardResult.cleanup -> None {
    await self._resp.aclose();
}


async def stream_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> ForwardResult | None;
