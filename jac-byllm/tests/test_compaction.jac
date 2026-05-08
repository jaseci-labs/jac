"""Tests for the auto-compaction feature (byllm/llm.impl/basellm.impl.jac).

Covers:
  1.  _litellm_ctx_window: known model returns value, unknown returns 0
  2.  _get_ctx_window: call_params wins over self.ctx_window
  3.  _get_ctx_window: self.ctx_window wins over jac.toml config
  4.  _get_ctx_window: jac.toml config wins over litellm auto-detect
  5.  _get_ctx_window: returns 0 when all sources unknown
  6.  _default_compact: too-few messages returns list unchanged
  7.  _default_compact: correct structure - system+user+summary+kept tail
  8.  _default_compact: keep_recent respects N assistant rounds in tail
  9.  _default_compact: litellm.completion failure returns list unchanged
  10. _compact_messages: custom on_compaction hook is called
  11. _compact_messages: hook return value replaces mt_run.messages
  12. _compact_messages: default path used when no hook provided
  13. invoke: threshold triggers compaction when prompt_tokens >= ratio
  14. invoke: compaction NOT triggered when below threshold
  15. invoke: compaction_enabled=False suppresses threshold trigger
  16. invoke: CompactionNotEffectiveError on consecutive threshold triggers
  17. invoke: _just_compacted resets after a below-threshold iteration
  18. invoke: ContextWindowExceededError triggers emergency compact + retry
  19. invoke: on_compaction hook wired through invoke() end-to-end
  20. ModelPool._get_ctx_window: explicit override wins over member minimum
  21. ModelPool._get_ctx_window: returns min of pool members when no override
"""

import unittest.mock;
import os;
import types;

import byllm.llm as _byllm_llm_mod;
import from byllm.lib { Model, ModelPool, MockLLM }
import from byllm.llm { BaseLLM }
import from byllm.mtir { MTRuntime }
import from byllm.types { Tool, MockToolCall, Message, MessageRole, CompletionResult }
import from byllm.exceptions { CompactionNotEffectiveError, ConfigurationError }
import from byllm.config_loader { reset_byllm_config, get_byllm_config }
import litellm;


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
"""Build a minimal MTRuntime with a fixed message list and a finish_tool."""
def _make_mt_run(extra_messages: list = [], call_params: dict = {}) -> MTRuntime {
    finish_tool = Tool.make_finish_tool(str);
    messages: list = [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Do something."},
        *extra_messages
    ];
    return MTRuntime(
        messages=messages,
        tools=[finish_tool],
        resp_type=str,
        stream=False,
        call_params=call_params,
        mtir=None
    );
}

"""Build a full assistant+tool_result round as plain dicts."""
def _make_round(index: int) -> list {
    return [
        {
            "role": "assistant",
            "content": f"Thinking about step {index}.",
            "tool_calls": [
                {
                    "id": f"call_{index}",
                    "function": {"name": "search", "arguments": "{}"}
                }
            ]
        },
        {
            "role": "tool",
            "content": f"Result of step {index}.",
            "tool_call_id": f"call_{index}",
            "name": "search"
        }
    ];
}


# ---------------------------------------------------------------------------
# 1-5. _get_ctx_window priority chain
# ---------------------------------------------------------------------------
test "_litellm_ctx_window returns positive for known model" {
    with unittest.mock.patch(
        "litellm.get_model_info", return_value={"max_input_tokens": 128000}
    ) {
        result = _byllm_llm_mod._litellm_ctx_window("gpt-4o");
        assert result == 128000 , f"Expected 128000, got {result}";
    }
}

test "_litellm_ctx_window returns 0 for unknown model" {
    with unittest.mock.patch(
        "litellm.get_model_info", side_effect=Exception("unknown model")
    ) {
        result = _byllm_llm_mod._litellm_ctx_window("my-custom-model");
        assert result == 0 , f"Expected 0, got {result}";
    }
}

