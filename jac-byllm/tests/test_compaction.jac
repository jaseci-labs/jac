"""Integration tests for the byLLM auto-compaction feature."""

import from unittest { mock }
import os;
import litellm;

import byllm.llm as _byllm_llm_mod;
import from byllm.lib { Model, ModelPool, MockLLM }
import from byllm.types { MockToolCall, CompletionResult }
import from byllm.exceptions { CompactionNotEffectiveError, ConfigurationError }
import from byllm.config_loader { reset_byllm_config, get_byllm_config }
import from byllm.mtir { MTRuntime }
import from pathlib { Path }


glob FIXTURE_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "fixtures"
);
glob COMPACTION_TOML_FIXTURE = os.path.join(FIXTURE_DIR, "compaction_config");


# ---------------------------------------------------------------------------
# T1. Above threshold → compaction runs end-to-end through `by llm()`,
#     replaces mt_run.messages, and the next iteration sees the shortened
#     list. Uses a custom on_compaction hook (instead of the default
#     compactor) because MockLLM.dispatch_no_streaming adds the assistant
#     message as a literal string, which _default_compact's role-detection
#     code cannot recognise as "assistant" - so the default compactor's
#     slice ends up empty against MockLLM-produced histories. Structural
#     correctness of _default_compact is verified separately in T1_struct.
# ---------------------------------------------------------------------------
test "above threshold compacts and next iteration sees shortened messages" {
    def step_a -> str { return "stepped"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),  # iter 1: no fire
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),  # iter 2: 85% → fire
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})  # iter 3: finish
        ]}
    );

    hook_call_count = [0];
    def shrinking_hook(msgs: list, keep_recent: int) -> list {
        hook_call_count[0] += 1;
        # Returning [system, user] is the most aggressive valid compaction.
        # Subsequent assistant/tool messages get re-appended by the loop, so
        # iter 3's mt_run will be [sys, user, ass_2, tool_2] = 4 messages.
        return [msgs[0], msgs[1]];
    }

    iter_msgs: list = [];
    original_dispatch = llm.dispatch_no_streaming;
    def capturing_dispatch(mt_run: MTRuntime) -> CompletionResult {
        iter_msgs.append(len(mt_run.get_msg_list()));
        return original_dispatch(mt_run);
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=shrinking_hook
    );

    with mock.patch.object(llm, "dispatch_no_streaming", capturing_dispatch) {
        result = my_task("test");
    }

    assert result == "ok" , f"Expected 'ok', got {result!r}";
    assert hook_call_count[0] == 1 ,
        f"Hook should be called exactly once at the iter-2 trigger, got {hook_call_count[0]}";
    # iter 1: pre-dispatch mt_run = [sys, user] = 2.
    # iter 2: pre-dispatch mt_run = [sys, user, ass_1, tool_1] = 4 (no compact yet).
    # iter 3: hook collapsed mt_run to [sys, user] after threshold fired,
    #         then loop appended iter-2 tool result = [sys, user, tool_2] = 3
    #         (proves compaction REPLACED messages: without compaction we'd be at 6).
    assert iter_msgs == [2, 4, 3] ,
        f"Expected [2, 4, 3] (compaction shrinks iter 3 from 6 to 3), got {iter_msgs}";
}


