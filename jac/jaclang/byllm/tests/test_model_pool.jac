"""ModelPool routing: aliasing, the fallback chain, stickiness, and the async bridge.

A pool dispatches through a litellm Router, never through its members. Fake
`router.completion` and leave the pool itself real.
"""

import unittest.mock;
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { MockLLM, Model, ModelPool }
import from support { call, events_of, fail, mk_run, say, stream_events, text_chunk }


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


def _pool(strategy: str, names: list[str], sticky: bool = False) -> ModelPool {
    return ModelPool(
        models=[Model(model_name=n, api_key="sk-test") for n in names],
        strategy=strategy,
        sticky=sticky
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


glob P = "pool-primary",
     F = "pool-fallback-1",
     SWITCH = {"from": "gpt-4o", "to": "gpt-4o-mini", "error": "Timeout"},
     BIG = {"prompt_tokens": 950, "completion_tokens": 5, "total_tokens": 955},
     RUN = {"logging": True, "ctx_window": 1000, "keep_recent_iterations": 1};


"""A sticky or plain fallback pool over P and F that answer from `replies`. Before each
attempt, the members in `outages[n]` time out, n being the calls answered so far; the
last entry holds from then on. `tried` records every attempt."""
def _pool_with_outage(
    replies: list[any], tried: list[str], outages: list[set[str]], sticky: bool = False
) -> ModelPool {
    import litellm;
    answers = MockLLM(outputs=list(replies));
    pool = _pool("fallback", ["gpt-4o", "gpt-4o-mini"], sticky);
    def _deployment(model: str, **kwargs: object) -> object {
        tried.append(model);
        if model in outages[min(len(answers.seen), len(outages) - 1)] {
            raise litellm.Timeout(message="down", model=model, llm_provider="openai");
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


"""A tool call whose usage fills most of a 1000-token window, so compaction runs."""
def _big_call(q: str) -> tuple[any, dict[str, int]] {
    return (call("lookup", {"q": q * 400}), BIG);
}


test "a sticky pool stays on the member that answered for the rest of its by call" {
    turn = [call("lookup", {"q": "x"}), say("done")];
    wraps = [call("lookup", {"q": "1"}), call("lookup", {"q": "2"}), say("done")];
    summary = [_big_call("a"), _big_call("b"), say("summary"), say("done")];
    # (label, sticky, how it runs, outages, replies, deployments tried in order)
    for (label, sticky, how, outages, replies, want) in [
        ("plain", False, "turn", [{P}], turn, [P, F, P, F]),
        ("sticky", True, "turn", [{P}], turn, [P, F, F]),
        ("sticky, streamed", True, "stream", [{P}], turn, [P, F, F]),
        ("each call starts at P", True, "twice", [{P}], ["a", "b"], [P, F, P, F]),
        ("wraps round", True, "turn", [{P}, {F}, {P}], wraps, [P, F, F, P, P, F]),
        ("compaction", True, "turn", [{P}, {P}, {F}], summary, [P, F, F, F, P, P])
    ] {
        tried: list[str] = [];
        pool = _pool_with_outage(replies, tried, outages, sticky);
        if how == "twice" {
            pool.invoke(mk_run());
            pool.invoke(mk_run());
        } else {
            out: any = pool.invoke(
                mk_run(tools=[lookup], stream=how == "stream", call_params=RUN)
            );
            if how == "stream" {
                stream_events(out);
            }
        }
        assert tried == want , f"{label}: tried {tried}";
    }
}


test "every switch is reported as an event and on the usage of the call that answered" {
    import litellm;
    usage = {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15};
    dropped = litellm.Timeout(message="reset", model="m", llm_provider="openai");
    tool_turn = [call("lookup", {"q": "x"}), say("42")];
    retried = [fail(dropped, reply=say("gone", usage=usage)), say("42", usage=usage)];
    summary = [_big_call("a"), _big_call("b")];
    # (label, outages, replies, how it is called, switches). One retry is allowed, so a
    # call that no member answers switches once per attempt.
    for (label, outages, replies, how, switches) in [
        ("logging stream", [{P}], [say("42")], "logging", 1),
        ("logging stream with tools", [{P}], tool_turn, "tools", 2),
        ("stream_handler", [{P}], [42], "handler", 1),
        ("no stream", [{P}], ["42"], "plain", 1),
        ("healthy pool", [set()], [say("42")], "logging", 0),
        ("retried after its usage chunk", [{P}], retried, "logging", 2),
        ("every member down", [{P, F}], [], "logging", 2),
        ("every member down, stream_handler", [{P, F}], [], "handler", 2),
        ("every member down in compaction", [{P}, {P}, {P, F}], summary, "tools", 4)
    ] {
        events: list[any] = [];
        raised: any = None;
        handler = events.append if how == "handler" else None;
        mt = mk_run(
            resp_type=int if how == "handler" else str,
            tools=[lookup] if how == "tools" else None,
            stream=how != "plain",
            call_params={** RUN, "stream_handler": handler}
        );
        with unittest.mock.patch.dict(
            _byllm_llm_mod._streaming_config, {"num_retries": 1, "retry_backoff": 0.0}
        ) {
            try {
                out: any = _pool_with_outage(replies, [], outages).invoke(mt);
                if how in ["logging", "tools"] {
                    for ev in out {
                        events.append(ev);
                    }
                }
            } except litellm.Timeout as e {
                raised = e;
            }
        }
        assert (raised is not None) == (outages[-1] == {P, F}) , f"{label}: {raised!r}";
        on_usage = sum([r.get("fallbacks", []) for r in mt._usage_history], []);
        reported = (
            on_usage
                if how == "plain"
                else [e.data for e in events_of(events, "model_fallback")]
        );
        assert reported == [SWITCH] * switches , f"{label}: got {reported}";
        assert raised or on_usage == reported , f"{label}: usage {on_usage}";
    }
}


test "each member's own settings reach the requests it serves" {
    import litellm;
    member = {"temperature": 0.0, "max_tokens": 17};
    pair = [member, {"max_tokens": 33}];
    toml = {"max_tokens": 99};
    # (label, strategy, settings per member, call site, jac.toml, what was sent). A
    # pair's first member times out, so its second one answers.
    for (label, strategy, members, call_site, project, want) in [
        ("fallback", "fallback", [member], {}, {}, (0.0, 17)),
        ("simple-shuffle", "simple-shuffle", [member], {}, {}, (0.0, 17)),
        ("the member that answered", "fallback", pair, {}, {}, (None, 33)),
        ("call site first", "fallback", [member], {"temperature": 0.5}, {}, (0.5, 17)),
        ("member before jac.toml", "fallback", [member], {}, toml, (0.0, 17)),
        ("jac.toml fills in", "fallback", [{"temperature": 0.0}], {}, toml, (0.0, 99)),
        ("nothing set", "fallback", [{}], {}, {}, (None, None))
    ] {
        answers = MockLLM(outputs=["ok"]);

        def _complete(**kwargs: object) -> object {
            if kwargs.get("model") == "gpt-4o" {
                raise litellm.Timeout(message="down", model="m", llm_provider="openai");
            }
            return answers.model_call_no_stream(kwargs);
        }

        names = ["gpt-4o", "gpt-4o-mini"][-len(members):];
        with unittest.mock.patch.dict(_byllm_llm_mod._call_params_config, project) {
            pool = ModelPool(
                models=[
                    Model(model_name=n, api_key="sk-test", call_params=s)
                    for (n, s) in zip(names, members)
                ],
                strategy=strategy
            );
            with unittest.mock.patch.object(litellm, "completion", _complete) {
                pool(**call_site).invoke(mk_run());
            }
        }
        sent = answers.seen[-1];
        assert (sent.get("temperature"), sent.get("max_tokens")) == want , (
            f"{label}: sent {sent}"
        );
    }
}