test "_get_ctx_window call_params override wins over self.ctx_window" {
    model = Model(model_name="gpt-4o", ctx_window=32000);
    result = model._get_ctx_window({"ctx_window": 99000});
    assert result == 99000 , f"Expected call_params override 99000, got {result}";
}

test "_get_ctx_window self.ctx_window wins over config and litellm" {
    reset_byllm_config();
    with unittest.mock.patch(
        "litellm.get_model_info", return_value={"max_input_tokens": 8000}
    ) {
        model = Model(model_name="gpt-4o", ctx_window=64000);
        result = model._get_ctx_window({});
        assert result == 64000 , f"Expected self.ctx_window=64000, got {result}";
    }
}

test "_get_ctx_window falls back to litellm when no explicit override" {
    reset_byllm_config();
    model = Model(model_name="gpt-4o");
    with unittest.mock.patch(
        "litellm.get_model_info", return_value={"max_input_tokens": 128000}
    ) {
        result = model._get_ctx_window({});
        assert result == 128000 , f"Expected litellm-detected 128000, got {result}";
    }
}

test "_get_ctx_window returns 0 when all sources unknown" {
    reset_byllm_config();
    model = Model(model_name="my-mystery-model");
    with unittest.mock.patch(
        "litellm.get_model_info", side_effect=Exception("unknown")
    ) {
        result = model._get_ctx_window({});
        assert result == 0 , f"Expected 0 for fully unknown model, got {result}";
    }
}


# ---------------------------------------------------------------------------
# 6-9. _default_compact slicing logic
# ---------------------------------------------------------------------------
test "_default_compact too few messages returns list unchanged" {
    messages = [
        {"role": "system", "content": "sys"},
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": "hey"}
    ];
    mock_model = MockLLM(model_name="mockllm", config={"outputs": ["summary"]});
    result = _byllm_llm_mod._default_compact(messages, 3, mock_model);
    assert result == messages , "Expected unchanged list for short message history";
}

test "_default_compact produces system user summary and kept tail" {
    summary_text = "Steps 1 and 2 were completed.";
    messages = (
        [{"role": "system", "content": "sys"}, {"role": "user", "content": "task"}] + _make_round(
            1
        ) + _make_round(2) + _make_round(3)
    );
    # MockLLM pops outputs sequentially - one output for the summarisation call
    mock_model = MockLLM(model_name="mockllm", config={"outputs": [summary_text]});
    result = _byllm_llm_mod._default_compact(messages, 1, mock_model);
    assert result[0]["role"] == "system" , "messages[0] must stay as system";
    assert result[1]["role"] == "user" , "messages[1] must stay as user task";
    assert result[2]["role"] == "user" , "messages[2] must be the summary message";
    assert "[Compacted context summary]" in result[2]["content"] , (
        f"Summary sentinel missing. Got: {result[2]['content']}"
    );
    assert summary_text in result[2]["content"] , (
        f"Summary text missing. Got: {result[2]['content']}"
    );
    assert result[-1]["role"] == "tool" , "Last message in tail should be a tool result";
}

test "_default_compact keep_recent 2 preserves exactly 2 assistant rounds in tail" {
    summary_text = "summarised";
    messages = (
        [{"role": "system", "content": "sys"}, {"role": "user", "content": "task"}] + _make_round(
            1
        ) + _make_round(2) + _make_round(3) + _make_round(4)
    );
    mock_model = MockLLM(model_name="mockllm", config={"outputs": [summary_text]});
    result = _byllm_llm_mod._default_compact(messages, 2, mock_model);
    tail = result[3:];
    assistant_count = sum(
        1
        for m in tail
        if m.get("role") == "assistant"
    );
    assert assistant_count == 2 , (
        f"Expected 2 assistant rounds in tail with keep_recent=2, got {assistant_count}"
    );
}