# ---------------------------------------------------------------------------
# T1_struct. Default compactor structural correctness.
#     Calls _default_compact directly with hand-built dict messages (the
#     pipeline test above can't exercise this because MockLLM produces
#     string assistant messages). Asserts: system + user task preserved
#     verbatim, summary user msg with sentinel + summary text,
#     keep_recent assistant rounds preserved with intact tool-call IDs.
# ---------------------------------------------------------------------------
test "default compactor produces system user summary and kept-tail structure" {
    sys_msg = {"role": "system", "content": "You are a helpful assistant."};
    user_msg = {"role": "user", "content": "Do the thing."};
    def make_round(idx: int) -> list {
        return [
            {
                "role": "assistant", "content": None,
                "tool_calls": [{
                    "id": f"call_{idx}",
                    "function": {"name": "search", "arguments": f'{{"q":"q{idx}"}}'}
                }]
            },
            {"role": "tool", "content": f"result_{idx}", "tool_call_id": f"call_{idx}", "name": "search"}
        ];
    }

    messages = [sys_msg, user_msg] + make_round(1) + make_round(2) + make_round(3);
    summary_text = "Steps 1, 2, and 3 searched for q1/q2/q3.";
    summariser = MockLLM(model_name="mockllm", config={"outputs": [summary_text]});

    result: list = list(_byllm_llm_mod._default_compact(messages, 1, summariser));

    # Expected shape: [sys, user, summary_msg, ass_3, tool_3]
    assert len(result) == 5 , f"Expected 5 messages, got {len(result)}: {result}";
    assert result[0] is sys_msg , "system message must be preserved by reference";
    assert result[1] is user_msg , "user task must be preserved by reference";
    assert result[2]["role"] == "user" , f"summary msg must have role=user, got {result[2]}";
    assert "[Compacted context summary]" in result[2]["content"] ,
        f"Summary sentinel missing, got: {result[2]['content']}";
    assert summary_text in result[2]["content"] ,
        f"Summary text missing, got: {result[2]['content']}";
    assert result[3]["role"] == "assistant" ,
        f"result[3] should be the kept assistant, got {result[3]}";
    assert result[3]["tool_calls"][0]["id"] == "call_3" ,
        f"Kept assistant's tool_call id should match round 3, got {result[3]}";
    assert result[4]["role"] == "tool" and result[4]["tool_call_id"] == "call_3" ,
        f"result[4] should be the matching tool result, got {result[4]}";
}


# ---------------------------------------------------------------------------
# T2. Below threshold → no compaction; outputs queue does not need a summary.
# ---------------------------------------------------------------------------
test "below threshold does not trigger compaction" {
    def step_a -> str { return "stepped"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
             {"prompt_tokens": 100})
        ]}
    );

    def my_task(q: str) -> str by llm(tools=[step_a], threshold_ratio=0.80);
    result = my_task("test");

    # If compaction had fired, _default_compact would have tried to pop a
    # summary that doesn't exist → IndexError. Successful completion + empty
    # queue prove no compaction ran.
    assert result == "ok" , f"Expected 'ok', got {result!r}";
    assert llm.config["outputs"] == [] ,
        f"Outputs queue should be empty, got {llm.config['outputs']}";
}


# ---------------------------------------------------------------------------
# T3a. Priority: call_params["ctx_window"] beats self.ctx_window.
#      Setup: self.ctx_window=10000 (would not fire at 850 → 8.5%),
#             call_params=1000 (would fire at 850 → 85%).
#      Compaction firing proves call_params won.
# ---------------------------------------------------------------------------
test "ctx_window priority - call_params beats self.ctx_window" {
    reset_byllm_config();
    def step_a -> str { return "a"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=10000,
        config={"outputs": [
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
        ]}
    );

    compaction_fired = [False];
    def hook(msgs: list, keep_recent: int) -> list {
        compaction_fired[0] = True;
        return msgs[:2];
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], ctx_window=1000, threshold_ratio=0.80, on_compaction=hook
    );

    my_task("test");
    assert compaction_fired[0] ,
        "Compaction should fire because call_params ctx_window=1000 beats self.ctx_window=10000";
}


# ---------------------------------------------------------------------------
# T3b. Priority: self.ctx_window beats jac.toml [compaction].ctx_window.
#      Tested at the _get_ctx_window function level (not via `by llm()`)
#      because MTRuntime.factory calls find_project_root(caller_file.parent),
#      which walks past our fixture and finds the outer jaseci/jac.toml -
#      stomping our cached fixture config. The full-pipeline integration
#      that the loop USES _get_ctx_window's result is covered by T3a + T3d.
# ---------------------------------------------------------------------------
test "ctx_window priority - self.ctx_window beats jac.toml" {
    reset_byllm_config();
    get_byllm_config(Path(COMPACTION_TOML_FIXTURE));
    try {
        # Sanity: confirm fixture is actually loaded with ctx_window=10000.
        loaded = get_byllm_config().get_compaction_config();
        assert loaded["ctx_window"] == 10000 ,
            f"Fixture should set ctx_window=10000, got {loaded}";

        llm = MockLLM(model_name="mockllm", ctx_window=1000);
        result = llm._get_ctx_window({});
        assert result == 1000 ,
            f"self.ctx_window=1000 must beat jac.toml=10000, got {result}";
    } finally {
        reset_byllm_config();
    }
}


