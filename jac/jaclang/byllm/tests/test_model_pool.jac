"""ModelPool routing: aliasing, the fallback chain, stickiness and its reports, member
settings, and the async bridge.

A pool dispatches through a litellm Router, never through its members. Fake
`router.completion` and leave the pool itself real; where a member's settings are the
subject, fake `litellm.completion` instead, so the Router's own merge runs.
"""

import contextlib;
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib {
    MockLLM,
    Model,
    ModelPool,
    StreamEvent,
    register_llm_call_hook,
    unregister_llm_call_hook
}
import from support { call, chunk_text, mk_run, say, stream_events, text_chunk }


"""The pool's litellm Router, as an untyped handle. ModelPool never exposes it
nominally, so patch or inspect it through here rather than casting at each site."""
def router(pool: ModelPool) -> any {
    return pool._router;
}


"""A litellm Router completion that answers `content`, standing in for a live
deployment."""
def _pool_reply(content: str) -> Callable {
    def _completion(**_kwargs: object) -> dict[str, any] {
        return {
            "model": "mock-pool-model",
            "choices": [
                {
                    "message": {
                        "content": content,
                        "role": "assistant",
                        "tool_calls": None
                    },
                    "finish_reason": "stop",
                    "index": 0
                }
            ]
        };
    }
    return _completion;
}


"""The same reply on the Router's async path."""
def _async_pool_reply(content: str) -> Callable {
    async def _acompletion(**_kwargs: object) -> dict[str, any] {
        return _pool_reply(content)();
    }
    return _acompletion;
}


def _pool(strategy: str, names: list[str]) -> ModelPool {
    return ModelPool(
        models=[Model(model_name=n, api_key="sk-test") for n in names],
        strategy=strategy
    );
}


test "every routing strategy dispatches through the router and answers" {
    # (strategy, deployments, expected alias, patch the async path?)
    # Only "fallback" gives each deployment a unique alias; every
    # load-balancing strategy, cost-based-routing included, shares pool-model.
    # cost-based-routing only has an acompletion path; ModelPool bridges it onto
    # the sync call, so patching acompletion is what proves the bridge is used.
    for (strategy, names, alias, is_async) in [
        ("fallback", ["gpt-3.5-turbo", "gpt-4"], "pool-primary", False),
        (
            "simple-shuffle",
            ["gpt-3.5-turbo", "gpt-4o-mini", "gemini/gemini-2.0-flash"],
            "pool-model",
            False
        ),
        ("cost-based-routing", ["gpt-4o", "gpt-4o-mini"], "pool-model", True)
    ] {
        pool = _pool(strategy, names);
        assert pool.model_name == alias , f"{strategy}: got alias {pool.model_name!r}";

        answer = f"{strategy}_answer";
        if is_async {
            router(pool).acompletion = _async_pool_reply(answer);
        } else {
            router(pool).completion = _pool_reply(answer);
        }

        def get_answer(question: str) -> str by pool();

        # Three calls, so a load-balancing pool is exercised across deployments.
        got = [get_answer(f"question {i}") for i in range(3)];
        assert got == [answer] * 3 , f"{strategy}: got {got}";
    }
}


test "a pool with every deployment exhausted raises rather than swallowing" {
    import from litellm.exceptions { RateLimitError as _LiteLLMRateLimit }
    pool = _pool("fallback", ["gpt-3.5-turbo", "gpt-4"]);

    def _all_fail(**_kwargs: object) -> object {
        raise _LiteLLMRateLimit(
            message="All deployments exhausted",
            model="gpt-3.5-turbo",
            llm_provider="openai"
        );
    }
    router(pool).completion = _all_fail;

    # Rate limits are retried with backoff; skip that here to keep the test fast.
    def get_answer(question: str) -> str by pool(stream_num_retries=0);

    raised: any = None;
    try {
        get_answer("test");
    } except Exception as e {
        raised = e;
    }
    assert raised is not None , "an exhausted pool must not return quietly";
    assert type(raised).__name__ == "RateLimitError" , (
        f"expected the rate-limit error to propagate, got {type(raised).__name__}"
    );
}


