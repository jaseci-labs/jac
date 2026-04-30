"""HTTP forwarding for the microservice gateway.

`raw_forward` buffers (for the 404-try-next passthrough path).
`stream_forward` returns a ForwardResult the caller can stream
(SSE / chunked) or abort via `cleanup()`. P15.
"""

import logging;
import aiohttp;
import from typing { Any }
import from fastapi.responses { Response, StreamingResponse }

glob _logger = logging.getLogger(__name__),
     _HOP_BY_HOP: set[str] = {"host","transfer-encoding","connection","keep-alive"};


"""Buffered forward. Returns (status, headers, body) or None on transport error."""
async def raw_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> tuple[int, dict[str, str], bytes] | None {
    try {
        async with aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=timeout)
        ) as session {
            async with session.request(
                method=method,
                url=url,
                headers=headers,
                data=body,
                allow_redirects=False
            ) as resp {
                resp_body = await resp.read();
                resp_headers: dict[str, str] = {};
                for (k, v) in resp.headers.items() {
                    if k.lower() not in _HOP_BY_HOP {
                        resp_headers[k] = v;
                    }
                }
                return (resp.status, resp_headers, resp_body);
            }
        }
    } except (aiohttp.ClientError, OSError) as e {
        # Include the exception type because some aiohttp errors
        # (notably ServerDisconnectedError) have an empty __str__,
        # which produces a useless `HTTP forward error: ` log line.
        _logger.error(f"HTTP forward error: {type(e).__name__}: {e}");
        return None;
    }
}


"""Handle for an open upstream response. Caller must call either
`to_response()` or `cleanup()`; otherwise the session leaks a
connection pool slot."""
obj ForwardResult {
    has status: int,
        headers: dict[str, str],
        _session: Any,
        _resp: Any;

    def to_response -> StreamingResponse;
    async def cleanup -> None;
}


impl ForwardResult.to_response -> StreamingResponse {
    resp = self._resp;
    session = self._session;

    async def body_iter {
        try {
            async for chunk in resp.content.iter_chunked(8192) {
                yield chunk;
            }
        } finally {
            try {
                resp.close();
            } except Exception {
                ;
            }
            try {
                await session.close();
            } except Exception {
                ;
            }
        }
    }

    return StreamingResponse(
        body_iter(), status_code=self.status, headers=self.headers
    );
}


impl ForwardResult.cleanup -> None {
    try {
        self._resp.close();
    } except Exception {
        ;
    }
    try {
        await self._session.close();
    } except Exception {
        ;
    }
}


"""Open the upstream request; return None on transport failure so the
caller can emit a 502."""
async def stream_forward(
    method: str, url: str, headers: dict[str, str], body: bytes, timeout: int = 30
) -> ForwardResult | None {
    session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=timeout));
    try {
        resp = await session.request(
            method=method, url=url, headers=headers, data=body, allow_redirects=False
        );
    } except (aiohttp.ClientError, OSError) as e {
        _logger.error(f"HTTP stream-forward error: {e}");
        await session.close();
        return None;
    }

    resp_headers: dict[str, str] = {};
    for (k, v) in resp.headers.items() {
        if k.lower() not in _HOP_BY_HOP {
            resp_headers[k] = v;
        }
    }

    return ForwardResult(
        status=resp.status, headers=resp_headers, _session=session, _resp=resp
    );
}
