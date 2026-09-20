"""Usage, cost, and per-call exposure tracking.

Usage/cost live on the per-call `mt_run`, tagged with a `call_kind` when
byLLM's own machinery makes a call on the caller's behalf, and reach the
caller three ways: the `usage` StreamEvent (once per invocation), `usage_step`
(once per call, for a caller enforcing a per-turn budget), and the `tokens`
telemetry field. All three share the same recording machinery.
"""

import asyncio;
import contextlib;
import io;
import unittest.mock;
import types;
import litellm;
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model, MockLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { MockToolCall, IterationContext }
import from jaclang.byllm.telemetry { register_agent_callback, _agent_callbacks }
import from support { TOKENS, call, events_of, finish, mk_run, say, scripted }

glob MODEL = "gpt-4o-mini",
     UNPRICEABLE = "openai/ft:definitely-not-a-real-model:acme::zzz",
     DISPATCH_PATHS = [
         "dispatch_no_streaming",
         "adispatch_no_streaming",
         "dispatch_streaming_with_tools",
         "dispatch_streaming",
         "adispatch_streaming"
     ];

obj _Person {
    has name: str,
        age: int;
}


def step_a -> str {
    return "stepped";
}


def finish_tool(final_output: str) -> str {
    return final_output;
}


def _with_callback(cb: Callable[[dict[str, any]], None], fn: Callable) -> object {
    original = _agent_callbacks.copy();
    _agent_callbacks.clear();
    register_agent_callback(cb);
    try {
        return fn();
    } finally {
        _agent_callbacks.clear();
        _agent_callbacks.extend(original);
    }
}


def _assert_tokens_via_callback(
    label: str, fn: Callable, expected_requests: int, expected_total_tokens: int
) -> tuple[any, ...] {
    captured: list[dict[str, any]] = [];
    def cb(record: dict[str, any]) {
        captured.append(record);
    }
    result = _with_callback(cb, fn);
    assert len(captured) == 1 , (
        f"{label}: expected exactly one telemetry record, got {captured}"
    );
    tokens = captured[0]["tokens"];
    assert tokens["requests"] == expected_requests , (
        f"{label}: expected {expected_requests} recorded call(s), got {tokens}"
    );
    assert tokens["total"]["total_tokens"] == expected_total_tokens , (
        f"{label}: expected total_tokens={expected_total_tokens}, got {tokens['total']}"
    );
    return (result, captured[0]);
}


# =============================================================================
# Cost computation
# =============================================================================
# Uses litellm's real `completion_cost`, not a stub - a mocked one would stay
# green even if `_attach_call_cost` silently computed nothing.

"""The usage one call on `path` records, answered by `llm`'s next queued reply."""
def _usage_from(path: str, llm: MockLLM) -> any {
    mt = mk_run();
    if path == "dispatch_no_streaming" {
        return llm.dispatch_no_streaming(mt).usage;
    }
    if path == "adispatch_no_streaming" {
        coro: any = llm.adispatch_no_streaming(mt);
        result: any = asyncio.run(coro);
        return result.usage;
    }
    if path == "dispatch_streaming_with_tools" {
        out: list[any] = [];
        list(llm.dispatch_streaming_with_tools(mt, out));
        return out[0].usage;
    }
    if path == "dispatch_streaming" {
        list(llm.dispatch_streaming(mt));
        return mt._usage_history[-1];
    }
    agen: any = llm.adispatch_streaming(mt);
    async def _drain {
        async for _item in agen {}
    }
    asyncio.run(_drain());
    return mt._usage_history[-1];
}


def _cost_of(usage: any) -> any {
    return usage.get("cost") if isinstance(usage, dict) else usage?.cost;
}


test "every dispatch path reports the cost litellm computes for the call" {
    expected = litellm.completion_cost(
        completion_response={"model": MODEL, "usage": dict(TOKENS)}, model=MODEL
    );
    assert expected > 0.0 , f"litellm priced {MODEL} at {expected}; fixture is blind";

    for path in DISPATCH_PATHS {
        llm = MockLLM(model_name=MODEL, outputs=[say("hi", usage=TOKENS)]);
        usage = _usage_from(path, llm);
        cost = _cost_of(usage);
        assert cost is not None , f"{path} left no cost on the usage payload";
        assert abs(cost - expected) < 1e-12 , (
            f"{path} reported {cost}, litellm computes {expected}"
        );
        if not isinstance(usage, dict) {
            dumped: dict[str, any] = usage.model_dump();
            assert "cost" in dumped , (
                f"{path} set cost but model_dump() dropped it, so would the aggregate"
            );
        }
    }
}


