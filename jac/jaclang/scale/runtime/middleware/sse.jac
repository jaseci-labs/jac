import json;
import logging;
import from typing { AsyncIterator }
import from jaclang.scale.runtime.middleware.stream_iterate { stream_iterate }


glob _logger: logging.Logger = logging.getLogger(
         "jaclang.scale.runtime.middleware.sse"
     ),
     _DEFAULT: any = str;


async def sse_frame_stream(gen: any) -> AsyncIterator[str] {
    try {
        async for item in stream_iterate(gen) {
            yield f"data: {json.dumps(item, default=_DEFAULT)}\n\n";
        }
        yield "event: end\ndata: {}\n\n";
    } except Exception as e {
        _logger.exception("sse_frame_stream: producer raised");
        err_payload = {"error_type": type(e).__name__, "message": str(e),};
        yield f"event: error\ndata: {json.dumps(err_payload, default=_DEFAULT)}\n\n";
    }
}