test "router init aliases deployments by strategy" {
    fb = _pool("fallback", ["gpt-3.5-turbo", "gpt-4"]);
    fb_models: any = router(fb).model_list;

    assert fb.model_name == "pool-primary" , f"got {fb.model_name!r}";
    assert len(fb_models) == 2 , f"got {len(fb_models)} deployments";
    assert fb_models[0]["model_name"] == "pool-primary";
    assert fb_models[1]["model_name"] == "pool-fallback-1";
    # The pool walks the members itself, so the Router has no chain to recurse into.
    assert not router(fb).fallbacks , f"got {router(fb).fallbacks}";

    lb = _pool("simple-shuffle", ["gpt-3.5-turbo", "gpt-4", "gpt-4o"]);
    lb_models: any = router(lb).model_list;
    assert lb.model_name == "pool-model";
    assert len(lb_models) == 3;
    assert all(m["model_name"] == "pool-model" for m in lb_models) , (
        f"every deployment should share the alias: {[
            m['model_name'] for m in lb_models
        ]}"
    );
}


test "a pool that fails before streaming falls back to the next deployment" {
    import from litellm.exceptions { RateLimitError }
    pool = _pool("fallback", ["gpt-3.5-turbo", "gpt-4"]);
    tried: list[str] = [];

    def _completion(
        model: str,
        messages: list[dict[str, any]],
        stream: bool,
        fallbacks: list[any],
        **_kw: object
    ) -> object {
        tried.append(model);
        if model == "pool-primary" {
            raise RateLimitError(
                message="Primary quota exceeded",
                model="gpt-3.5-turbo",
                llm_provider="openai"
            );
        }
        def _gen -> object {
            yield text_chunk("stream_fallback_");
            yield text_chunk("success");
        }
        return _gen();
    }

    # `_completion` is the per-model call the fallback loop drives with
    # fallbacks=[], so the Router cannot recurse back into the primary.
    router(pool)._completion = _completion;

    def stream_answer(question: str) -> str by pool(stream=True);

    assert "".join(list(stream_answer("test question"))) == "stream_fallback_success";
    assert tried == ["pool-primary", "pool-fallback-1"] , (
        f"the primary must be tried first, then the fallback, got {tried}"
    );
}


test "a pool that fails mid-stream raises rather than splicing in a fallback" {
    # Once a chunk has been delivered the caller has already seen partial
    # output, so falling back would concatenate partial-A with a whole B. The
    # yielded guard turns that into a raise instead.
    import from litellm.exceptions { RateLimitError }
    pool = _pool("fallback", ["gpt-3.5-turbo", "gpt-4"]);
    tried: list[str] = [];

    def _completion(
        model: str,
        messages: list[dict[str, any]],
        stream: bool,
        fallbacks: list[any],
        **_kw: object
    ) -> object {
        tried.append(model);
        if model == "pool-primary" {
            def _failing -> object {
                yield text_chunk("partial_chunk");
                raise RateLimitError(
                    message="Primary failed mid-stream",
                    model="gpt-3.5-turbo",
                    llm_provider="openai"
                );
            }
            return _failing();
        }
        def _never -> object {
            yield text_chunk("should_not_appear");
        }
        return _never();
    }
    router(pool)._completion = _completion;

    def stream_answer(question: str) -> str by pool(stream=True);

    chunks: list[any] = [];
    raised: any = None;
    try {
        for chunk in stream_answer("test question") {
            chunks.append(chunk);
        }
    } except RateLimitError as e {
        raised = e;
    }
    assert raised is not None , "a mid-stream failure must reach the caller";
    assert "partial_chunk" in "".join(chunks) , (
        f"what was already streamed is still delivered, got {chunks}"
    );
    assert "should_not_appear" not in "".join(chunks) , (
        f"the fallback must not be spliced onto partial output, got {chunks}"
    );
    assert tried == ["pool-primary"] , f"the fallback must not be tried at all, got {tried}";
}


"""The tool the agent turns below call."""
def lookup(q: str) -> str {
    return f"found {q}";
}


glob PRIMARY = "pool-primary",
     SECOND = "pool-fallback-1",
     SILENT_MODEL = "together_ai/glm-5.3-flash",
     ANSWERING_MODEL = "gpt-4o-mini";