test "cost is omitted rather than guessed when it cannot be computed" {
    for (label, model, reply) in [
        ("unpriceable model", UNPRICEABLE, say("hi", usage=TOKENS)),
        (
            "model litellm cannot map to a provider",
            "acme-internal-llm",
            say("hi", usage=TOKENS)
        ),
        ("response with no usage data", MODEL, say("hi"))
    ] {
        printed = io.StringIO();
        with contextlib.redirect_stdout(printed) {
            usage = _usage_from(
                "dispatch_no_streaming", MockLLM(model_name=model, outputs=[reply])
            );
        }
        assert _cost_of(usage) is None , (
            f"{label} reported cost={_cost_of(usage)}; unknown must stay distinct "
            "from free"
        );
        # The failed lookup is expected and swallowed, so litellm's
        # provider-list hint for it is noise on every call.
        assert "Provider List" not in printed.getvalue() , (
            f"{label}: the cost lookup printed {printed.getvalue()!r}"
        );
        if reply.usage {
            assert usage["prompt_tokens"] == TOKENS["prompt_tokens"] , (
                f"{label} must leave the token counts intact"
            );
        }
    }
}


test "_attach_call_cost trusts a cost litellm already computed" {
    usage = litellm.Usage(**TOKENS);
    usage.cost = 0.0042;
    with unittest.mock.patch.object(
        litellm, "completion_cost", return_value=999.0
    ) as spy {
        _byllm_llm_mod._attach_call_cost(usage, MODEL);
        assert spy.call_count == 0 , (
            "a cost litellm already attached must not trigger recomputation"
        );
    }
    assert usage.cost == 0.0042 , "a cost litellm already attached must not be overwritten";
}


test "byllm opts in to litellm's native include_cost_in_streaming_usage, configurably" {
    # litellm computes a more accurate `cost` itself when this flag is set,
    # so byLLM opts in by default rather than relying only on its own fallback.
    litellm.include_cost_in_streaming_usage = False;
    Model(model_name=MODEL);
    assert litellm.include_cost_in_streaming_usage , (
        "byllm should opt in to litellm's native streaming cost computation by default"
    );

    with unittest.mock.patch.dict(
        _byllm_llm_mod._litellm_config,
        {"debug": False, "drop_params": True, "include_cost_in_streaming_usage": False},
        clear=True
    ) {
        litellm.include_cost_in_streaming_usage = True;
        Model(model_name=MODEL);
        assert not litellm.include_cost_in_streaming_usage , (
            "config should be able to turn off litellm's native streaming cost "
            "computation"
        );
    }
}


test "include_cost_in_streaming_usage defaults to True" {
    import from jaclang.byllm.config_loader { JacByllmConfig }
    defaults = JacByllmConfig().get_default_config();
    assert defaults["litellm"]["include_cost_in_streaming_usage"] == True;
}


test "dispatch_streaming_with_tools forwards the stream's logging_obj and attributes usage to the served model" {
    # litellm only computes a native cost when stream_chunk_builder receives
    # a logging_obj - byLLM's rebuild call must forward the one on the
    # CustomStreamWrapper, or every tools-loop call loses the native path.
    marker = object();
    llm = MockLLM(
        model_name="requested-model",
        logging_obj=marker,
        outputs=[say("hi", usage=TOKENS, model="actual-served-model")]
    );
    # The spy rebuilds without the marker, which litellm would try to log through.
    real_builder = litellm.stream_chunk_builder;
    seen_logging_obj: list[any] = [];
    def _spy(chunks: list[any], logging_obj: object = None) -> any {
        seen_logging_obj.append(logging_obj);
        return real_builder(chunks);
    }

    mt = mk_run(stream=True);
    out: list[any] = [];
    with unittest.mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _spy
    ) {
        list(llm.dispatch_streaming_with_tools(mt, out));
    }

    assert seen_logging_obj == [marker] , (
        f"stream_chunk_builder should receive the stream's own logging_obj, "
        f"got {seen_logging_obj}"
    );
    assert mt._usage_history[-1]["model"] == "actual-served-model" , (
        "usage must be attributed to the model stream_chunk_builder reports, "
        "not the one requested on the client"
    );
}