# ---------------------------------------------------------------------------
# T3c. Priority: jac.toml [compaction].ctx_window beats litellm registry.
#      Same caveat as T3b - tested at the _get_ctx_window level.
# ---------------------------------------------------------------------------
test "ctx_window priority - jac.toml beats litellm" {
    reset_byllm_config();
    get_byllm_config(Path(COMPACTION_TOML_FIXTURE));
    try {
        # gpt-4o-mini's litellm registry value is 128000; our fixture is 10000.
        # No self.ctx_window override on the model (default 0).
        llm = MockLLM(model_name="gpt-4o-mini");
        result = llm._get_ctx_window({});
        assert result == 10000 ,
            f"jac.toml=10000 must beat litellm=128000 for gpt-4o-mini, got {result}";
    } finally {
        reset_byllm_config();
    }
}


# ---------------------------------------------------------------------------
# T3d. Fallback: unknown model + no override → ctx_window=0 → threshold check
#      is disabled (`if comp_enabled and ctx_window > 0`). High prompt_tokens
#      must NOT fire compaction.
# ---------------------------------------------------------------------------
test "ctx_window fallback - unknown model with no override disables threshold" {
    reset_byllm_config();
    def step_a -> str { return "a"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="definitely-not-a-real-model-zzz",
        config={"outputs": [
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
             {"prompt_tokens": 999_999})
        ]}
    );

    compaction_fired = [False];
    def hook(msgs: list, keep_recent: int) -> list {
        compaction_fired[0] = True;
        return msgs[:2];
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=hook
    );

    result = my_task("test");
    assert result == "ok" , f"Expected 'ok', got {result!r}";
    assert not compaction_fired[0] ,
        "Compaction must NOT fire when ctx_window resolves to 0 (unknown model, no override)";
}


# ---------------------------------------------------------------------------
# T4. compaction_enabled=False suppresses BOTH the proactive threshold path
#     AND the emergency ContextWindowExceededError path.
# ---------------------------------------------------------------------------
test "compaction_enabled false suppresses proactive and emergency paths" {
    def step_a -> str { return "a"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    # --- Sub-assert 1: above threshold but disabled - no compaction.
    llm1 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
             {"prompt_tokens": 950})
        ]}
    );

    proactive_fired = [False];
    def hook1(msgs: list, keep_recent: int) -> list {
        proactive_fired[0] = True;
        return msgs[:2];
    }

    def task1(q: str) -> str by llm1(
        tools=[step_a],
        threshold_ratio=0.80,
        compaction_enabled=False,
        on_compaction=hook1
    );

    assert task1("test") == "ok" , "task1 should complete";
    assert not proactive_fired[0] ,
        "Proactive compaction must NOT fire when compaction_enabled=False";

    # --- Sub-assert 2: ContextWindowExceededError must propagate, no retry.
    llm2 = MockLLM(model_name="mockllm", config={"outputs": []});

    call_count = [0];
    def fake_raises(mt_run: MTRuntime) -> CompletionResult {
        call_count[0] += 1;
        raise litellm.exceptions.ContextWindowExceededError(
            message="ctx", model="mockllm", llm_provider="openai"
        );
    }

    def task2(q: str) -> str by llm2(tools=[step_a], compaction_enabled=False);

    raised = False;
    with mock.patch.object(llm2, "dispatch_no_streaming", fake_raises) {
        try {
            task2("test");
        } except litellm.exceptions.ContextWindowExceededError {
            raised = True;
        }
    }
    assert raised ,
        "ContextWindowExceededError must propagate when compaction_enabled=False";
    assert call_count[0] == 1 ,
        f"Should not retry when compaction is disabled, got {call_count[0]} calls";
}