"""A fallback pool whose deployments in `down` time out, the way a silent provider
does; the others answer from `answers`, on the Router's streaming and non-streaming
paths alike. `tried` records the deployment of every attempt."""
def _pool_with_outage(
    answers: MockLLM, tried: list[str], down: set[str], sticky: bool = False
) -> ModelPool {
    import litellm;
    pool = ModelPool(
        models=[
            Model(model_name=SILENT_MODEL, api_key="sk-test"),
            Model(model_name=ANSWERING_MODEL, api_key="sk-test")
        ],
        strategy="fallback",
        sticky=sticky
    );
    def _deployment(model: str, **kwargs: object) -> object {
        tried.append(model);
        if model in down {
            raise litellm.Timeout(
                message="no bytes in 90 s", model=model, llm_provider="together_ai"
            );
        }
        if kwargs.get("stream") {
            return answers.model_call_with_stream(kwargs);
        }
        return answers.model_call_no_stream(kwargs);
    }
    router(pool).completion = _deployment;
    router(pool)._completion = _deployment;
    return pool;
}


test "a sticky pool stays on the member that answered for the rest of its by call" {
    # The turn makes two model calls: the tool call, then the answer. A plain pool
    # waits on the silent primary before both; a sticky one only before the first.
    for (stream, sticky, want) in [
        (False, False, [PRIMARY, SECOND, PRIMARY, SECOND]),
        (False, True, [PRIMARY, SECOND, SECOND]),
        (True, False, [PRIMARY, SECOND, PRIMARY, SECOND]),
        (True, True, [PRIMARY, SECOND, SECOND])
    ] {
        tried: list[str] = [];
        answers = MockLLM(outputs=[call("lookup", {"q": "x"}), say("done")]);
        pool = _pool_with_outage(answers, tried, {PRIMARY}, sticky=sticky);

        def turn(q: str) -> str by pool(tools=[lookup], stream=stream, logging=stream);

        result = turn("x");
        answer = chunk_text(stream_events(result)) if stream else result;
        label = f"stream={stream}, sticky={sticky}";
        assert answer == "done" , f"{label}: got {answer!r}";
        assert tried == want , f"{label}: tried {tried}";
    }
}


test "the next by call on a sticky pool starts at the primary again" {
    tried: list[str] = [];
    pool = _pool_with_outage(
        MockLLM(outputs=["one", "two"]), tried, {PRIMARY}, sticky=True
    );

    def ask(q: str) -> str by pool();

    assert [ask("a"), ask("b")] == ["one", "two"];
    assert tried == [PRIMARY, SECOND, PRIMARY, SECOND] , f"tried {tried}";
}


test "a sticky pool wraps round to the next member when the one it stays on fails" {
    # Each member goes down right after it answers, so every call fails over: from
    # the primary to the second member, from there back round to the primary.
    tried: list[str] = [];
    down = {PRIMARY};
    answers = MockLLM(
        outputs=[call("lookup", {"q": "1"}), call("lookup", {"q": "2"}), say("done")]
    );
    pool = _pool_with_outage(answers, tried, down, sticky=True);
    serve = router(pool).completion;

    def flaky(model: str, **kwargs: object) -> object {
        reply = serve(model, **kwargs);
        down.clear();
        down.add(model);
        return reply;
    }
    router(pool).completion = flaky;

    def turn(q: str) -> str by pool(tools=[lookup]);

    assert turn("x") == "done";
    assert tried == [PRIMARY, SECOND, SECOND, PRIMARY, PRIMARY, SECOND] , (
        f"tried {tried}"
    );
}


test "a sticky pool stays on the member a compaction summary moved to" {
    # The second member answers the turn's two tool calls, then goes down. The
    # summary compaction asks for falls back to the primary, so the turn's last
    # call starts there instead of waiting on the second member again.
    tried: list[str] = [];
    down = {PRIMARY};
    big = {"prompt_tokens": 950, "completion_tokens": 5, "total_tokens": 955};
    answers = MockLLM(
        outputs=[
            (call("lookup", {"q": "a" * 400}), big),
            (call("lookup", {"q": "b" * 400}), big),
            say("summary of the history"),
            say("done")
        ]
    );
    pool = _pool_with_outage(answers, tried, down, sticky=True);
    serve = router(pool).completion;

    def second_goes_down(model: str, **kwargs: object) -> object {
        reply = serve(model, **kwargs);
        if tried.count(SECOND) == 2 {
            down.clear();
            down.add(SECOND);
        }
        return reply;
    }
    router(pool).completion = second_goes_down;

    def turn(q: str) -> str by pool(
        tools=[lookup], ctx_window=1000, keep_recent_iterations=1
    );

    assert turn("x") == "done";
    assert "Summarise" in str(answers.seen[2]) , "the third call is the summary";
    assert tried == [PRIMARY, SECOND, SECOND, SECOND, PRIMARY, PRIMARY] , (
        f"tried {tried}"
    );
}