test "_rebuild_stream_chunks only forwards logging_obj when the cached support flag is set" {
    # The flag is fixed at import, so branch coverage patches it directly
    # rather than swapping stream_chunk_builder's own signature.
    fake_logging_obj = object();
    seen: list[any] = [];
    def _fake_builder(chunks: list[any], logging_obj: object = None) -> dict[str, any] {
        seen.append(logging_obj);
        return {"n": len(chunks)};
    }

    with unittest.mock.patch.object(
        _byllm_llm_mod.litellm, "stream_chunk_builder", _fake_builder
    ) {
        with unittest.mock.patch.object(
            _byllm_llm_mod, "_STREAM_CHUNK_BUILDER_ACCEPTS_LOGGING_OBJ", False
        ) {
            _byllm_llm_mod._rebuild_stream_chunks([1, 2], fake_logging_obj);
        }
        with unittest.mock.patch.object(
            _byllm_llm_mod, "_STREAM_CHUNK_BUILDER_ACCEPTS_LOGGING_OBJ", True
        ) {
            _byllm_llm_mod._rebuild_stream_chunks([1, 2], fake_logging_obj);
        }
    }

    assert seen == [None, fake_logging_obj] , (
        f"logging_obj must only be forwarded when the cached flag is True, "
        f"got {seen}"
    );
}


test "_stream_chunk_builder_accepts_logging_obj degrades to False and logs on any introspection failure" {
    # Two distinct raise sites share one except: litellm not being installed
    # (no stream_chunk_builder attribute at all) and a signature that itself
    # refuses to be introspected.
    cases = [
        (
            "litellm not installed",
            lambda { return unittest.mock.patch.object(
                _byllm_llm_mod, "litellm", types.SimpleNamespace()
            ); }
        ),
        (
            "signature introspection fails",
            lambda { return unittest.mock.patch(
                "inspect.signature", side_effect=ValueError("boom")
            ); }
        )
    ];
    for (label, make_patch) in cases {
        with make_patch(), unittest.mock.patch.object(
            _byllm_llm_mod.logger, "debug"
        ) as mock_debug {
            result = _byllm_llm_mod._stream_chunk_builder_accepts_logging_obj();
            assert not result , f"{label}: must degrade to False, not raise";
            assert mock_debug.call_count >= 1 , (
                f"{label}: the failure must be logged, not silently swallowed"
            );
        }
    }
}


test "_usage_to_dict logs rather than silently swallowing a serialization failure" {
    class _Unserializable {
        def model_dump(self: _Unserializable) -> dict[str, any] {
            raise RuntimeError("boom");
        }
    }

    with unittest.mock.patch.object(_byllm_llm_mod.logger, "debug") as mock_debug {
        result = _byllm_llm_mod._usage_to_dict(_Unserializable());
        assert result == {} , (
            "a usage object that fails to serialize must still degrade to an "
            "empty payload"
        );
        assert mock_debug.call_count >= 1 , (
            "a usage object that fails to serialize must be logged, not "
            "silently swallowed - it looks identical to a real zero-token "
            "call otherwise"
        );
    }
}


test "a call reporting no measurable usage is still counted, not dropped" {
    mt = mk_run();
    _byllm_llm_mod._record_usage(mt, {}, MODEL);
    _byllm_llm_mod._record_usage(mt, None, MODEL);

    assert len(mt._usage_history) == 2 , (
        "a call whose provider returned no usable payload still happened - it "
        "must not vanish from requests entirely"
    );
    assert _byllm_llm_mod._aggregate_usage(mt._usage_history)["requests"] == 2;
}