# ---------------------------------------------------------------------------
# T5. ContextWindowExceededError → emergency compact → retry succeeds.
#     Patched dispatch raises on the first outer call, then defers to the
#     real MockLLM popper. We use a custom on_compaction hook here (rather
#     than the default compactor) because at the moment of the first dispatch
#     mt_run has only [system, user] = 2 messages, too few for the default
#     compactor's slice to be non-empty. The hook lets us assert that the
#     emergency path: (a) catches the exception, (b) calls compaction, (c)
#     retries the dispatch.
# ---------------------------------------------------------------------------
test "ContextWindowExceededError triggers emergency compaction and retries" {
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="mockllm",
        config={"outputs": [
            (MockToolCall(tool=finish_tool, args={"final_output": "recovered"}), {})
        ]}
    );

    hook_called = [False];
    def hook(msgs: list, keep_recent: int) -> list {
        hook_called[0] = True;
        return msgs[:2];  # no-op when mt_run already has 2 messages
    }

    original_dispatch = llm.dispatch_no_streaming;
    outer_call_count = [0];
    def fake_dispatch(mt_run: MTRuntime) -> CompletionResult {
        outer_call_count[0] += 1;
        if outer_call_count[0] == 1 {
            raise litellm.exceptions.ContextWindowExceededError(
                message="ctx exceeded", model="mockllm", llm_provider="openai"
            );
        }
        return original_dispatch(mt_run);
    }

    def my_task(q: str) -> str by llm(tools=[], on_compaction=hook);

    with mock.patch.object(llm, "dispatch_no_streaming", fake_dispatch) {
        result = my_task("test");
    }

    assert hook_called[0] ,
        "on_compaction hook must be invoked by the emergency compaction path";
    assert result == "recovered" ,
        f"Expected 'recovered' after compact+retry, got {result!r}";
    # 1 raise + 1 retry = 2 outer dispatches. Hook bypasses the default
    # compactor, so no inner summarisation dispatch.
    assert outer_call_count[0] == 2 ,
        f"Expected 2 dispatches (raise + retry), got {outer_call_count[0]}";
    assert llm.config["outputs"] == [] ,
        f"Outputs queue should be empty, got {llm.config['outputs']}";
}


# ---------------------------------------------------------------------------
# T6. CompactionNotEffectiveError when compaction produces no reduction.
#     Need ≥4 messages at trigger time so the `removed == 0 and >= 4` guard
#     in _compact_messages fires. We arrange for trigger to happen on iter 2
#     (mt_run has 5 messages by then) and use a no-op hook that returns the
#     same list unchanged → removed=0 → error.
# ---------------------------------------------------------------------------
test "compaction with no reduction raises CompactionNotEffectiveError" {
    def step_a -> str { return "a"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),  # iter 1: no fire
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900})   # iter 2: fire, no reduce
        ]}
    );

    def noop_hook(msgs: list, keep_recent: int) -> list {
        return msgs;  # same length - cannot reduce
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=noop_hook
    );

    raised = False;
    try {
        my_task("test");
    } except CompactionNotEffectiveError as e {
        raised = True;
        msg = str(e);
        assert "no reduction" in msg ,
            f"Error should explain why compaction failed, got: {msg}";
    }
    assert raised , "Expected CompactionNotEffectiveError when compaction has no effect";
}


