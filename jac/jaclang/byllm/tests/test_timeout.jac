"""The call timeout (#9622, #9760): one deadline for a whole `by llm()` call, and LLMTimeout."""

import asyncio;
import time;
import from unittest { mock }
import from jaclang.byllm._optdeps.litellm { litellm }
import from jaclang.byllm.exceptions { LLMTimeout, RateLimitError }
import from jaclang.byllm.lib { MockLLM, Model, ModelPool }
import from jaclang.byllm.llm {
    _NO_FORCED_TOOL_MODELS,
    _is_timeout_error,
    _is_transient_error
}
import from jaclang.testing.requires { require_module }
import from support { call, mk_run, say, text_chunk }


"""Run `work`, naming the error it raises in place of its result."""
def _outcome(work: Callable) -> str {
    try {
        return str(work());
    } except Exception as e {
        return type(e).__name__;
    }
}


test "the bound resolves through its precedence chain" {
    via_call_params = Model(model_name="gpt-4o-mini", timeout=45.0);
    via_call_params(timeout=30.0);

    # (label, model, call-site params, expected budget) -- None means no bound at all.
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
        run = mk_run(stream=False, call_params=call_params);
        params = model.make_model_params(run);
        assert model._call_deadline(run).budget == expected , (
            f"{label}: got {model._call_deadline(run).budget!r}"
        );
        got = params.get("timeout");
        if expected is None {
            assert "timeout" not in params , f"{label}: got {got!r}";
        } else {
            # A request gets what is left of the call's budget, not a fresh one.
            assert expected - 1.0 < got <= expected , f"{label}: got {got!r}";
        }
    }
}


test "a stalled request raises LLMTimeout after one request on every transport" {
    require_module("litellm");
    require_module("openai");
    import httpx;
    # Every send times out at once, so the count is the whole story: a provider
    # client retrying underneath byLLM would send three.
    sent: list[int] = [];

    def stall(*_args: any, **_kwargs: any) -> any {
        sent.append(1);
        raise httpx.ReadTimeout("stalled");
    }

    async def astall(*_args: any, **_kwargs: any) -> any {
        sent.append(1);
        raise httpx.ReadTimeout("stalled");
    }

    async def drain(model: Model, run: any, streaming: bool) {
        if streaming {
            async for _piece in model.adispatch_streaming(run) {}
        } else {
            await model.adispatch_no_streaming(run);
        }
    }

    def send_once(model: Model, run: any, streaming: bool, is_async: bool) -> any {
        if is_async {
            return asyncio.run(drain(model, run, streaming));
        }
        if streaming {
            return list(model.dispatch_streaming(run));
        }
        return model.dispatch_no_streaming(run);
    }

    # (label, model config beyond base_url, streaming, async)
    for (label, extra, streaming, is_async) in [
        ("litellm", {}, False, False),
        ("litellm, streaming", {}, True, False),
        ("litellm async, streaming", {}, True, True),
        ("proxy", {"proxy": True}, False, False),
        ("proxy, streaming", {"proxy": True}, True, False),
        ("proxy async", {"proxy": True}, False, True),
        ("proxy async, streaming", {"proxy": True}, True, True)
    ] {
        sent.clear();
        model = Model(
            model_name="openai/gpt-4o-mini",
            api_key="sk-test",
            config={"base_url": "http://127.0.0.1:9/v1"} | extra
        );
        run = mk_run(stream=streaming, call_params={"stream_num_retries": 0});
        with mock.patch.object(httpx.Client, "send", stall) {
            with mock.patch.object(httpx.AsyncClient, "send", astall) {
                got = _outcome(lambda { send_once(model, run, streaming, is_async); });
            }
        }
        assert got == "LLMTimeout" , f"{label}: got {got}";
        sends = len(sent);
        assert sends == 1 , f"{label}: the client retried underneath, {sends} sends";
    }
}


