"""ModelPool routing: aliasing, the fallback chain, and the async bridge.

A pool dispatches through a litellm Router, never through its members. Fake
`router.completion` and leave the pool itself real.
"""

import from jaclang.byllm.lib { Model, ModelPool }


"""The pool's litellm Router, as an untyped handle. ModelPool never exposes it
nominally, so patch or inspect it through here rather than casting at each site."""
def router(pool: ModelPool) -> any {
    return pool._router;
}


"""A litellm Router completion that answers `content`, standing in for a live
deployment."""
def _pool_reply(content: str) -> Callable {
    def _completion(**_kwargs: object) -> dict {
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
            async def _acompletion(**_kwargs: object) -> dict {
                return _pool_reply(answer)();
            }
            router(pool).acompletion = _acompletion;
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

    def get_answer(question: str) -> str by pool();

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
    fb_chain: any = router(fb).fallbacks;

    assert fb.model_name == "pool-primary" , f"got {fb.model_name!r}";
    assert len(fb_models) == 2 , f"got {len(fb_models)} deployments";
    assert fb_models[0]["model_name"] == "pool-primary";
    assert fb_models[1]["model_name"] == "pool-fallback-1";
    assert "pool-primary" in fb_chain[0] , f"got {fb_chain}";
    assert "pool-fallback-1" in fb_chain[0].get("pool-primary", []) , (
        f"the fallback chain must name the next deployment: {fb_chain}"
    );

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


"""One streaming chunk, in the shape litellm's Router hands back."""
def _stream_chunk(text: str) -> object {
    import types;
    return types.SimpleNamespace(
        choices=[types.SimpleNamespace(delta=types.SimpleNamespace(content=text))]
    );
}


test "a pool that fails before streaming falls back to the next deployment" {
    import from litellm.exceptions { RateLimitError }
    pool = _pool("fallback", ["gpt-3.5-turbo", "gpt-4"]);
    tried: list = [];

    def _completion(
        model: str, messages: list, stream: bool, fallbacks: list, **_kw: object
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
            yield _stream_chunk("stream_fallback_");
            yield _stream_chunk("success");
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
    tried: list = [];

    def _completion(
        model: str, messages: list, stream: bool, fallbacks: list, **_kw: object
    ) -> object {
        tried.append(model);
        if model == "pool-primary" {
            def _failing -> object {
                yield _stream_chunk("partial_chunk");
                raise RateLimitError(
                    message="Primary failed mid-stream",
                    model="gpt-3.5-turbo",
                    llm_provider="openai"
                );
            }
            return _failing();
        }
        def _never -> object {
            yield _stream_chunk("should_not_appear");
        }
        return _never();
    }
    router(pool)._completion = _completion;

    def stream_answer(question: str) -> str by pool(stream=True);

    chunks: list = [];
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
