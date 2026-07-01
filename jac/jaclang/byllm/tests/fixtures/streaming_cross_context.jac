"""Regression test: a streaming `by llm()` result must be safe to iterate from a
different contextvars.Context than the one that created it.

The scale backend's `sse_frame_stream` drives each `next()` on a thread-pool worker via
`loop.run_in_executor`, i.e. a *foreign* Context. Pre-fix, `Model.invoke`'s
streaming wrapper reset its `byllm_invocation_id` Token in a `finally` that ran
in that foreign Context, raising
`ValueError: <Token ...> was created in a different Context` and killing the
stream.

"""
import asyncio;
import contextvars;
import from jaclang.byllm.lib { Model }
import from jaclang.byllm.telemetry { _current_invocation_id }

glob llm = Model(
         model_name="mockllm",
         config={
             "outputs": [
                 "alpha beta gamma from a copied context",
                 "alpha beta gamma from a worker thread",
             ]
         }
     );

"""Stream a short answer."""
def stream_answer() -> str by llm(stream=True);

# Module-level sentinel so end-of-stream is detected by identity (cleaner than
# sniffing the chunk's type).
glob _STOP = object();

def _next_or_stop(gen: object) -> object {
    try {
        return next(gen);
    } except StopIteration {
        return _STOP;
    }
}

# Path A: consume the whole generator inside a fresh, foreign Context.
def consume_in_copied_context() -> list {
    gen = stream_answer();
    ctx = contextvars.copy_context();
    return ctx.run(list, gen);
}

# Path B: drive each next() on a thread-pool worker — the exact asyncio +
# run_in_executor shape the scale backend's SSE microservice uses.
async def consume_in_thread_pool() -> list {
    gen = stream_answer();
    loop = asyncio.get_event_loop();
    chunks = [];
    while True {
        item = await loop.run_in_executor(None, _next_or_stop, gen);
        if item is _STOP {
            break;
        }
        chunks.append(item);
    }
    return chunks;
}


with entry {
    # Path A — pre-fix this line raises ValueError ("different Context").
    chunks_a = consume_in_copied_context();
    assert chunks_a , "copied-Context iteration produced no chunks";
    assert "copied context" in "".join(chunks_a) , f"missing content: {chunks_a}";

    # Path B — thread-pool executor.
    chunks_b = asyncio.run(consume_in_thread_pool());
    assert chunks_b , "thread-pool iteration produced no chunks";
    assert "worker thread" in "".join(chunks_b) , f"missing content: {chunks_b}";

    # The wrapper must not leak its invocation id into the caller's Context.
    assert _current_invocation_id.get(None) is None , "invocation id leaked into caller Context";

    print("CROSS_CONTEXT_PASS");
}
