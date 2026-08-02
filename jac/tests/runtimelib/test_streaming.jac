"""Unit tests for `runtimelib.streaming.context_bound_stream`.

This is the primitive behind transport-agnostic streaming context lifetime: a
generator returned by a walker/function must be safe to drain from a *foreign*
contextvars.Context (an SSE thread-pool worker, the native push pump) yet still
resolve the request-scoped ContextVars its yield frames read, and run its
teardown (commit) exactly once when the stream ends. These tests exercise the
wrapper directly with a sentinel ContextVar -- no ExecutionContext needed -- so
they FAIL for a naive `return raw_gen` (which does not bind the context) and
pass only when every step and the teardown run inside the captured snapshot.
"""

import asyncio;
import contextvars;
import from jaclang.runtimelib.streaming {
    context_bound_stream,
    context_bound_async_stream,
    iter_sync_or_async,
    drain_sse
}


async def _drain(stream: any) -> list {
    out: list = [];
    async for x in stream {
        out.append(x);
    }
    return out;
}

glob _probe: contextvars.ContextVar = contextvars.ContextVar(
         "_probe", default="unset"
     );


# Each step must run inside the captured Context: the source generator reads a
# ContextVar that is set ONLY in the captured snapshot, while the wrapper itself
# is consumed from the default (foreign) Context where the var is still "unset".
test "generator steps run inside the captured context" {
    def _source {
        for _i in range(3) {
            yield _probe.get();
        }
    }

    captured = contextvars.copy_context();
    captured.run(_probe.set, "request-scope");

    torn: list = [];
    def _teardown {
        torn.append(_probe.get());
    }

    # Consume from the default Context -- `_probe` here is still "unset".
    assert _probe.get() == "unset";
    stream = context_bound_stream(_source(), captured, _teardown);
    items = list(stream);

    # Every yielded value was read inside the captured snapshot, not the caller's.
    assert items == ["request-scope", "request-scope", "request-scope"] , items;
    # Teardown ran once, also inside the captured snapshot.
    assert torn == ["request-scope"] , torn;
    # The wrapper never leaked the captured binding into the caller's Context.
    assert _probe.get() == "unset";
}