test "every switch is reported as a model_fallback event and on the answering call's usage" {
    want = {"from": SILENT_MODEL, "to": ANSWERING_MODEL, "error": "Timeout"};
    for (label, tools, handled) in [
        ("logging stream with tools", [lookup], False),
        ("logging stream, no tools", [], False),
        ("stream_handler, structured answer", [], True)
    ] {
        tried: list[str] = [];
        events: list[StreamEvent] = [];
        if handled {
            pool = _pool_with_outage(MockLLM(outputs=[42]), tried, {PRIMARY});

            def count(q: str) -> int by pool(
                stream=True, stream_handler=events.append
            );

            assert count("x") == 42 , f"{label}: the answer still arrives";
        } else {
            answers = MockLLM(
                outputs=[call("lookup", {"q": "x"}), say("42")]
                    if tools
                    else [say("42")]
            );
            pool = _pool_with_outage(answers, tried, {PRIMARY});
            def answer(q: str) -> str by pool(tools=tools, stream=True, logging=True);
            events = stream_events(answer("x"));
            assert chunk_text(events) == "42" , f"{label}: got {chunk_text(events)!r}";
        }
        switches = [
            e.data
            for e in events
            if e.event_type == "model_fallback"
        ];
        assert switches and all(s == want for s in switches) , (
            f"{label}: got {switches} in {[e.event_type for e in events]}"
        );
        if not handled {
            per_call = events[-1].data["per_call"];
            assert [
                r.get("fallbacks")
                for r in per_call
                if r.get("fallbacks")
            ]
                == [[want]] * len(switches) , f"{label}: usage {per_call}";
        }
    }

    tried: list[str] = [];
    healthy = _pool_with_outage(MockLLM(outputs=["fine"]), tried, set());

    def calm(q: str) -> str by healthy(stream=True, logging=True);

    events = stream_events(calm("x"));
    assert chunk_text(events) == "fine" and tried == [PRIMARY];
    assert "model_fallback" not in [e.event_type for e in events];
    assert "fallbacks" not in events[-1].data["per_call"][0];
}


test "a call that does not stream reports the switch on its usage entry" {
    records: list[dict[str, any]] = [];
    tried: list[str] = [];
    pool = _pool_with_outage(MockLLM(outputs=["fine"]), tried, {PRIMARY});

    def ask(q: str) -> str by pool();

    register_llm_call_hook(records.append);
    try {
        assert ask("x") == "fine";
    } finally {
        unregister_llm_call_hook(records.append);
    }
    want = [{"from": SILENT_MODEL, "to": ANSWERING_MODEL, "error": "Timeout"}];
    assert [r["usage"].get("fallbacks") for r in records] == [want] , f"got {records}";
}


test "a stream that fails still reports the switches it made" {
    import litellm;
    import unittest.mock;
    want = {"from": SILENT_MODEL, "to": ANSWERING_MODEL, "error": "Timeout"};
    big = {"prompt_tokens": 950, "completion_tokens": 5, "total_tokens": 955};
    # (label, deployments down, replies, tools, through a stream_handler, switches)
    # The last row's turn switches on both of its model calls, then compaction's
    # summary, the only call that does not stream, finds every member down.
    for (label, down, replies, tools, handled, expected) in [
        ("every member down, logging stream", {PRIMARY, SECOND}, [], [], False, 1),
        ("every member down, stream_handler", {PRIMARY, SECOND}, [], [], True, 1),
        (
            "every member down for the compaction summary",
            {PRIMARY},
            [
                (call("lookup", {"q": "a" * 400}), big),
                (call("lookup", {"q": "b" * 400}), big)
            ],
            [lookup],
            False,
            3
        )
    ] {
        tried: list[str] = [];
        events: list[StreamEvent] = [];
        pool = _pool_with_outage(MockLLM(outputs=replies), tried, down);

        def _all_down(model: str, **kwargs: object) -> object {
            raise litellm.Timeout(
                message="no bytes", model=model, llm_provider="together_ai"
            );
        }
        router(pool).completion = _all_down;

        def answer(q: str) -> str by pool(
            tools=tools,
            stream=True,
            logging=True,
            ctx_window=1000,
            keep_recent_iterations=1
        );

        def count(q: str) -> int by pool(stream=True, stream_handler=events.append);

        raised: any = None;
        with unittest.mock.patch.dict(
            _byllm_llm_mod._streaming_config, {"num_retries": 0}
        ) {
            try {
                if handled {
                    count("x");
                } else {
                    turn: any = answer("x");
                    for ev in turn {
                        events.append(ev);
                    }
                }
            } except Exception as e {
                raised = e;
            }
        }
        assert type(raised).__name__ == "Timeout" , f"{label}: got {raised!r}";
        switches = [
            e.data
            for e in events
            if e.event_type == "model_fallback"
        ];
        assert switches == [want] * expected , (
            f"{label}: got {switches} in {[e.event_type for e in events]}"
        );
    }
}


