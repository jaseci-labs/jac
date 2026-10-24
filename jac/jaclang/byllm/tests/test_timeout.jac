"""The call timeout (#9622, #9760): one deadline for a whole `by llm()` call, and LLMTimeout."""

import asyncio;
import time;
import from unittest { mock }
import from jaclang.byllm._optdeps.litellm { litellm }
import from jaclang.byllm.exceptions { LLMTimeout, RateLimitError }
import from jaclang.byllm.lib { MockLLM, Model, ModelPool }
import from jaclang.byllm.llm { _is_timeout_error, _is_transient_error }
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


test "one deadline covers everything a call does" {
    require_module("litellm");
    transient = litellm.APIConnectionError(
        message="connection reset", llm_provider="openai", model="gpt-4o-mini"
    );

    def nap -> str {
        time.sleep(0.6);
        return "rested";
    }

    def retry_after_failure(budget: float) -> tuple[str, int] {
        answer = litellm.completion;
        timeouts: list[float] = [];

        def fails_once(**kwargs: any) -> any {
            timeouts.append(float(kwargs["timeout"]));
            if len(timeouts) == 1 {
                raise transient;
            }
            return answer(
                model="gpt-4o-mini",
                messages=kwargs["messages"],
                mock_response="recovered"
            );
        }
        model = Model(model_name="gpt-4o-mini", api_key="sk-test", timeout=budget);
        with mock.patch("litellm.completion", fails_once) {
            got = _outcome(lambda { model.dispatch_no_streaming(mk_run()).output; });
        }
        # The 1s backoff is spent by the time the retry goes out.
        if len(timeouts) == 2 and timeouts[1] > timeouts[0] - 0.9 {
            got = "retried with a fresh budget";
        }
        return (got, len(timeouts));
    }

    def slow_failure(budget: float) -> tuple[str, int] {
        asked: list[int] = [];

        def fails_late(**_kwargs: any) -> any {
            asked.append(1);
            time.sleep(0.8);
            raise transient;
        }
        model = Model(model_name="gpt-4o-mini", api_key="sk-test", timeout=budget);
        with mock.patch("litellm.completion", fails_late) {
            got = _outcome(lambda { model.dispatch_no_streaming(mk_run()); });
        }
        return (got, len(asked));
    }

    def tool_loop(budget: float) -> tuple[str, int] {
        llm = MockLLM(outputs=[call("nap"), say("done")], timeout=budget);

        """Rest, then report."""
        def rest(note: str) -> str by llm(tools=[nap]);

        return (_outcome(lambda { rest("go"); }), len(llm.seen));
    }

    def stream_closed(budget: float, is_async: bool) -> tuple[str, int] {
        held: list[any] = [];
        closed: list[int] = [];

        def chunks -> any {
            try {
                for _ in range(100) {
                    yield text_chunk("x");
                }
            } finally {
                closed.append(1);
            }
        }

        async def achunks -> any {
            try {
                for _ in range(100) {
                    yield text_chunk("x");
                }
            } finally {
                closed.append(1);
            }
        }

        # The provider keeps its stream, so only an explicit close ends it.
        def answer(**_kwargs: any) -> any {
            held.append(chunks());
            return held[0];
        }

        async def aanswer(**_kwargs: any) -> any {
            held.append(achunks());
            return held[0];
        }
        model = Model(model_name="gpt-4o-mini", api_key="sk-test", timeout=budget);

        def read_slowly -> str {
            try {
                for _piece in model.dispatch_streaming(mk_run(stream=True)) {
                    time.sleep(0.3);
                }
            } except LLMTimeout {
                return "closed" if closed else "left open";
            }
            return "read to the end";
        }

        # Checked before asyncio.run ends, since its shutdown closes every
        # async generator still open.
        async def aread_slowly -> str {
            try {
                async for _piece in model.adispatch_streaming(mk_run(stream=True)) {
                    await asyncio.sleep(0.3);
                }
            } except LLMTimeout {
                return "closed" if closed else "left open";
            }
            return "read to the end";
        }
        if is_async {
            with mock.patch("litellm.acompletion", aanswer) {
                got = _outcome(lambda { asyncio.run(aread_slowly()); });
            }
        } else {
            with mock.patch("litellm.completion", answer) {
                got = _outcome(read_slowly);
            }
        }
        return (got, len(held));
    }

    def sync_stream_closed(budget: float) -> tuple[str, int] {
        return stream_closed(budget, False);
    }

    def async_stream_closed(budget: float) -> tuple[str, int] {
        return stream_closed(budget, True);
    }

    # (label, scenario, call budget, outcome, requests sent)
    for (label, scenario, budget, outcome, requests) in [
        (
            "a retry whose backoff fits gets only what is left",
            retry_after_failure,
            30.0,
            "recovered",
            2
        ),
        (
            "a request that spends the budget leaves no time to retry",
            slow_failure,
            1.5,
            "APIConnectionError",
            1
        ),
        (
            "a tool that outlives the deadline ends the call",
            tool_loop,
            0.4,
            "LLMTimeout",
            1
        ),
        (
            "a stream cut off at the deadline closes the provider's stream",
            sync_stream_closed,
            0.5,
            "closed",
            1
        ),
        (
            "an async stream cut off at the deadline closes the provider's stream",
            async_stream_closed,
            0.5,
            "closed",
            1
        )
    ] {
        (got, sent) = scenario(budget);
        assert got == outcome , f"{label}: got {got!r}";
        assert sent == requests , f"{label}: {sent} requests";
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
