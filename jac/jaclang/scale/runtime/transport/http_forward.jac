import logging;
import from jaclang.runtimelib.serving.client { ClientConnectionError, arequest }
import from jaclang.runtimelib.serving.datatypes { Response, StreamingResponse }

glob _logger = logging.getLogger(__name__),
     _HOP_BY_HOP: set[str] = {
         "host",
         "transfer-encoding",
         "connection",
         "keep-alive",
         "content-length",
         "te",
         "trailer",
         "upgrade",
         "proxy-authenticate",
         "proxy-authorization"
     },
     _DRAINABLE_BYTES: int = 65536;


def _is_drainable(resp: any) -> bool {
    length = resp.headers.get("Content-Length");
    try {
        return length is not None and int(length) <= _DRAINABLE_BYTES;
    } except ValueError {
        return False;
    }
}

def _filtered_headers(resp: any) -> dict[str, str] {
    resp_headers: dict[str, str] = {};
    for (k, v) in resp.headers.items() {
        if str(k).lower() not in _HOP_BY_HOP {
            resp_headers[str(k)] = str(v);
        }
    }
    return resp_headers;
}

async def raw_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> tuple[int, dict[str, str], bytes] | None {
    try {
        resp = await arequest(
            method, url, headers=headers, data=body, timeout=float(timeout)
        );
    } except (ClientConnectionError, OSError) as e {
        _logger.error(f"HTTP forward error: {type(e).__name__}: {e}");
        return None;
    }
    return (resp.status_code, _filtered_headers(resp), resp.body);
}


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
    if _is_drainable(self._resp) {
        try {
            async for _chunk in self._resp.aiter_raw() {
                ;
            }
        } except Exception {
            ;
        }
    }
    await self._resp.aclose();
}


async def stream_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> ForwardResult | None {
    try {
        resp = await arequest(
            method, url, headers=headers, data=body, timeout=float(timeout), stream=True
        );
    } except (ClientConnectionError, OSError) as e {
        _logger.error(f"HTTP stream-forward error: {e}");
        return None;
    }
    return ForwardResult(
        status=resp.status_code, headers=_filtered_headers(resp), _resp=resp
    );
}
