"""SSE framing for generator-returning RPC functions.

The serve.endpoints layer detects an iterator return value and wraps
it in a StreamingResponse with `media_type='text/event-stream'`. But
StarletteResponse just iterates the body and writes each yield to the
wire — which for a generator of dicts produces the dict's repr, not
valid SSE. Browsers (and our `sv_service_call` SSE consumer) expect
the canonical:

    data: {json}\n\n

framing per WHATWG-EventSource. This module exposes one helper that
takes the user's iterator and rewraps it so each yield becomes a
correctly-framed `data: ...\n\n` chunk, plus a terminating
`event: end` sentinel so the consumer knows it's a normal close (not
a connection drop).

Errors raised inside the user's generator are caught and emitted as
`event: error\ndata: {json}\n\n` so the consumer can surface a
structured error instead of a partial-stream EOF.

Sync iterators are awaited via `asyncio.to_thread` so a blocking
`q.get()` (the common pattern for cross-thread event queues — see
jac-coder's stream_events) does not pin the event loop.
"""

import json;
import asyncio;
import logging;
import from inspect { isgenerator }
import from typing { Any, AsyncIterator, AsyncGenerator }


glob _logger: logging.Logger = logging.getLogger("jac_scale.microservices.sse"),
     # Use the str() builtin as the json.dumps default so types like UUID,
     # datetime, etc. that the user's events may contain become string
     # representations instead of raising. Hoisted to module scope so we
     # don't re-bind it on every yield.
     _DEFAULT: Any = str,
     # Sentinel used to detect end-of-stream from the worker-thread side
     # (asyncio.to_thread can't propagate StopIteration cleanly).
     _STOP: Any = object();


"""Drive `next(gen)` on a worker thread; return _STOP at end-of-stream.

Hoisted out of sse_frame_stream because Jac doesn't support nested
defs. Used only by the sync-generator branch.
"""
def _next_or_stop(gen: Any) -> Any {
    try {
        return next(gen);
    } except StopIteration {
        return _STOP;
    }
}


"""Wrap a sync or async generator so each yield is emitted as a
properly framed SSE chunk.

Returns an AsyncIterator suitable for handing to
`StreamingResponse(..., media_type='text/event-stream')`.

Exception semantics: a raised exception inside the wrapped generator
is converted to an `event: error` SSE chunk so the consumer can
distinguish a graceful end-of-stream (`event: end`) from a producer-
side failure. The exception is also logged.
"""
async def sse_frame_stream(gen: Any) -> AsyncIterator[str] {
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
            # Drive the sync generator on the default executor so a blocking
            # next() — e.g. queue.get(timeout=...) inside the producer —
            # does not stall the event loop. `loop.run_in_executor` returns
            # a Future awaitable that Jac's stdlib stubs recognise (whereas
            # asyncio.to_thread's TypeVar return is opaque to the checker).
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
        # Normal close — explicit so the consumer can tell EOF apart
        # from a dropped connection.
        yield "event: end\ndata: {}\n\n";
    } except Exception as e {
        _logger.exception("sse_frame_stream: producer raised");
        err_payload = {"error_type": type(e).__name__, "message": str(e),};
        yield f"event: error\ndata: {json.dumps(err_payload, default=_DEFAULT)}\n\n";
    } finally {
        # Best-effort cleanup so a long-running queue producer can drop its
        # state when the consumer disconnects mid-stream.
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