test "_default_compact model invoke failure propagates the exception" {
    messages = (
        [{"role": "system", "content": "sys"}, {"role": "user", "content": "task"}] + _make_round(
            1
        ) + _make_round(2)
    );
    mock_model = MockLLM(model_name="mockllm", config={"outputs": ["summary"]});
    raised = False;
    with unittest.mock.patch.object(
        mock_model, "dispatch_no_streaming", side_effect=Exception("API down")
    ) {
        try {
            _byllm_llm_mod._default_compact(messages, 1, mock_model);
        } except Exception as e {
            raised = True;
            assert "API down" in str(e) , f"Expected original exception to propagate, got: {e}";
        }
    }
    assert raised , "Summarisation model failure should propagate, not be swallowed";
}


# ---------------------------------------------------------------------------
# 10-12. _compact_messages hook dispatch
# ---------------------------------------------------------------------------
test "_compact_messages custom on_compaction hook is called" {
    hook_called = False;
    received_args = [];

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal hook_called;
        hook_called = True;
        received_args.append((len(msgs), keep_recent));
        return msgs[:2];
    }

    mt_run = _make_mt_run(
        extra_messages=_make_round(1) + _make_round(2),
        call_params={"on_compaction": my_hook}
    );
    model = Model(model_name="gpt-4o-mini");
    model._compact_messages(mt_run, keep_recent=2, comp_model=None);

    assert hook_called , "Custom on_compaction hook was not called";
    assert received_args[0][1] == 2 , (
        f"Hook should receive keep_recent=2, got {received_args[0][1]}"
    );
}

test "_compact_messages hook return value replaces mt_run messages" {
    compacted_messages = [
        {"role": "system", "content": "sys"},
        {"role": "user", "content": "task"},
        {"role": "user", "content": "summary here"}
    ];

    def my_hook(msgs: list, keep_recent: int) -> list {
        return compacted_messages;
    }

    mt_run = _make_mt_run(
        extra_messages=_make_round(1) + _make_round(2),
        call_params={"on_compaction": my_hook}
    );
    model = Model(model_name="gpt-4o-mini");
    model._compact_messages(mt_run, keep_recent=1, comp_model=None);

    assert mt_run.messages == compacted_messages , (
        "mt_run.messages should be replaced by hook return value"
    );
}

test "_compact_messages default path used when no hook provided" {
    default_compact_called = False;

    def spy(msgs: list, keep_recent: int, model: BaseLLM) -> list {
        nonlocal default_compact_called;
        default_compact_called = True;
        return msgs[:2];
    }

    mt_run = _make_mt_run(extra_messages=_make_round(1) + _make_round(2));
    model = Model(model_name="gpt-4o-mini");

    with unittest.mock.patch.object(_byllm_llm_mod, "_default_compact", spy) {
        model._compact_messages(mt_run, keep_recent=1, comp_model=None);
    }
    assert default_compact_called , "_default_compact should be called when no hook";
}


# ---------------------------------------------------------------------------
# 13-19. invoke() threshold and guard logic
#
# All tests use Model(model_name="mockllm") with MockLLM's outputs list and
# the "by llm()" syntax - matching the established test discipline.
# Each outputs entry may be a plain MockToolCall or a (MockToolCall, usage)
# tuple; the tuple form injects prompt_tokens so threshold logic can be tested.
#
# byLLM auto-generates and appends finish_tool internally (mtir.impl.jac).
# We define a local function named "finish_tool" only for use in MockToolCall -
# Tool.is_finish_tool() checks the function name, so the name must match exactly.
# ---------------------------------------------------------------------------
test "invoke threshold triggers compaction when prompt tokens above ratio" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs[:2];
    }

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 850, "total_tokens": 950}
                ),
                (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {})
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a], ctx_window=1000, threshold_ratio=0.80, on_compaction=my_hook
    );

    result = my_task("test");
    assert compaction_called , (
        "Compaction hook should have been called when prompt_tokens/ctx_window >= 0.80"
    );
}

