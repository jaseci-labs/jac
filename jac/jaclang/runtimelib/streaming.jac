import asyncio;
import contextvars;
import json;
import from collections.abc { AsyncGenerator, Generator }
import from inspect { isgenerator }


def context_bound_stream(
    source: Generator, captured: contextvars.Context, teardown: Callable[[], None]
) -> Generator {
    try {
        while True {
            try {
                item = captured.run(next, source);
            } except StopIteration {
                break;
            }
            yield item;
        }
    } finally {
        captured.run(teardown);
    }
}


async def _anext_value(source: AsyncGenerator) -> any {
    return await source.__anext__();
}


async def _aclose_value(source: AsyncGenerator) {
    await source.aclose();
}


async def context_bound_async_stream(
    source: AsyncGenerator, captured: contextvars.Context, teardown: Callable[[], None]
) -> any {
    try {
        while True {
            loop = asyncio.get_running_loop();

            step = loop.create_task(_anext_value(source), context=captured);
            try {
                item = await step;
            } except StopAsyncIteration {
                break;
            }
            yield item;
        }
    } finally {
        try {
            closer = asyncio.get_running_loop().create_task(
                _aclose_value(source), context=captured
            );
            await closer;
        } except Exception {
            ;
        }
        captured.run(teardown);
    }
}


def iter_sync_or_async(gen: any) -> Generator {
    if isgenerator(gen) {
        try {
            for item in gen {
                yield item;
            }
        } finally {
            try {
                gen.close();
            } except Exception {
                ;
            }
        }
    } elif isinstance(gen, AsyncGenerator) {
        loop = asyncio.new_event_loop();
        try {
            while True {
                try {
                    item = loop.run_until_complete(gen.__anext__());
                } except StopAsyncIteration {
                    break;
                }
                yield item;
            }
        } finally {
            try {
                loop.run_until_complete(gen.aclose());
            } except Exception {
                ;
            }
            loop.close();
        }
    } else {
        raise TypeError(
            f"expected a generator or async generator, got {type(gen).__name__}"
        );
    }
}


def _sse_default(v: any) -> str {
    return str(v);
}


def _sse_data_frame(item: any) -> str {
    return f"data: {json.dumps(item, `default=_sse_default)}\n\n";
}


def iter_sse_frames(gen: any) -> Generator[str] {
    try {
        items = iter_sync_or_async(gen);
    } except TypeError {
        err = {
            "error_type": "TypeError",
            "message": f"sse expected a generator, got {type(gen).__name__}"
        };
        yield f"event: error\ndata: {json.dumps(err, `default=_sse_default)}\n\n";
        return;
    }
    try {
        for item in items {
            yield _sse_data_frame(item);
        }
        yield "event: end\ndata: {}\n\n";
    } except Exception as e {
        err = {"error_type": type(e).__name__, "message": str(e)};
        yield f"event: error\ndata: {json.dumps(err, `default=_sse_default)}\n\n";
    } finally {
        try {
            items.close();
        } except Exception {
            ;
        }
        close_fn = gen?.close;
        if close_fn {
            try {
                close_fn();
            } except Exception {
                ;
            }
        }
    }
}


def drain_sse(gen: any, write: Callable[[bytes], None]) {
    frames = iter_sse_frames(gen);
    try {
        for frame in frames {
            write(frame.encode());
        }
    } except (BrokenPipeError, ConnectionResetError, OSError) {
        ;
    } finally {
        try {
            frames.close();
        } except Exception {
            ;
        }
    }
}
