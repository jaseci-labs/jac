import json;
import asyncio;
import logging;
import from inspect { isgenerator }
import from typing { AsyncIterator, AsyncGenerator }


glob _logger: logging.Logger = logging.getLogger(
         "jac_scale.runtime.middleware.sse"
     ),
     _DEFAULT: any = str,
     _STOP: any = object();


def _next_or_stop(gen: any) -> any {
    try {
        return next(gen);
    } except StopIteration {
        return _STOP;
    }
}


async def sse_frame_stream(gen: any) -> AsyncIterator[str] {
    sync = isgenerator(gen);
    if not sync and not isinstance(gen, AsyncGenerator) {
        raise TypeError(
            f"sse_frame_stream expected a generator or async generator, got {type(
                gen
            ).__name__}"
        );
    }

    try {
        if sync {
            loop = asyncio.get_event_loop();
            while True {
                item = await loop.run_in_executor(None, _next_or_stop, gen);
                if item is _STOP {
                    break;
                }
                yield f"data: {json.dumps(item, default=_DEFAULT)}\n\n";
            }
        } else {
            async for item in gen {
                yield f"data: {json.dumps(item, default=_DEFAULT)}\n\n";
            }
        }

        yield "event: end\ndata: {}\n\n";
    } except Exception as e {
        _logger.exception("sse_frame_stream: producer raised");
        err_payload = {"error_type": type(e).__name__, "message": str(e),};
        yield f"event: error\ndata: {json.dumps(err_payload, default=_DEFAULT)}\n\n";
    } finally {
        try {
            close_fn = gen?.close;
            if close_fn {
                close_fn();
            }
        } except Exception {
            ;
        }
    }
}