# Natural exhaustion runs teardown exactly once.
test "teardown runs exactly once on normal completion" {
    def _source {
        yield 1;
        yield 2;
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    out = list(context_bound_stream(_source(), captured, _teardown));
    assert out == [1, 2];
    assert len(calls) == 1;
    # Closing an already-exhausted wrapper does not re-run teardown.
    calls.clear();
}


# A consumer that goes away mid-stream (`close()`) still runs teardown once, so
# the request's writes commit even on early disconnect.
test "teardown runs once when the consumer closes mid-stream" {
    def _source {
        i = 0;
        while True {
            yield i;
            i += 1;
        }
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    stream = context_bound_stream(_source(), captured, _teardown);
    assert next(stream) == 0;
    assert next(stream) == 1;
    stream.close();
    assert len(calls) == 1 , "teardown must run exactly once on close";
    # Idempotent: a second close is a no-op.
    stream.close();
    assert len(calls) == 1;
}


# An exception raised inside a yield frame propagates to the consumer AND runs
# teardown exactly once (the request context is still torn down).
test "teardown runs once when the source raises" {
    def _source {
        yield 1;
        raise ValueError("boom in yield frame");
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    stream = context_bound_stream(_source(), captured, _teardown);
    assert next(stream) == 1;
    raised = False;
    try {
        next(stream);
    } except ValueError {
        raised = True;
    }
    assert raised , "the source exception must surface to the consumer";
    assert len(calls) == 1 , "teardown must run exactly once even on error";
}


# --- Async-generator wrapper (Phase 3) ---------------------------------------

# The async analogue of the discriminator: each `__anext__` step must run inside
# the captured Context, even though the wrapper is drained from the default
# (foreign) Context where the sentinel is still "unset".
test "async generator steps run inside the captured context" {
    async def _source {
        for _i in range(3) {
            yield _probe.get();
        }
    }

    captured = contextvars.copy_context();
    captured.run(_probe.set, "request-scope");

    torn: list = [];
    def _teardown {
        torn.append(_probe.get());
    }

    assert _probe.get() == "unset";
    stream = context_bound_async_stream(_source(), captured, _teardown);
    loop = asyncio.new_event_loop();
    try {
        items = loop.run_until_complete(_drain(stream));
    } finally {
        loop.close();
    }

    assert items == ["request-scope", "request-scope", "request-scope"] , items;
    assert torn == ["request-scope"] , torn;
    assert _probe.get() == "unset";
}


# Natural exhaustion runs teardown exactly once.
test "async teardown runs exactly once on normal completion" {
    async def _source {
        yield 1;
        yield 2;
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    stream = context_bound_async_stream(_source(), captured, _teardown);
    loop = asyncio.new_event_loop();
    try {
        out = loop.run_until_complete(_drain(stream));
    } finally {
        loop.close();
    }
    assert out == [1, 2];
    assert len(calls) == 1;
}


# A consumer that stops draining and `aclose()`s mid-stream still runs teardown
# exactly once, so the request's writes commit even on early disconnect.
test "async teardown runs once when the consumer aclose()s mid-stream" {
    async def _source {
        i = 0;
        while True {
            yield i;
            i += 1;
        }
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    stream = context_bound_async_stream(_source(), captured, _teardown);

    async def _step_then_close {
        a = await stream.__anext__();
        b = await stream.__anext__();
        assert a == 0 and b == 1;
        await stream.aclose();
        # Idempotent: a second aclose is a no-op.
        await stream.aclose();
    }

    loop = asyncio.new_event_loop();
    try {
        loop.run_until_complete(_step_then_close());
    } finally {
        loop.close();
    }
    assert len(calls) == 1 , "teardown must run exactly once on aclose";
}


# --- Drain-cascade lifecycle (Step 5): closing the outer iterator must cascade
#     to close/aclose the (context-bound) source so its commit-at-drain teardown
#     runs on cancel/disconnect, not only on natural exhaustion. --------------

# Closing the iter_sync_or_async wrapper over a SYNC source closes that source
# (its finally runs), so an early consumer disconnect still tears the request
# context down.
test "closing iter_sync_or_async closes the sync source" {
    torn: list = [];
    def _src {
        try {
            i = 0;
            while True {
                yield i;
                i += 1;
            }
        } finally {
            torn.append("closed");
        }
    }
    it = iter_sync_or_async(_src());
    assert next(it) == 0;
    assert next(it) == 1;
    it.close();
    assert torn == ["closed"] , "closing the wrapper must close the sync source";
}


# Closing the wrapper over an ASYNC source aclose()s it on the wrapper's own live
# loop -- the previously-missing path that left an async stream's commit teardown
# deferred to GC after the loop was gone.
test "closing iter_sync_or_async aclose()s the async source" {
    torn: list = [];
    async def _src {
        try {
            i = 0;
            while True {
                yield i;
                i += 1;
            }
        } finally {
            torn.append("closed");
        }
    }
    it = iter_sync_or_async(_src());
    assert next(it) == 0;
    assert next(it) == 1;
    it.close();
    assert torn == ["closed"] , "closing the wrapper must aclose the async source";
}


# A client that disconnects mid-stream (write raises BrokenPipe) must have the
# underlying generator closed by drain_sse -- not leaked until GC.
test "drain_sse closes the source generator on client disconnect" {
    torn: list = [];
    def _src {
        try {
            i = 0;
            while True {
                yield {"n": i};
                i += 1;
            }
        } finally {
            torn.append("closed");
        }
    }
    writes: list = [];
    def _write(b: bytes) {
        writes.append(b);
        if len(writes) >= 2 {
            raise BrokenPipeError("client gone");
        }
    }
    drain_sse(_src(), _write);
    assert len(writes) == 2;
    assert torn == ["closed"] , "client disconnect must close the source generator";
}


# An exception raised inside an async yield frame propagates to the consumer AND
# runs teardown exactly once.
test "async teardown runs once when the source raises" {
    async def _source {
        yield 1;
        raise ValueError("boom in async yield frame");
    }
    calls: list = [];
    def _teardown {
        calls.append(1);
    }
    captured = contextvars.copy_context();
    stream = context_bound_async_stream(_source(), captured, _teardown);

    async def _drive -> bool {
        first = await stream.__anext__();
        assert first == 1;
        raised = False;
        try {
            await stream.__anext__();
        } except ValueError {
            raised = True;
        }
        return raised;
    }

    loop = asyncio.new_event_loop();
    try {
        raised = loop.run_until_complete(_drive());
    } finally {
        loop.close();
    }
    assert raised , "the source exception must surface to the consumer";
    assert len(calls) == 1 , "teardown must run exactly once even on error";
}
