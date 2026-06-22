"""Transient mid-stream retry on the single-model path (byllm#546).

A streaming call whose response drops mid-stream with a transient transport
error must be retried on the SAME model, the partial output discarded, and a
`stream_reset` surfaced so consumers drop what they already showed. Non-transient
errors must NOT retry, and after the retry budget is exhausted the error
propagates instead of hanging. Covers the no-tools path, the with-tools path
(what agents use), the negative case, and the streaming-only read timeout.
"""
import from byllm.lib { Model }
import from byllm.mtir { MTRuntime }
import from litellm.exceptions { APIConnectionError, AuthenticationError }
import types;

def make_chunk(text: str) -> object {
    delta = types.SimpleNamespace(content=text);
    choice = types.SimpleNamespace(delta=delta);
    return types.SimpleNamespace(choices=[choice], usage=None);
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
            message="peer closed connection (incomplete chunked read)",
            llm_provider="anthropic", model="m"
        );
    }
    yield make_chunk("Hello ");
    yield make_chunk("world");
}

glob _tools_calls = {"n": 0};

def drop_then_recover_tools(params: dict) -> object {
    _tools_calls["n"] += 1;
    if _tools_calls["n"] == 1 {
        yield make_chunk("PARTIAL-DISCARDED ");
        raise APIConnectionError(
            message="incomplete chunked read", llm_provider="anthropic", model="m"
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

glob _auth_calls = {"n": 0};

def auth_fail(params: dict) -> object {
    _auth_calls["n"] += 1;
    raise AuthenticationError(message="bad key", llm_provider="anthropic", model="m");
    yield make_chunk("");
}

with entry {
    # --- no-tools path: retried once, partial dropped, output de-duplicated ---
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

    # --- with-tools path (what agents use): partial step discarded on retry ---
    model_t = Model(model_name="gpt-4o-mini");
    model_t.model_call_with_stream = drop_then_recover_tools;
    mt_t = make_mt_run();
    out: list = [];
    list(model_t.dispatch_streaming_with_tools(mt_t, out));
    assert _tools_calls["n"] == 2;
    assert mt_t._stream_reset_count == 1;
    assert out[0].output == "Hello world";

    # --- non-transient error must NOT retry (guards the classifier) ---
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

    # --- Part A: streaming gets an inter-chunk read timeout, non-streaming none ---
    model_p = Model(model_name="gpt-4o-mini");
    stream_params = model_p.make_model_params(make_mt_run(stream=True));
    assert "timeout" in stream_params;
    assert stream_params["timeout"].read == 90.0;
    ns_params = model_p.make_model_params(make_mt_run(stream=False));
    assert "timeout" not in ns_params;

    print("STREAM_RETRY_PASS");
}
