"""Transient mid-stream retry on the single-model path (byllm#546).

Four pointed checks: a transient mid-stream drop is retried on the SAME model
with the partial output reset and a `stream_reset` surfaced (recovers); a
non-transient error is NOT retried (boundary); an unending transient error is
bounded then propagates (no hang); and the inter-chunk read timeout is set for
streaming only (fails fast). The retry decision is shared across all dispatch
paths via _is_transient_error / _resolve_stream_retries.
"""
import from byllm.lib { Model }
import from byllm.mtir { MTRuntime }
import from litellm.exceptions { APIConnectionError, AuthenticationError }
import types;

def make_chunk(text: str) -> object {
    delta = types.SimpleNamespace(content=text);
    return types.SimpleNamespace(choices=[types.SimpleNamespace(delta=delta)], usage=None);
}

def make_mt_run(stream: bool = True) -> MTRuntime {
    return MTRuntime(
        messages=[
            {"role": "system", "content": "x"},
            {"role": "user", "content": "hi"}
        ],
        resp_type=str, stream=stream, tools=[], call_params={}
    );
}

glob _drop_calls = {"n": 0};

def drop_then_recover(params: dict) -> object {
    _drop_calls["n"] += 1;
    if _drop_calls["n"] == 1 {
        yield make_chunk("PARTIAL-DISCARDED ");
        raise APIConnectionError(
            message="incomplete chunked read", llm_provider="anthropic", model="m"
        );
    }
    yield make_chunk("Hello ");
    yield make_chunk("world");
}

glob _auth_calls = {"n": 0};

def auth_fail(params: dict) -> object {
    _auth_calls["n"] += 1;
    raise AuthenticationError(message="bad key", llm_provider="anthropic", model="m");
    yield make_chunk("");
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
    # 1. recovers: retried once, partial dropped, stream_reset emitted, de-duplicated
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

    # 2. boundary: a non-transient error is not retried
    model_a = Model(model_name="gpt-4o-mini");
    model_a.model_call_with_stream = auth_fail;
    mt_a = make_mt_run();
    auth_raised: bool = False;
    try {
        list(model_a._invoke_streaming(mt_a));
    } except AuthenticationError {
        auth_raised = True;
    }
    assert auth_raised;
    assert _auth_calls["n"] == 1;
    assert mt_a._stream_reset_count == 0;

    # 3. no hang: an unending transient error is bounded (1 + 2 retries) then raises
    model_x = Model(model_name="gpt-4o-mini");
    model_x.model_call_with_stream = always_drop;
    raised: bool = False;
    try {
        list(model_x._invoke_streaming(make_mt_run()));
    } except APIConnectionError {
        raised = True;
    }
    assert raised;
    assert _always_calls["n"] == 3;

    # 4. fails fast: streaming gets the inter-chunk read timeout, non-streaming none
    model_p = Model(model_name="gpt-4o-mini");
    stream_params = model_p.make_model_params(make_mt_run(stream=True));
    assert "timeout" in stream_params;
    assert stream_params["timeout"].read == 90.0;
    assert "timeout" not in model_p.make_model_params(make_mt_run(stream=False));

    print("STREAM_RETRY_PASS");
}