test "streaming records attribute the actual serving model and carry finish_reason" {
    # As providers send it: finish_reason arrives before usage, which comes on a
    # trailing chunk with empty choices.
    llm = MockLLM(
        model_name="requested-model",
        outputs=[say("hi", usage=TOKENS, model="actual-served-model")]
    );
    mt = mk_run(stream=True);
    list(llm.dispatch_streaming(mt));

    rec = mt._usage_history[-1];
    assert rec["model"] == "actual-served-model" , (
        "a router/pool fallback to a different model must be attributed to the "
        "model that actually served it, not the one configured on the client"
    );
    assert rec.get("finish_reason") == "stop" , (
        "streaming records must carry finish_reason like the non-streaming "
        "ones already do, even though it arrives on an earlier chunk than usage"
    );
}


# =============================================================================
# Usage capture and call_kind tagging
# =============================================================================
# Usage lives on the per-call mt_run, not the shared (and reused) model
# instance. byLLM's own follow-up calls get a call_kind distinct from
# ordinary react_iteration calls.

test "usage is recorded on mt_run, isolated per invocation, sync and async alike" {
    llm = MockLLM(
        model_name="gpt-4o-mini",
        outputs=[
            say(
                "hi",
                usage={"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}
            ),
            say(
                "hi",
                usage={"prompt_tokens": 20, "completion_tokens": 2, "total_tokens": 22}
            )
        ]
    );
    mt_sync = mk_run();
    mt_async = mk_run();

    llm.dispatch_no_streaming(mt_sync);
    coro: any = llm.adispatch_no_streaming(mt_async);
    asyncio.run(coro);

    assert len(mt_sync._usage_history) == 1 , "mt_sync should see exactly its own call";
    assert len(mt_async._usage_history) == 1 , "mt_async should see exactly its own call";
    assert mt_sync._usage_history[0]["prompt_tokens"] == 10;
    assert mt_async._usage_history[0]["prompt_tokens"] == 20 , (
        "the async primitive must record usage too, not just the sync one"
    );
    assert mt_sync._usage_history[0]["call_kind"] == "react_iteration";
    assert mt_sync._usage_history[0]["model"] == "gpt-4o-mini";
}


test "tokens telemetry is populated via register_agent_callback for every invocation shape" {
    # Model wraps a MockLLM delegate but is the layer that actually owns
    # telemetry emission (Model.invoke) - a bare MockLLM never fires it.
    llm_plain = Model(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                )
            ]
        }
    );
    def plain_task(q: str) -> str by llm_plain(tools=[finish_tool]);
    (plain_result, plain_rec) = _assert_tokens_via_callback(
        "plain non-streaming", lambda { return plain_task("test"); }, 1, 110
    );
    assert plain_result == "ok";
    assert "react_iteration" in plain_rec["tokens"]["by_kind"];

    # A str-returning finish_tool call always triggers a final_answer_restream,
    # consuming a second mock output - hence requests=2 here vs 1 above.
    llm_stream = Model(
        model_name="mockllm",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
                ),
                "ok"
            ]
        }
    );
    def stream_task(q: str) -> str by llm_stream(
        tools=[finish_tool], stream=True, logging=True
    );
    _assert_tokens_via_callback(
        "streaming, tool-calling", lambda { return list(stream_task("test")); }, 2, 110
    );

    # Async, no tools - the branch BaseLLM.ainvoke dispatches directly rather
    # than delegating to the already-telemetered sync Model.invoke.
    llm_async = Model(model_name="test-model");
    async def async_task(q: str) -> str by llm_async();
    def _run_async -> str {
        with scripted(
            llm_async,
            [
                say(
                    "async-ok",
                    usage={
                        "prompt_tokens": 12,
                        "completion_tokens": 2,
                        "total_tokens": 14
                    }
                )
            ]
        ) {
            return asyncio.run(async_task("test"));
        }
    }
    (async_result, async_rec) = _assert_tokens_via_callback(
        "async, no tools", _run_async, 1, 14
    );
    assert async_result == "async-ok";
    assert async_rec["status"] == "success";
}


