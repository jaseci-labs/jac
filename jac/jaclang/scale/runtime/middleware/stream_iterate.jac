import asyncio;
import logging;
import from inspect { isgenerator }
import from typing { AsyncGenerator, AsyncIterator }

glob _logger: logging.Logger = logging.getLogger(
         "jaclang.scale.runtime.middleware.stream_iterate"
     ),
     _STREAM_STOP: any = object();


def _next_or_stop(gen: any) -> any {
    try {
        return next(gen);
    } except StopIteration {
        return _STREAM_STOP;
    }
}


"""Yield items from a sync or async generator.

Synchronous generators are advanced in a worker thread so a slow step does not
block the event loop. The generator is always closed in a ``finally`` block.
Callers handle protocol-specific termination and error framing."""
async def stream_iterate(gen: any) -> AsyncIterator[any] {
    sync = isgenerator(gen);
    if not sync and not isinstance(gen, AsyncGenerator) {
        raise TypeError(
            f"stream_iterate expected a generator or async generator, got {type(
                gen
            ).__name__}"
        );
    }
    try {
        if sync {
            loop = asyncio.get_running_loop();
            while True {
                item = await loop.run_in_executor(None, _next_or_stop, gen);
                if item is _STREAM_STOP {
                    break;
                }
                yield item;
            }
        } else {
            async for item in gen {
                yield item;
            }
        }
    } finally {
        try {
            close_fn = gen?.close;
            if close_fn {
                close_fn();
            }
        } except Exception {
            _logger.debug("stream_iterate: generator close failed", exc_info=True);
        }
    }
}