test "invoke compaction not triggered when below threshold" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs;
    }

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 100, "total_tokens": 200}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a], ctx_window=1000, threshold_ratio=0.80, on_compaction=my_hook
    );

    result = my_task("test");
    assert not compaction_called , (
        "Compaction should NOT be triggered when prompt_tokens is well below threshold"
    );
}

test "invoke compaction enabled false suppresses threshold trigger" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs;
    }

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 900, "total_tokens": 1000}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a],
        ctx_window=1000,
        threshold_ratio=0.80,
        compaction_enabled=False,
        on_compaction=my_hook
    );

    result = my_task("test");
    assert not compaction_called , "Compaction should NOT trigger when compaction_enabled=False";
}

test "invoke CompactionNotEffectiveError on consecutive threshold triggers" {
    def step_a -> str {
        return "a";
    }

    def my_hook(msgs: list, keep_recent: int) -> list {
        return msgs;  # no-op - compaction produces no reduction
    }

    # Two identical high-usage entries: iter 1 compact fires, iter 2 fires again → error
    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 900, "total_tokens": 950}
                ),
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 900, "total_tokens": 950}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a], ctx_window=1000, threshold_ratio=0.80, on_compaction=my_hook
    );

    raised = False;
    try {
        my_task("test");
    } except CompactionNotEffectiveError as e {
        raised = True;
        assert "900/1000" in str(e) or "90%" in str(e) , (
            f"Error message should contain token info, got: {e}"
        );
    }
    assert raised , "Expected CompactionNotEffectiveError when compaction has no effect";
}

test "invoke just_compacted resets after a below-threshold iteration" {
    compaction_count = 0;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_count;
        compaction_count += 1;
        return msgs[:2];
    }

    def step_a -> str {
        return "a";
    }
    def step_b -> str {
        return "b";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    # iter 1: high → compact, just_compacted=True
    # iter 2: low  → just_compacted resets to False
    # iter 3: high + finish_tool → compact again (no error), loop exits
    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 900, "total_tokens": 950}
                ),
                (
                    MockToolCall(tool=step_b, args={}),
                    {"prompt_tokens": 100, "total_tokens": 200}
                ),
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 850, "total_tokens": 900}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a, step_b],
        ctx_window=1000,
        threshold_ratio=0.80,
        on_compaction=my_hook
    );

    raised = False;
    try {
        result = my_task("test");
    } except CompactionNotEffectiveError {
        raised = True;
    }
    assert not raised , (
        "CompactionNotEffectiveError should NOT be raised after a below-threshold reset"
    );
    assert compaction_count == 2 , (
        f"Expected 2 compactions (iter 1 and iter 3), got {compaction_count}"
    );
}


# ---------------------------------------------------------------------------
# 18. ContextWindowExceededError emergency path
#
# MockLLM cannot raise provider exceptions natively, so we patch at
# model_call_no_stream (the LiteLLM call boundary) - the established pattern
# for exception testing in test_byllm.jac (see "unknown tool error" and
# exception-logging tests). The SimpleNamespace response on the retry mirrors
# LiteLLM's dict format so dispatch_no_streaming can process it normally.
# ---------------------------------------------------------------------------
test "invoke ContextWindowExceededError triggers compact and retry and succeeds" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs[:2];
    }

    def step_a -> str {
        return "a";
    }
    model = Model(model_name="gpt-4o-mini");

    # Build a minimal finish_tool response in LiteLLM response-dict format.
    # dispatch_no_streaming looks up "finish_tool" in mt_run.tools, which is the
    # auto-generated one appended by MTRuntime.factory - so the name must match.
    fake_fn = types.SimpleNamespace(
        name="finish_tool", arguments='{"final_output": "recovered"}'
    );
    fake_tc = types.SimpleNamespace(id="call_1", function=fake_fn);
    ok_resp: dict = {
        "choices": [{"message": {"content": None, "tool_calls": [fake_tc]}}],
        "usage": {},
        "model": "gpt-4o-mini"
    };

    call_count = 0;
    def fake_model_call(params: dict) -> dict {
        nonlocal call_count;
        call_count += 1;
        if call_count == 1 {
            raise litellm.exceptions.ContextWindowExceededError(
                message="context length exceeded",
                model="gpt-4o-mini",
                llm_provider="openai"
            );
        }
        return ok_resp;
    }

    def my_task(q: str) -> str by model(tools=[step_a], on_compaction=my_hook);

    with unittest.mock.patch.object(model, "model_call_no_stream", fake_model_call) {
        result = my_task("test");
    }
    assert compaction_called , "on_compaction should be called after ContextWindowExceededError";
    assert result == "recovered" , f"Expected 'recovered' after compact+retry, got '{result}'";
    assert call_count == 2 , f"Expected 2 model_call_no_stream calls (fail + retry), got {call_count}";
}