"""A fake provider: request n runs `steps[n]` (wait, fail, answer or stream), notes any
request given more time than the call had left, and keeps every stream it hands out."""
obj _Provider {
    has budget: float,
        steps: list[any],
        real: any,
        started: float = 0.0,
        closed: int = 0,
        open_after: int = 0,
        held: list[any] = [],
        sent: list[float] = [],
        overgiven: list[str] = [];

    def postinit {
        self.started = time.monotonic();
    }

    def record(timeout: any) -> list[any] {
        left = self.budget - (time.monotonic() - self.started);
        given = max(timeout.connect, timeout.read) if timeout?.read else float(timeout);
        self.sent.append(given);
        if given > left + 0.05 {
            self.overgiven.append(
                f"request {len(self.sent)}: {given:.1f}s, {left:.1f}s left"
            );
        }
        return self.steps[len(self.sent) - 1];
    }

    def completion(**kwargs: any) -> any {
        for (act, arg) in self.record(kwargs["timeout"]) {
            if act == "wait" {
                time.sleep(arg);
            } elif act == "fail" {
                raise arg;
            } elif act == "answer" {
                return self.real(
                    model="gpt-4o-mini", messages=kwargs["messages"], mock_response=arg
                );
            } else {
                self.held.append(self.stream(arg, kwargs["timeout"].read));
                return self.held[-1];
            }
        }
    }

    async def acompletion(**kwargs: any) -> any {
        self.record(kwargs["timeout"]);
        self.held.append(self.astream());
        return self.held[-1];
    }

    # With an error, waits out the read timeout it was given, as httpx would.
    def stream(error: Exception | None, read: float) -> any {
        try {
            if error is not None {
                time.sleep(min(read, 1.0));
                raise error;
            }
            for _ in range(10) {
                yield text_chunk("x");
            }
        } finally {
            self.closed += 1;
        }
    }

    async def astream -> any {
        try {
            for _ in range(10) {
                yield text_chunk("x");
            }
        } finally {
            self.closed += 1;
        }
    }
}


def _nap -> str {
    time.sleep(0.6);
    return "rested";
}


def _read_slowly(model: Model, fake: _Provider) -> str {
    try {
        for _piece in model.dispatch_streaming(mk_run(stream=True)) {
            time.sleep(0.3);
        }
    } finally {
        fake.open_after = len(fake.held) - fake.closed;
    }
    return "read to the end";
}


# Counted before asyncio.run ends, since its shutdown closes every open async generator.
async def _aread_slowly(model: Model, fake: _Provider) -> str {
    try {
        async for _piece in model.adispatch_streaming(mk_run(stream=True)) {
            await asyncio.sleep(0.3);
        }
    } finally {
        fake.open_after = len(fake.held) - fake.closed;
    }
    return "read to the end";
}


"""Run one row: `call` sends a request, `forced` one with a forced tool_choice,
`stream`/`astream` read a stream slowly, `tool` runs a tool loop on a MockLLM."""
def _run_row(mode: str, budget: float, fake: _Provider) -> str {
    if mode == "tool" {
        llm = MockLLM(outputs=[call("_nap"), say("done")], timeout=budget);

        """Rest, then report."""
        def rest(note: str) -> str by llm(tools=[_nap]);

        got = _outcome(lambda { rest("go"); });
        fake.sent = list(llm.seen);
        return got;
    }
    # A model name of its own: a rejected tool_choice is remembered per model.
    name = "gpt-4o-mini-forced" if mode == "forced" else "gpt-4o-mini";
    model = Model(model_name=name, api_key="sk-test", timeout=budget);
    forced = mk_run(call_params={"tool_choice": "required"});
    with mock.patch("litellm.completion", fake.completion) {
        with mock.patch("litellm.acompletion", fake.acompletion) {
            if mode == "astream" {
                got = _outcome(lambda { asyncio.run(_aread_slowly(model, fake)); });
            } elif mode == "stream" {
                got = _outcome(lambda { _read_slowly(model, fake); });
            } elif mode == "forced" {
                got = _outcome(lambda { model.dispatch_no_streaming(forced).output; });
            } else {
                got = _outcome(
                    lambda { model.dispatch_no_streaming(mk_run()).output; }
                );
            }
        }
    }
    _NO_FORCED_TOOL_MODELS.discard(name);
    return got;
}


