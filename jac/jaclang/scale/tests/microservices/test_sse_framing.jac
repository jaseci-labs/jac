import asyncio;
import from typing { AsyncIterator, Iterator }
import from jaclang.scale.runtime.middleware.sse { sse_frame_stream }


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


async def _collect(agen: object) -> list {
    out: list = [];
    async for frame in agen {
        out.append(frame);
    }
    return out;
}


async def _async_producer -> AsyncIterator {
    yield {"n": 0};
    yield {"n": 1};
    yield {"n": 2};
}


async def _raising_producer -> AsyncIterator {
    yield {"ok": 1};
    raise ValueError("boom");
}


def _sync_producer -> Iterator {
    yield {"a": 1};
    yield {"a": 2};
}


test "sse_frame_stream frames each async item as a data: line and ends with event: end" {
    frames = _run(_collect(sse_frame_stream(_async_producer())));

    # three data frames + one terminator
    assert len(frames) == 4;
    assert frames[0] == "data: {\"n\": 0}\n\n";
    assert frames[1] == "data: {\"n\": 1}\n\n";
    assert frames[2] == "data: {\"n\": 2}\n\n";
    assert frames[3] == "event: end\ndata: {}\n\n";

    # every data frame is terminated by a blank line per SSE wire format
    for f in frames[0:3] {
        assert f.startswith("data: ");
        assert f.endswith("\n\n");
    }
}


test "sse_frame_stream drives a real sync generator through run_in_executor" {
    frames = _run(_collect(sse_frame_stream(_sync_producer())));

    assert len(frames) == 3;
    assert frames[0] == "data: {\"a\": 1}\n\n";
    assert frames[1] == "data: {\"a\": 2}\n\n";
    assert frames[2] == "event: end\ndata: {}\n\n";
}


test "sse_frame_stream emits event: error and no end frame when the producer raises" {
    frames = _run(_collect(sse_frame_stream(_raising_producer())));

    # the item yielded before the raise still framed, then an error frame
    assert len(frames) == 2;
    assert frames[0] == "data: {\"ok\": 1}\n\n";

    err = frames[1];
    assert err.startswith("event: error\ndata: ");
    assert err.endswith("\n\n");
    # the real exception type and message are carried on the error payload
    assert "\"error_type\": \"ValueError\"" in err;
    assert "\"message\": \"boom\"" in err;

    # the success terminator must NOT be emitted on the error path
    for f in frames {
        assert not f.startswith("event: end");
    }
}


test "sse_frame_stream rejects a non-generator argument with TypeError" {
    raised: bool = False;
    try {
        _run(_collect(sse_frame_stream([1, 2, 3])));
    } except TypeError {
        raised = True;
    }
    assert raised;
}