# ---------------------------------------------------------------------------
# T7. ConfigurationError when on_compaction returns invalid types.
#     Three cases (None, [], dict) - all should raise ConfigurationError.
#     The hook is invoked at iter 1 (mt_run=3, msg_dicts=3) - the validation
#     fires before the >=4 length check, so 3-message setup is fine here.
# ---------------------------------------------------------------------------
test "on_compaction hook returning invalid types raises ConfigurationError" {
    def step_a -> str { return "a"; }

    # Build a fresh llm + run my_task with the given hook, return the exception
    # (or None if no exception was raised).
    def run_with_hook(hook: object) -> object {
        llm = MockLLM(
            model_name="mockllm",
            ctx_window=1000,
            config={"outputs": [
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900})
            ]}
        );

        def my_task(q: str) -> str by llm(
            tools=[step_a], threshold_ratio=0.80, on_compaction=hook
        );

        try {
            my_task("test");
        } except ConfigurationError as e {
            return e;
        } except Exception as other {
            return other;
        }
        return None;
    }

    # Case 1: returns None
    def hook_none(msgs: list, keep_recent: int) -> object {
        return None;
    }
    e1 = run_with_hook(hook_none);
    assert isinstance(e1, ConfigurationError) ,
        f"hook returning None must raise ConfigurationError, got {type(e1).__name__}: {e1}";
    assert "on_compaction hook" in str(e1) , f"Error should name the hook, got: {e1}";

    # Case 2: returns empty list
    def hook_empty(msgs: list, keep_recent: int) -> list {
        return [];
    }
    e2 = run_with_hook(hook_empty);
    assert isinstance(e2, ConfigurationError) ,
        f"hook returning [] must raise ConfigurationError, got {type(e2).__name__}: {e2}";
    assert "at least 2 messages" in str(e2) ,
        f"Error should mention minimum length, got: {e2}";

    # Case 3: returns a dict (not a list)
    def hook_dict(msgs: list, keep_recent: int) -> object {
        return {"role": "user", "content": "wrong shape"};
    }
    e3 = run_with_hook(hook_dict);
    assert isinstance(e3, ConfigurationError) ,
        f"hook returning a dict must raise ConfigurationError, got {type(e3).__name__}: {e3}";
}


# ---------------------------------------------------------------------------
# T8. Streaming path (`stream=True, logging=True` → _invoke_streaming) must
#     respect the same threshold-trigger and disable-switch as invoke().
# ---------------------------------------------------------------------------
test "streaming path triggers compaction and respects compaction_enabled" {
    def step_a -> str { return "stepped"; }
    def finish_tool(final_output: str) -> str { return final_output; }

    # --- Sub-assert 1: streaming triggers compaction at threshold.
    llm1 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
            (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {}),
            "done"  # popped by dispatch_streaming for the final answer
        ]}
    );

    fired1 = [False];
    def hook1(msgs: list, keep_recent: int) -> list {
        fired1[0] = True;
        return msgs[:2];
    }

    def task1(q: str) -> str by llm1(
        tools=[step_a],
        stream=True,
        logging=True,
        threshold_ratio=0.80,
        on_compaction=hook1
    );

    for event in task1("test") { }  # drain the generator
    assert fired1[0] , "Streaming path must trigger compaction at threshold";

    # --- Sub-assert 2: streaming with compaction_enabled=False skips threshold.
    llm2 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={"outputs": [
            (MockToolCall(tool=finish_tool, args={"final_output": "done"}),
             {"prompt_tokens": 950}),
            "done"
        ]}
    );

    fired2 = [False];
    def hook2(msgs: list, keep_recent: int) -> list {
        fired2[0] = True;
        return msgs[:2];
    }

    def task2(q: str) -> str by llm2(
        tools=[step_a],
        stream=True,
        logging=True,
        threshold_ratio=0.80,
        compaction_enabled=False,
        on_compaction=hook2
    );

    for event in task2("test") { }
    assert not fired2[0] ,
        "Streaming path must NOT trigger compaction when compaction_enabled=False";
}


# ---------------------------------------------------------------------------
# T9. ModelPool ctx_window resolution. Driven directly through
#     pool._get_ctx_window() because ModelPool routes through the LiteLLM
#     Router (no MockLLM seam at the pool level), and the integration we
#     care about here - "pool's override beats min-of-members" - is purely
#     about ctx_window resolution, not about the ReAct/threshold loop.
# ---------------------------------------------------------------------------
test "ModelPool ctx_window override beats min of members" {
    reset_byllm_config();
    a = Model(model_name="gpt-4o", ctx_window=128000);
    b = Model(model_name="gpt-3.5-turbo", ctx_window=16000);

    pool_min = ModelPool(models=[a, b]);
    assert pool_min._get_ctx_window({}) == 16000 ,
        "Pool without override must return min of member ctx_windows";

    pool_override = ModelPool(models=[a, b], ctx_window=200000);
    assert pool_override._get_ctx_window({}) == 200000 ,
        "Pool with explicit ctx_window must override member minimum";

    assert pool_override._get_ctx_window({"ctx_window": 500}) == 500 ,
        "call_params ctx_window must beat pool's own override";
}