test "one deadline covers everything a call does" {
    require_module("litellm");
    reset = litellm.APIConnectionError(
        message="connection reset", llm_provider="openai", model="gpt-4o-mini"
    );
    rejected = litellm.BadRequestError(
        message="tool_choice is not supported", model="m", llm_provider="openai"
    );
    stalled = litellm.Timeout(message="no chunk", model="m", llm_provider="openai");
    (fail, ok) = ([("fail", reset)], [("answer", "ok")]);
    slow_fail = [("wait", 0.8), ("fail", reset)];
    late = [("wait", 1.2), ("fail", rejected)];
    (stall, chunks) = ([("stream", stalled)], [("stream", None)]);
    # Each row sends one request per step list, gives no request more time than the
    # call has left, and leaves no provider stream open.
    # (label, mode, budget, each request's steps, outcome)
    for (label, mode, budget, steps, outcome) in [
        ("a retry gets only the time left", "call", 30.0, [fail, ok], "ok"),
        ("no time left to retry", "call", 1.5, [slow_fail], "APIConnectionError"),
        ("a tool past the deadline ends the call", "tool", 0.4, [[]], "LLMTimeout"),
        ("the fallback gets only the time left", "forced", 2.0, [late, ok], "ok"),
        ("no time left for the fallback", "forced", 1.0, [late], "LLMTimeout"),
        ("a silent stream is cut off", "stream", 0.5, [stall], "Timeout"),
        ("a cut-off stream is closed", "stream", 0.5, [chunks], "LLMTimeout"),
        ("a cut-off async stream is closed", "astream", 0.5, [chunks], "LLMTimeout")
    ] {
        fake = _Provider(budget=budget, steps=steps, real=litellm.completion);
        got = _run_row(mode, budget, fake);
        assert got == outcome , f"{label}: got {got!r}";
        assert len(fake.sent) == len(steps) , f"{label}: {len(fake.sent)} requests";
        assert not fake.overgiven , f"{label}: {fake.overgiven[0]}";
        assert fake.open_after == 0 , f"{label}: a provider stream was left open";
    }
}


test "a pool leaves the bound to its router" {
    # The Router already gets [byllm.fallback] timeout.
    pool = ModelPool(models=[Model(model_name="gpt-4o-mini")]);
    assert pool._resolve_timeout(mk_run(stream=False)) is None;
    assert "timeout" not in pool.make_model_params(mk_run(stream=False));
}


test "LLMTimeout and RateLimitError stay retryable" {
    require_module("openai");
    import httpx;
    import openai;
    err = LLMTimeout(message="provider stalled", model="gpt-4o-mini");
    assert isinstance(err, litellm.Timeout) , "LLMTimeout must remain a litellm.Timeout";
    assert str(err) == "provider stalled" , f"got {str(err)!r}";
    assert err.model == "gpt-4o-mini" , f"got {err.model!r}";
    assert err.status_code == 408 , f"got {err.status_code!r}";

    # No provider client retries underneath byLLM any more, so byLLM must retry these.
    request = httpx.Request("POST", "http://127.0.0.1/v1/chat/completions");
    # (label, error, transient)
    for (label, error, transient) in [
        ("LLMTimeout", err, True),
        ("a 429", RateLimitError("429"), True),
        (
            "a dropped proxy connection",
            openai.APIConnectionError(request=request),
            True
        ),
        (
            "a proxy 5xx",
            openai.InternalServerError(
                "upstream failed",
                response=httpx.Response(502, request=request),
                body=None
            ),
            True
        ),
        (
            "a rejected proxy request",
            openai.BadRequestError(
                "bad input", response=httpx.Response(400, request=request), body=None
            ),
            False
        )
    ] {
        assert _is_transient_error(error) == transient , (
            f"{label}: expected transient={transient}"
        );
    }
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
