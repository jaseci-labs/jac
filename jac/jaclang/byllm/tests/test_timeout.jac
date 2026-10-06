"""Non-streaming request timeout (#9622): where it resolves from, and LLMTimeout."""

import socket;
import threading;
import time;
import from jaclang.byllm._optdeps.litellm { litellm }
import from jaclang.byllm.exceptions { LLMTimeout, RateLimitError }
import from jaclang.byllm.lib { Model, ModelPool }
import from jaclang.byllm.llm { _is_timeout_error, _is_transient_error }
import from jaclang.testing.requires { require_module }
import from support { mk_run }


test "the bound resolves through its precedence chain" {
    via_call_params = Model(model_name="gpt-4o-mini", timeout=45.0);
    via_call_params(timeout=30.0);

    # (label, model, call-site params, expected) -- None expects no key at all.
    cases: list[any] = [
        ("the configured default", Model(model_name="gpt-4o-mini"), {}, 600.0),
        ("the model field", Model(model_name="gpt-4o-mini", timeout=45.0), {}, 45.0),
        ("model call_params over the field", via_call_params, {}, 30.0),
        (
            "the call site over everything",
            Model(model_name="gpt-4o-mini", timeout=45.0),
            {"timeout": 15.0},
            15.0
        ),
        ("zero drops the bound", Model(model_name="gpt-4o-mini", timeout=0.0), {}, None)
    ];
    for (label, model, call_params, expected) in cases {
        params = model.make_model_params(mk_run(stream=False, call_params=call_params));
        got = params.get("timeout");
        if expected is None {
            assert "timeout" not in params , f"{label}: got {got!r}";
        } else {
            assert got == expected , f"{label}: got {got!r}";
        }
    }
}


test "a stalled endpoint raises LLMTimeout at the configured bound" {
    # A socket that accepts and never answers.
    require_module("litellm");
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", 0));
    srv.listen(1);
    port = srv.getsockname()[1];
    held: list[any] = [];

    def stall -> None {
        try {
            (conn, _addr) = srv.accept();
            held.append(conn);
            conn.recv(65536);
        } except Exception {
            return;
        }
    }
    worker = threading.Thread(target=stall, daemon=True);
    worker.start();

    model = Model(
        model_name="openai/gpt-4o-mini",
        api_key="sk-test",
        config={"base_url": f"http://127.0.0.1:{port}"}
    );
    raised: any = None;
    started = time.monotonic();
    try {
        model.dispatch_no_streaming(
            mk_run(call_params={"timeout": 3.0, "stream_num_retries": 0})
        );
    } except Exception as e {
        raised = e;
    } finally {
        for conn in held {
            conn.close();
        }
        srv.close();
        worker.join(timeout=2.0);
    }
    elapsed = time.monotonic() - started;
    assert isinstance(raised, LLMTimeout) , f"got {type(raised).__name__}: {raised}";
    assert elapsed >= 3.0 , f"gave up before the bound: {elapsed:.1f}s";
    # One request, not three: litellm's own retries would land near 11s.
    assert elapsed < 9.0 , f"the bound covered more than one request: {elapsed:.1f}s";
}


test "a pool leaves the bound to its router" {
    # The Router already gets [byllm.fallback] timeout.
    pool = ModelPool(models=[Model(model_name="gpt-4o-mini")]);
    assert pool._resolve_timeout(mk_run(stream=False)) is None;
    assert "timeout" not in pool.make_model_params(mk_run(stream=False));
}


test "LLMTimeout and RateLimitError stay retryable" {
    err = LLMTimeout(message="provider stalled", model="gpt-4o-mini");
    assert isinstance(err, litellm.Timeout) , "LLMTimeout must remain a litellm.Timeout";
    assert _is_transient_error(err) , "LLMTimeout must stay transient";
    assert str(err) == "provider stalled" , f"got {str(err)!r}";
    assert err.model == "gpt-4o-mini" , f"got {err.model!r}";
    assert err.status_code == 408 , f"got {err.status_code!r}";
    # litellm's own 429 retry is off (num_retries=0), so byLLM must retry it.
    assert _is_transient_error(RateLimitError("429")) , "RateLimitError must stay transient";
}


test "every transport's timeout type is recognised" {
    require_module("litellm");
    import httpx;
    assert _is_timeout_error(
        litellm.Timeout(message="stalled", model="gpt-4o-mini", llm_provider="openai")
    ) , "the litellm transport";
    assert _is_timeout_error(httpx.ReadTimeout("stalled")) , "the http_client transport";
    assert not _is_timeout_error(ValueError("not a timeout"));
}