# ---------------------------------------------------------------------------
# 19. on_compaction hook wired end-to-end through invoke()
# ---------------------------------------------------------------------------
test "invoke on_compaction hook receives correct arguments" {
    received_keep_recent = [];
    received_msg_count = [];

    def my_hook(msgs: list, keep_recent: int) -> list {
        received_msg_count.append(len(msgs));
        received_keep_recent.append(keep_recent);
        return msgs[:2];
    }

    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 850, "total_tokens": 900}
                ),
                (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {})
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a],
        ctx_window=1000,
        threshold_ratio=0.80,
        keep_recent_iterations=2,
        on_compaction=my_hook
    );

    my_task("test");
    assert len(received_keep_recent) == 1 , "Hook should have been called once";
    assert received_keep_recent[0] == 2 , (
        f"Hook should receive keep_recent=2, got {received_keep_recent[0]}"
    );
    assert received_msg_count[0] >= 2 , "Hook should receive at least system+user messages";
}


# ---------------------------------------------------------------------------
# Streaming path (_invoke_streaming) compaction tests
#
# _invoke_streaming is triggered by stream=True + logging=True.
# The ReAct tool-calling iterations still use dispatch_no_streaming internally;
# compaction fires between iterations just like in invoke(). The final answer
# is streamed from dispatch_streaming, so the outputs list needs one extra
# text entry for that call.
# ---------------------------------------------------------------------------
test "invoke streaming threshold triggers compaction" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs[:2];
    }

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 850, "total_tokens": 950}
                ),
                (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {}),
                "done"  # dispatched by dispatch_streaming for the final streamed answer
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a],
        stream=True,
        logging=True,
        ctx_window=1000,
        threshold_ratio=0.80,
        on_compaction=my_hook
    );

    # Consume all StreamEvents to drive the generator to completion
    for event in my_task("test") { }

    assert compaction_called , "Compaction should fire in _invoke_streaming when threshold exceeded";
}

test "invoke streaming compaction_enabled False suppresses threshold trigger" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs[:2];
    }

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 900, "total_tokens": 1000}
                ),
                "done"
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a],
        stream=True,
        logging=True,
        ctx_window=1000,
        threshold_ratio=0.80,
        compaction_enabled=False,
        on_compaction=my_hook
    );

    for event in my_task("test") { }

    assert not compaction_called , "Compaction should NOT fire in streaming path when disabled";
}

# ---------------------------------------------------------------------------
# New tests added to address PR review findings
# ---------------------------------------------------------------------------
test "_compact_messages hook returning None raises ConfigurationError" {
    # Return type intentionally omitted so Jac allows returning None
    def bad_hook(msgs: list, keep_recent: int) {
        return None;
    }

    mt_run = _make_mt_run(
        extra_messages=_make_round(1) + _make_round(2),
        call_params={"on_compaction": bad_hook}
    );
    model = Model(model_name="gpt-4o-mini");

    raised = False;
    try {
        model._compact_messages(mt_run, keep_recent=1, comp_model=None);
    } except ConfigurationError as e {
        raised = True;
        assert "on_compaction hook" in str(e) , f"Error should mention the hook, got: {e}";
    }
    assert raised , "ConfigurationError should be raised when hook returns None";
}

