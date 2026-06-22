"""Transient mid-stream retry on the single-model path (byllm#546).

A streaming call whose response drops mid-stream with a transient transport
error must be retried on the SAME model, the partial output discarded, and a
`stream_reset` event surfaced so consumers drop what they already showed. After
the retry budget is exhausted the error propagates instead of hanging.
"""
import from byllm.lib { Model }
import from byllm.mtir { MTRuntime }
import from litellm.exceptions { APIConnectionError }
import types;

def make_chunk(text: str) -> object {
    delta = types.SimpleNamespace(content=text);
    choice = types.SimpleNamespace(delta=delta);
    return types.SimpleNamespace(choices=[choice], usage=None);
}

def make_mt_run() -> MTRuntime {
    return MTRuntime(
        messages=[
            {"role": "system", "content": "x"},
            {"role": "user", "content": "hi"}
        ],
        resp_type=str,
        stream=True,
        tools=[],
        call_params={}
    );
}

glob _drop_calls = {"n": 0};

def drop_then_recover(params: dict) -> object {
    _drop_calls["n"] += 1;
    if _drop_calls["n"] == 1 {
        yield make_chunk("PARTIAL-DISCARDED ");
        raise APIConnectionError(
            message="peer closed connection (incomplete chunked read)",
            llm_provider="anthropic",
            model="m"
        );
    }
    yield make_chunk("Hello ");
    yield make_chunk("world");
}

glob _always_calls = {"n": 0};

def always_drop(params: dict) -> object {
    _always_calls["n"] += 1;
    raise APIConnectionError(
        message="incomplete chunked read", llm_provider="anthropic", model="m"
    );
    yield make_chunk("");
}

with entry {
    # --- recover: retried once, partial dropped, output de-duplicated ---
    model = Model(model_name="gpt-4o-mini");
    model.model_call_with_stream = drop_then_recover;
    mt = make_mt_run();
    events = list(model._invoke_streaming(mt));
    kinds = [ev.event_type for ev in events];
    buf: list = [];
    for ev in events {
        if ev.event_type == "stream_reset" {
            buf = [];
        } elif ev.event_type == "chunk" {
            buf.append(ev.data.get("content", ""));
        }
    }
    assert _drop_calls["n"] == 2;
    assert mt._stream_reset_count == 1;
    assert "stream_reset" in kinds;
    assert "".join(buf) == "Hello world";

    # --- exhaust: 1 initial + 2 retries, then the transient error propagates ---
    model2 = Model(model_name="gpt-4o-mini");
    model2.model_call_with_stream = always_drop;
    raised: bool = False;
    try {
        list(model2._invoke_streaming(make_mt_run()));
    } except APIConnectionError {
        raised = True;
    }
    assert raised;
    assert _always_calls["n"] == 3;

    print("STREAM_RETRY_PASS");
}
