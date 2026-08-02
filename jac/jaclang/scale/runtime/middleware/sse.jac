import asyncio;
import json;
import logging;
import from collections.abc { AsyncIterator }
import from jaclang.runtimelib.streaming { iter_sse_frames }


glob _logger: logging.Logger = logging.getLogger(
         "jaclang.scale.runtime.middleware.sse"
     ),
     _STOP: any = object();


def _next_or_stop(gen: any) -> any {
    try {
        return next(gen);
    } except StopIteration {
        return _STOP;
    }
}


async def sse_frame_stream(gen: any) -> AsyncIterator[str] {
    loop = asyncio.get_event_loop();
    frames = iter_sse_frames(gen);
    try {
        while True {
            frame = await loop.run_in_executor(None, _next_or_stop, frames);
            if frame is _STOP {
                break;
            }
            yield frame;
        }
    } except Exception as e {
        _logger.exception("sse_frame_stream: producer raised");
        err_payload = {"error_type": type(e).__name__, "message": str(e),};
        yield f"event: error\ndata: {json.dumps(err_payload, default=str)}\n\n";
    }
}