test "_compact_messages hook returning empty list raises ConfigurationError" {
    def bad_hook(msgs: list, keep_recent: int) -> list {
        return [];  # intentionally too short
    }

    mt_run = _make_mt_run(
        extra_messages=_make_round(1) + _make_round(2),
        call_params={"on_compaction": bad_hook}
    );
    model = Model(model_name="gpt-4o-mini");

    raised = False;
    try {
        model._compact_messages(mt_run, keep_recent=1, comp_model=None);
    } except ConfigurationError as e {
        raised = True;
        assert "at least 2 messages" in str(e) , f"Error should mention minimum length, got: {e}";
    }
    assert raised , "ConfigurationError should be raised when hook returns empty list";
}

test "invoke threshold_ratio 0.0 always compacts" {
    compaction_called = False;

    def my_hook(msgs: list, keep_recent: int) -> list {
        nonlocal compaction_called;
        compaction_called = True;
        return msgs[:2];
    }

    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    # threshold_ratio=0.0 means even 1 prompt token triggers compaction.
    # Falsy-zero fix ensures 0.0 is not treated as "unset".
    # Hook returns msgs[:2] to satisfy the removed>0 guard in _compact_messages.
    llm = Model(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=step_a, args={}),
                    {"prompt_tokens": 1, "total_tokens": 50}
                ),
                (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {})
            ]
        }
    );

    def my_task(q: str) -> str by llm(
        tools=[step_a], ctx_window=1000, threshold_ratio=0.0, on_compaction=my_hook
    );

    result = my_task("test");
    assert compaction_called , "threshold_ratio=0.0 should always trigger compaction";
}

test "invoke compaction_enabled False blocks emergency ContextWindowExceededError path" {
    model = Model(model_name="gpt-4o-mini");

    def step_a -> str {
        return "a";
    }

    call_count = 0;
    def fake_model_call(params: dict) -> dict {
        nonlocal call_count;
        call_count += 1;
        raise litellm.exceptions.ContextWindowExceededError(
            message="context length exceeded",
            model="gpt-4o-mini",
            llm_provider="openai"
        );
    }

    def my_task(q: str) -> str by model(tools=[step_a], compaction_enabled=False);

    raised = False;
    with unittest.mock.patch.object(model, "model_call_no_stream", fake_model_call) {
        try {
            my_task("test");
        } except litellm.exceptions.ContextWindowExceededError {
            raised = True;
        }
    }
    assert raised , "ContextWindowExceededError should propagate when compaction_enabled=False";
    assert call_count == 1 , "Should not retry when compaction is disabled";
}

# ---------------------------------------------------------------------------
# 20-21. ModelPool._get_ctx_window
# ---------------------------------------------------------------------------
test "ModelPool get_ctx_window explicit override wins over member minimum" {
    model_a = Model(model_name="gpt-4o", ctx_window=128000);
    model_b = Model(model_name="gpt-3.5-turbo", ctx_window=16000);
    pool = ModelPool(models=[model_a, model_b], ctx_window=200000);
    result = pool._get_ctx_window({});
    assert result == 200000 , (
        f"Pool's explicit ctx_window=200000 should win over member minimum, got {result}"
    );
}

test "ModelPool get_ctx_window returns min of members when no override" {
    reset_byllm_config();
    model_a = Model(model_name="gpt-4o", ctx_window=128000);
    model_b = Model(model_name="gpt-3.5-turbo", ctx_window=16000);
    pool = ModelPool(models=[model_a, model_b]);

    with unittest.mock.patch(
        "litellm.get_model_info", side_effect=Exception("unknown")
    ) {
        result = pool._get_ctx_window({});
    }
    assert result == 16000 , (
        f"Pool should return min(128000, 16000) = 16000 when no override, got {result}"
    );
}