def _restream_case -> MTRuntime {
    llm = MockLLM(
        model_name="test-model",
        outputs=[
            say(
                "Gus",
                usage={"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
            )
        ]
    );
    mt_run = mk_run(resp_type=_Person, stream=True, finish=True);
    list(llm._stream_final_answer(mt_run));
    return mt_run;
}


def _recovery_case -> MTRuntime {
    llm = MockLLM(
        model_name="test-model",
        outputs=[
            call(
                "finish_tool",
                {"output": {"name": "Gus", "age": 29}},
                usage={"prompt_tokens": 15, "completion_tokens": 3, "total_tokens": 18}
            )
        ]
    );
    mt_run = mk_run(resp_type=_Person, finish=True);
    llm._attempt_recovery(mt_run);
    return mt_run;
}


def _compaction_case -> MTRuntime {
    sys_msg = {"role": "system", "content": "You are a helpful assistant."};
    user_msg = {"role": "user", "content": "Do the thing."};
    round1 = [
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call_1",
                    "function": {"name": "search", "arguments": '{"q":"a"}'}
                }
            ]
        },
        {
            "role": "tool",
            "content": "result_1",
            "tool_call_id": "call_1",
            "name": "search"
        }
    ];
    messages = [sys_msg, user_msg] + round1 + round1 + round1;

    summariser = MockLLM(
        model_name="test-model",
        outputs=[
            (
                "a summary",
                {"prompt_tokens": 200, "completion_tokens": 20, "total_tokens": 220}
            )
        ]
    );
    parent_mt = mk_run();
    _byllm_llm_mod._default_compact(messages, 1, summariser, parent_mt);
    return parent_mt;
}


test "byLLM's own follow-up calls get a call_kind distinct from react_iteration" {
    cases = [
        ("final_answer_restream", _restream_case),
        ("recovery", _recovery_case),
        ("compaction", _compaction_case)
    ];
    for (expected_kind, run) in cases {
        mt_run = run();
        assert len(mt_run._usage_history) == 1 , (
            f"{expected_kind}: expected exactly one recorded call"
        );
        assert mt_run._usage_history[0]["call_kind"] == expected_kind;
        assert mt_run._call_kind == "react_iteration" , (
            f"{expected_kind}: call_kind override must reset after the call"
        );
    }
}


test "usage StreamEvent always terminates a logging=True stream, even with no usage data" {
    llm = MockLLM(outputs=["hello there"]);

    def my_task(q: str) -> str by llm(stream=True, logging=True);

    events = list(my_task("test"));
    assert events , "expected at least the usage event";
    assert events[-1].event_type == "usage" , (
        f"usage must be the last event even with no measurable tokens, got "
        f"{events[-1].event_type}"
    );
    assert events[-1].data["requests"] == 1 , (
        "the call still happened even though it reported no usage - it must "
        "be counted, not silently dropped"
    );
    assert len(events[-1].data["per_call"]) == 1;
    assert events[-1].data["total"].get("total_tokens", 0) == 0;
}


test "cache token fields are normalized onto every recorded call, regardless of provider shape" {
    mt = mk_run();

    # Anthropic-shaped: cache fields already top-level.
    _byllm_llm_mod._record_usage(
        mt,
        {
            "prompt_tokens": 100,
            "completion_tokens": 10,
            "total_tokens": 110,
            "cache_read_input_tokens": 40,
            "cache_creation_input_tokens": 15
        },
        "claude-sonnet-4-5"
    );

    # OpenAI-shaped: cache reads only nested under prompt_tokens_details, no
    # cache-creation concept at all.
    _byllm_llm_mod._record_usage(
        mt,
        {
            "prompt_tokens": 200,
            "completion_tokens": 20,
            "total_tokens": 220,
            "prompt_tokens_details": {"cached_tokens": 60}
        },
        "gpt-4o-mini"
    );

    # No cache concept whatsoever.
    _byllm_llm_mod._record_usage(
        mt,
        {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55},
        "some-model"
    );

    assert len(mt._usage_history) == 3;

    anthropic_rec = mt._usage_history[0];
    assert anthropic_rec["cache_read_input_tokens"] == 40;
    assert anthropic_rec["cache_creation_input_tokens"] == 15;

    openai_rec = mt._usage_history[1];
    assert openai_rec["cache_read_input_tokens"] == 60 , (
        "cache_read_input_tokens must be normalized from the nested "
        "prompt_tokens_details.cached_tokens when no top-level field exists"
    );
    assert openai_rec["cache_creation_input_tokens"] == 0 , (
        "a provider with no cache-creation concept must report 0, not be "
        "missing the key entirely"
    );

    bare_rec = mt._usage_history[2];
    assert bare_rec["cache_read_input_tokens"] == 0;
    assert bare_rec["cache_creation_input_tokens"] == 0;
}


