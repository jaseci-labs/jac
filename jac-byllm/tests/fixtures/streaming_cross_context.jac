"""Regression fixture for byllm streaming + cross-Context iteration.

Drives a streaming Model.invoke() result from inside a different
contextvars.Context than the one it was created in, mirroring how
jac-scale's SSE microservice consumes streaming generators via
loop.run_in_executor(None, _next_or_stop, gen).

Pre-fix, the wrapper's finally clause did
_current_invocation_id.reset(token) where the token was bound to the
caller's Context. Iteration from a foreign Context raised
ValueError: Token was created in a different Context. The fix makes
the wrapper carry its own captured Context, so no token-based reset
crosses Context boundaries.

Also exercises iteration from a real thread-pool worker (the exact
asyncio + run_in_executor shape used by jac-scale).
"""
import asyncio;
import contextvars;
import from concurrent.futures { ThreadPoolExecutor }
import from byllm.lib { Model }

glob llm = Model(
         model_name="mockllm",
         config={
             "outputs": [
                 "hello cross context streaming world",
                 "hello cross context streaming world"
             ]
         }
     );

def stream_essay -> str by llm(stream=True);


def _next_or_stop(gen: object) -> object {
    _stop = object();
    try {
        return next(gen);
    } except StopIteration {
        return _stop;
    }
}


async def _drive_in_thread_pool(gen: object) -> list {
    loop = asyncio.get_event_loop();
    chunks = [];
    while True {
        item = await loop.run_in_executor(None, _next_or_stop, gen);
        # _next_or_stop returns its sentinel object on StopIteration; we
        # detect it by type since the sentinel is created per-call.
        if isinstance(item, str) {
            chunks.append(item);
        } else {
            break;
        }
    }
    return chunks;
}


# --- Path 1: iterate from a fresh contextvars.Context ---
glob gen = stream_essay(),
     ctx = contextvars.copy_context(),
     chunks_ctx = ctx.run(list, gen);

with entry {
    assert chunks_ctx , "context-bound iteration produced no chunks";
    assert "hello cross context" in "".join(chunks_ctx);
}

# --- Path 2: iterate from an asyncio + thread-pool executor ---
glob gen2 = stream_essay(),
     chunks_async = asyncio.run(_drive_in_thread_pool(gen2));

with entry {
    assert chunks_async , "thread-pool iteration produced no chunks";
    assert "hello cross context" in "".join(chunks_async);

    print("CROSS_CONTEXT_STREAM_PASS");
}