"""Answer every litellm call that a pool's Router makes from `answers`, failing those
for the models in `down`, sync and async alike. What litellm received is `answers.seen`."""
def _provider(answers: MockLLM, down: set[str]) -> any {
    import litellm;
    import unittest.mock;
    def _completion(**kwargs: object) -> object {
        if kwargs.get("model") in down {
            raise litellm.Timeout(
                message="no bytes",
                model=str(kwargs.get("model")),
                llm_provider="openai"
            );
        }
        return answers.model_call_no_stream(kwargs);
    }
    async def _acompletion(**kwargs: object) -> object {
        return _completion(**kwargs);
    }
    stack = contextlib.ExitStack();
    stack.enter_context(unittest.mock.patch.object(litellm, "completion", _completion));
    stack.enter_context(
        unittest.mock.patch.object(litellm, "acompletion", _acompletion)
    );
    return stack;
}


"""What the provider was sent, reduced to the two settings under test."""
def _settings(request: dict[str, any]) -> tuple[any, any] {
    return (request.get("temperature"), request.get("max_tokens"));
}


test "each member's own settings reach its request, on every strategy" {
    member_settings = {"temperature": 0.0, "max_tokens": 17};
    for strategy in ["fallback", "simple-shuffle", "cost-based-routing"] {
        answers = MockLLM(outputs=["ok"]);
        pool = ModelPool(
            models=[
                Model(
                    model_name="gpt-4o-mini",
                    api_key="sk-test",
                    call_params=member_settings
                )
            ],
            strategy=strategy
        );
        with _provider(answers, set()) {
            pool.invoke(mk_run());
        }
        sent = answers.seen[-1];
        assert _settings(sent) == (0.0, 17) , f"{strategy}: sent {sent}";
    }

    answers = MockLLM(outputs=["ok"]);
    pair = ModelPool(
        models=[
            Model(
                model_name="gpt-4o",
                api_key="sk-test",
                call_params={"temperature": 0.1, "max_tokens": 11}
            ),
            Model(
                model_name="gpt-4o-mini",
                api_key="sk-test",
                call_params={"temperature": 0.9, "max_tokens": 33}
            )
        ],
        strategy="fallback"
    );
    with _provider(answers, {"gpt-4o"}) {
        pair.invoke(mk_run());
    }
    assert _settings(answers.seen[-1]) == (0.9, 33) , (
        f"the member that answered sends its own settings, sent {answers.seen[-1]}"
    );
}


test "a setting comes from the call site, then the member, then jac.toml" {
    import unittest.mock;
    for (label, call_site, member, project, want) in [
        ("member only", {}, {"temperature": 0.0}, {}, (0.0, None)),
        (
            "call site beats member",
            {"temperature": 0.5},
            {"temperature": 0.0},
            {},
            (0.5, None)
        ),
        (
            "member beats jac.toml",
            {},
            {"max_tokens": 17},
            {"max_tokens": 99},
            (None, 17)
        ),
        ("jac.toml fills in", {}, {"temperature": 0.0}, {"max_tokens": 99}, (0.0, 99)),
        ("nothing set", {}, {}, {}, (None, None))
    ] {
        answers = MockLLM(outputs=["ok"]);
        with unittest.mock.patch.dict(_byllm_llm_mod._call_params_config, project) {
            pool = ModelPool(
                models=[
                    Model(
                        model_name="gpt-4o-mini", api_key="sk-test", call_params=member
                    )
                ],
                strategy="fallback"
            );
            with _provider(answers, set()) {
                pool(**call_site).invoke(mk_run());
            }
        }
        sent = answers.seen[-1];
        assert _settings(sent) == want , f"{label}: sent {sent}";
    }
}