# =============================================================================
# Per-call usage exposure during a streaming ReAct loop
# =============================================================================
# `usage` only fires once, after the whole invocation finishes. `usage_step`
# fires once per individual call instead, reusing the exact `usage` shape.

test "usage_step fires once per underlying call, scoped to that call's own usage" {
    llm = MockLLM(
        outputs=[
            (
                MockToolCall(tool=step_a, args={}),
                {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
            ),
            (
                MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                {"prompt_tokens": 200, "completion_tokens": 20, "total_tokens": 220}
            ),
            # A str-returning finish_tool call always triggers a
            # final_answer_restream - the 3rd underlying call.
            (
                "done",
                {"prompt_tokens": 300, "completion_tokens": 30, "total_tokens": 330}
            )
        ]
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    events = list(task("go"));
    usage_steps = [e.data for e in events_of(events, "usage_step")];
    finals = [e.data for e in events_of(events, "usage")];
    final_usage: dict[str, any] | None = finals[-1] if finals else None;

    assert len(usage_steps) == 3 , (
        f"expected one usage_step per underlying call, got {len(usage_steps)}"
    );
    assert usage_steps[0]["total"]["total_tokens"] == 110;
    assert usage_steps[0]["per_call"][0]["call_kind"] == "react_iteration";
    assert usage_steps[1]["total"]["total_tokens"] == 220 , (
        "each usage_step must carry only its own call's usage, not a running "
        "cumulative sum"
    );
    assert usage_steps[2]["total"]["total_tokens"] == 330;
    assert usage_steps[2]["per_call"][0]["call_kind"] == "final_answer_restream" , (
        "the restream is its own call and gets its own usage_step"
    );
    assert final_usage is not None;
    assert set(usage_steps[0].keys()) == set(final_usage.keys()) , (
        "usage_step must reuse the exact usage event shape so both can be "
        "parsed with the same code"
    );
    summed_tokens = sum(step["total"].get("total_tokens", 0) for step in usage_steps);
    assert summed_tokens == final_usage["total"]["total_tokens"] , (
        "summing every usage_step must equal the final usage total, or a "
        "caller tracking spend via usage_step alone would drift from it"
    );
}


test "usage_step correctly attributes an interleaved compaction call" {
    # Default compaction summarises on a copy of the model that shares its reply
    # queue, so the summary is queued right after the call that crosses the
    # threshold.
    llm = MockLLM(
        model_name="test-model",
        ctx_window=1000,
        outputs=[
            call(
                "step_a",
                usage={
                    "prompt_tokens": 100,
                    "completion_tokens": 10,
                    "total_tokens": 110
                }
            ),
            call(
                "step_a",
                usage={
                    "prompt_tokens": 850,
                    "completion_tokens": 10,
                    "total_tokens": 860
                }
            ),
            say(
                "a summary",
                usage={
                    "prompt_tokens": 300,
                    "completion_tokens": 40,
                    "total_tokens": 340
                }
            ),
            finish(
                "done",
                usage={"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
            ),
            say("done")
        ]
    );

    def task(q: str) -> str by llm(
        tools=[step_a],
        stream=True,
        logging=True,
        threshold_ratio=0.80,
        keep_recent_iterations=1
    );

    steps = [e.data for e in events_of(list(task("go")), "usage_step")];
    assert llm.exhausted() , f"the summary was never requested: {llm.outputs}";
    compacted = [
        step
        for step in steps
        if "compaction" in [c["call_kind"] for c in step["per_call"]]
    ];
    assert len(compacted) == 1 , (
        f"exactly one usage_step should cover the compaction call, got {steps}"
    );
    kinds = [c["call_kind"] for c in compacted[0]["per_call"]];
    assert kinds == ["react_iteration", "compaction"] , (
        f"the usage_step covering the iteration where compaction fired must hold "
        f"the react call and the compaction call, got call_kinds={kinds}"
    );
    assert compacted[0]["total"]["total_tokens"] == 860 + 340 , (
        "the usage_step must sum both the react call and the interleaved "
        "compaction call, not just one of them"
    );
}


test "usage_step fires for the recovery call" {
    # A text answer that cannot become a _Person is recovered by a forced
    # finish_tool call; that episode reports its own usage_step.
    llm = MockLLM(
        model_name="test-model",
        outputs=[
            say("not a person"),
            call(
                "finish_tool",
                {"output": {"name": "Gus", "age": 29}},
                usage={"prompt_tokens": 40, "completion_tokens": 8, "total_tokens": 48}
            ),
            say("Gus")
        ]
    );
    mt_run = mk_run(resp_type=_Person, tools=[step_a], stream=True);

    steps = [
        e.data for e in events_of(list(llm._invoke_streaming(mt_run)), "usage_step")
    ];
    assert llm.exhausted() , f"recovery never ran: {llm.outputs}";
    assert len(steps) == 1 , f"the recovery episode must report one usage_step: {steps}";
    kinds = [c["call_kind"] for c in steps[0]["per_call"]];
    assert kinds == ["recovery", "final_answer_restream"] , (
        f"the usage_step must cover the recovery call, got call_kinds={kinds}"
    );
    assert steps[0]["total"]["total_tokens"] == 48;
}


test "usage_step does not fire for the no-tools branch" {
    llm = MockLLM(
        outputs=[
            (
                "hello there",
                {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7}
            )
        ]
    );

    def task(q: str) -> str by llm(stream=True, logging=True);

    event_types: list[any] = [];
    events = list(task("go"));
    for event in events {
        event_types.append(event.event_type);
    }

    assert "usage_step" not in event_types , (
        "a single-call invocation has nothing to distinguish a per-call step "
        "from the final aggregate; usage_step must not duplicate it"
    );
    assert event_types.count("usage") == 1;
}


test "_usage_history_total_cost sums real cost across recorded calls" {
    mt = mk_run(stream=True);
    mt._usage_history = [
        {"call_kind": "react_iteration", "total_tokens": 100, "cost": 0.001},
        {"call_kind": "react_iteration", "total_tokens": 50, "cost": 0.0005},
        {"call_kind": "compaction", "total_tokens": 300}
    ];

    total = _byllm_llm_mod._usage_history_total_cost(mt);
    assert abs(total - 0.0015) < 1e-12 , (
        f"expected cost-bearing entries summed and missing-cost entries "
        f"treated as 0, got {total}"
    );
}


test "on_iteration's IterationContext exposes real cumulative total_cost" {
    llm = MockLLM(
        outputs=[
            (
                MockToolCall(tool=step_a, args={}),
                {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
            ),
            (
                MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
            ),
            "done"
        ]
    );

    seen_contexts: list[IterationContext] = [];
    def hook(ctx: IterationContext) -> str {
        seen_contexts.append(ctx);
        return "continue";
    }

    def task(q: str) -> str by llm(
        tools=[step_a], stream=True, logging=True, on_iteration=hook
    );

    for event in task("go") {}

    assert len(seen_contexts) >= 1 , "on_iteration should have fired before iteration 2";
    ctx = seen_contexts[0];
    assert ctx.total_tokens == 110 , (
        f"total_tokens should reflect the real first call, got {ctx.total_tokens}"
    );
    # MockLLM's default model name has no price, so 0.0 is the honest expectation
    # here; the summation itself is exercised with real costs elsewhere above.
    assert ctx.total_cost == 0.0 , (
        f"total_cost should reflect real recorded cost (none here), got {ctx.total_cost}"
    );
}


test "llm_timing no longer duplicates token counts now that usage_step exists" {
    llm = MockLLM(
        outputs=[
            (
                MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                {"prompt_tokens": 100, "completion_tokens": 10, "total_tokens": 110}
            ),
            "done"
        ]
    );

    def task(q: str) -> str by llm(tools=[step_a], stream=True, logging=True);

    timing_events = [e.data for e in events_of(list(task("go")), "llm_timing")];

    assert len(timing_events) == 1;
    assert set(timing_events[0].keys()) == {"duration_ms", "iteration"} , (
        f"llm_timing should carry only timing data now that usage_step covers "
        f"token/cost per call, got keys={list(timing_events[0].keys())}"
    );
}
