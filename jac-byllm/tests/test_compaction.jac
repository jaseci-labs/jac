"""Integration tests for the byLLM auto-compaction feature."""

import from unittest { mock }
import os;
import types;
import litellm;

import byllm.llm as _byllm_llm_mod;
import from byllm.lib { Model, ModelPool, MockLLM }
import from byllm.llm { BaseLLM, LocalLLM }
import from byllm.types { MockToolCall, CompletionResult }
import from byllm.exceptions { CompactionNotEffectiveError, ConfigurationError }
import from byllm.config_loader { reset_byllm_config, get_byllm_config }
import from byllm.mtir { MTRuntime }
import from pathlib { Path }


glob FIXTURE_DIR = os.path.join(
         os.path.dirname(os.path.abspath(__file__)), "fixtures"
     ),
     COMPACTION_TOML_FIXTURE = os.path.join(FIXTURE_DIR, "compaction_config");


# MockLLM.dispatch_no_streaming adds the assistant message as a string, which
# _default_compact's role-detection cannot recognise. So pipeline tests use a
# hook; structural correctness of _default_compact is verified separately.
test "above threshold compacts and next iteration sees shortened messages" {
    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
                (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
            ]
        }
    );

    hook_call_count = [0];
    def shrinking_hook(msgs: list, keep_recent: int) -> list {
        hook_call_count[0] += 1;
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

    assert result == "ok";
    assert hook_call_count[0] == 1;
    # Without compaction iter 3 would be at 6 messages; hook collapses to 3.
    assert iter_msgs == [2, 4, 3] , f"Expected [2, 4, 3], got {iter_msgs}";
}


test "default compactor produces system user summary and kept-tail structure" {
    sys_msg = {"role": "system", "content": "You are a helpful assistant."};
    user_msg = {"role": "user", "content": "Do the thing."};
    def make_round(idx: int) -> list {
        return [
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": f"call_{idx}",
                        "function": {"name": "search", "arguments": f'{{"q":"q{idx}"}}'}
                    }
                ]
            },
            {
                "role": "tool",
                "content": f"result_{idx}",
                "tool_call_id": f"call_{idx}",
                "name": "search"
            }
        ];
    }

    messages = [sys_msg, user_msg] + make_round(1) + make_round(2) + make_round(3);
    summary_text = "Steps 1, 2, and 3 searched for q1/q2/q3.";
    summariser = MockLLM(model_name="mockllm", config={"outputs": [summary_text]});

    result: list = list(_byllm_llm_mod._default_compact(messages, 1, summariser));

    assert len(result) == 5 , f"Expected 5 messages, got {len(result)}";
    assert result[0] is sys_msg;
    assert result[1] is user_msg;
    assert result[2]["role"] == "user";
    assert "[Compacted context summary]" in result[2]["content"];
    assert summary_text in result[2]["content"];
    assert result[3]["role"] == "assistant";
    assert result[3]["tool_calls"][0]["id"] == "call_3";
    assert result[4]["role"] == "tool" and result[4]["tool_call_id"] == "call_3";
}


test "below threshold does not trigger compaction" {
    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 100}
                )
            ]
        }
    );

    def my_task(q: str) -> str by llm(tools=[step_a], threshold_ratio=0.80);
    result = my_task("test");

    assert result == "ok";
    assert llm.config["outputs"] == [];
}


test "ctx_window priority - call_params beats self.ctx_window" {
    reset_byllm_config();
    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=10000,
        config={
            "outputs": [
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
                (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
            ]
        }
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
    assert compaction_fired[0];
}


# T3b/T3c stay at the resolver level: by llm() invocations through MTRuntime
# call get_byllm_config(project_dir) for system-prompt resolution, which wipes
# our cached fixture config (find_project_root walks past tests/fixtures and
# hits the outer jaseci/jac.toml). See ISSUE_config_cache_invalidation.md.
test "ctx_window priority - self.ctx_window beats jac.toml" {
    reset_byllm_config();
    get_byllm_config(Path(COMPACTION_TOML_FIXTURE));
    try {
        loaded = get_byllm_config().get_compaction_config();
        assert loaded["ctx_window"] == 10000 , f"Fixture not loaded: {loaded}";

        llm = MockLLM(model_name="mockllm", ctx_window=1000);
        assert llm._get_ctx_window({}) == 1000;
    } finally {
        reset_byllm_config();
    }
}


test "ctx_window priority - jac.toml beats litellm" {
    reset_byllm_config();
    get_byllm_config(Path(COMPACTION_TOML_FIXTURE));
    try {
        # litellm registry has gpt-4o-mini = 128000.
        llm = MockLLM(model_name="gpt-4o-mini");
        assert llm._get_ctx_window({}) == 10000;
    } finally {
        reset_byllm_config();
    }
}


test "ctx_window fallback - unknown model with no override disables threshold" {
    reset_byllm_config();
    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="definitely-not-a-real-model-zzz",
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 999_999}
                )
            ]
        }
    );

    compaction_fired = [False];
    def hook(msgs: list, keep_recent: int) -> list {
        compaction_fired[0] = True;
        return msgs[:2];
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=hook
    );

    assert my_task("test") == "ok";
    assert not compaction_fired[0];
}


test "compaction_enabled false suppresses proactive and emergency paths" {
    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm1 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 950}
                )
            ]
        }
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

    assert task1("test") == "ok";
    assert not proactive_fired[0];

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
    assert raised;
    assert call_count[0] == 1;
}


# Hook used instead of default compactor: at first dispatch mt_run has only
# [system, user] = 2 messages, too few for the default slice to be non-empty.
test "ContextWindowExceededError triggers emergency compaction and retries" {
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                (MockToolCall(tool=finish_tool, args={"final_output": "recovered"}), {})
            ]
        }
    );

    hook_called = [False];
    def hook(msgs: list, keep_recent: int) -> list {
        hook_called[0] = True;
        return msgs[:2];
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

    assert hook_called[0];
    assert result == "recovered";
    assert outer_call_count[0] == 2;
    assert llm.config["outputs"] == [];
}


test "compaction with no reduction raises CompactionNotEffectiveError" {
    def step_a -> str {
        return "a";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900})
            ]
        }
    );

    def noop_hook(msgs: list, keep_recent: int) -> list {
        return msgs;
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=noop_hook
    );

    raised = False;
    try {
        my_task("test");
    } except CompactionNotEffectiveError as e {
        raised = True;
        assert "no reduction" in str(e);
    }
    assert raised;
}


test "on_compaction hook returning invalid types raises ConfigurationError" {
    def step_a -> str {
        return "a";
    }

    def run_with_hook(hook: object) -> object {
        llm = MockLLM(
            model_name="mockllm",
            ctx_window=1000,
            config={
                "outputs": [
                    (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900})
                ]
            }
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

    def hook_none(msgs: list, keep_recent: int) -> object {
        return None;
    }
    e1 = run_with_hook(hook_none);
    assert isinstance(e1, ConfigurationError) , f"Got {type(e1).__name__}: {e1}";
    assert "on_compaction hook" in str(e1);

    def hook_empty(msgs: list, keep_recent: int) -> list {
        return [];
    }
    e2 = run_with_hook(hook_empty);
    assert isinstance(e2, ConfigurationError);
    assert "at least 2 messages" in str(e2);

    def hook_dict(msgs: list, keep_recent: int) -> object {
        return {"role": "user", "content": "wrong shape"};
    }
    e3 = run_with_hook(hook_dict);
    assert isinstance(e3, ConfigurationError);
}


test "streaming path triggers compaction and respects compaction_enabled" {
    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm1 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
                (MockToolCall(tool=finish_tool, args={"final_output": "done"}), {}),
                "done"
            ]
        }
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

    for event in task1("test") { }
    assert fired1[0];

    llm2 = MockLLM(
        model_name="mockllm",
        ctx_window=1000,
        config={
            "outputs": [
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                    {"prompt_tokens": 950}
                ),
                "done"
            ]
        }
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
    assert not fired2[0];
}


# ModelPool routes through the LiteLLM Router (no MockLLM seam at pool level),
# so resolution is verified at the function level only.
test "ModelPool ctx_window override beats min of members" {
    reset_byllm_config();
    a = Model(model_name="gpt-4o", ctx_window=128000);
    b = Model(model_name="gpt-3.5-turbo", ctx_window=16000);

    pool_min = ModelPool(models=[a, b]);
    assert pool_min._get_ctx_window({}) == 16000;

    pool_override = ModelPool(models=[a, b], ctx_window=200000);
    assert pool_override._get_ctx_window({}) == 200000;

    assert pool_override._get_ctx_window({"ctx_window": 500}) == 500;
}


# Spec n_ctx for "local:gemma-4-e4b" is 8192. With prompt_tokens=850, an
# override of 1000 fires (85%); without, spec=8192 doesn't fire (10%).
# So compaction firing means an override won.
test "LocalLLM ctx_window propagation drives compaction end-to-end" {
    reset_byllm_config();
    OVERRIDE = 1000;

    def step_a -> str {
        return "stepped";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    # format_prompt subscripts messages[3] assuming get_msg_list() converted
    # ToolCallResultMsg via to_dict(). On CI this isinstance check evaluates
    # differently and the subscript raises. Bypass it - logging-only helper.
    def noop_format(p: dict) -> str {
        return "";
    }

    def make_fake_dispatch -> object {
        step_resp: dict = {
            "choices": [
                {
                    "message": {
                        "content": None,
                        "tool_calls": [
                            types.SimpleNamespace(
                                id="call_step",
                                function=types.SimpleNamespace(
                                    name="step_a", arguments="{}"
                                )
                            )
                        ]
                    }
                }
            ],
            "usage": {"prompt_tokens": 850},
            "model": "local:gemma-4-e4b"
        };
        finish_resp: dict = {
            "choices": [
                {
                    "message": {
                        "content": None,
                        "tool_calls": [
                            types.SimpleNamespace(
                                id="call_finish",
                                function=types.SimpleNamespace(
                                    name="finish_tool",
                                    arguments='{"final_output": "ok"}'
                                )
                            )
                        ]
                    }
                }
            ],
            "usage": {},
            "model": "local:gemma-4-e4b"
        };
        call_count = [0];
        def fake(params: dict) -> dict {
            call_count[0] += 1;
            return step_resp if call_count[0] == 1 else finish_resp;
        }
        return fake;
    }

    # Drive `by target(...)` with the given call_params; report whether
    # compaction fired. patch_target is the LLM whose dispatch should be
    # intercepted (same as target for LocalLLM, _local_delegate for Model).
    def fires_compaction(
        target: object, patch_target: object, ctx_window_in_call: int
    ) -> bool {
        fired = [False];
        def hook(msgs: list, keep_recent: int) -> list {
            fired[0] = True;
            return msgs[:2];
        }
        def task(q: str) -> str by target(
            tools=[step_a],
            ctx_window=ctx_window_in_call,
            threshold_ratio=0.80,
            on_compaction=hook
        );
        with mock.patch.object(patch_target, "format_prompt", noop_format) {
            with mock.patch.object(
                patch_target, "model_call_no_stream", make_fake_dispatch()
            ) {
                task("test");
            }
        }
        return fired[0];
    }

    # Baseline: no override anywhere - 850/8192 = 10% must NOT fire.
    spec = LocalLLM(model_name="local:gemma-4-e4b");
    assert not fires_compaction(spec, spec, 0) , "Baseline (no override) must not fire - test cannot discriminate otherwise";

    # config["n_ctx"] rung: same value the engine is built with.
    cfg = LocalLLM(model_name="local:gemma-4-e4b", config={"n_ctx": OVERRIDE});
    assert fires_compaction(cfg, cfg, 0) , "config['n_ctx'] override must reach compaction";

    # self.ctx_window rung.
    own = LocalLLM(model_name="local:gemma-4-e4b", ctx_window=OVERRIDE);
    assert fires_compaction(own, own, 0) , "self.ctx_window override must reach compaction";

    # call_params rung (highest priority).
    direct = LocalLLM(model_name="local:gemma-4-e4b");
    assert fires_compaction(direct, direct, OVERRIDE) , "by llm(ctx_window=...) must reach compaction";

    # Model wrapper must forward ctx_window to _local_delegate.
    m = Model(model_name="local:gemma-4-e4b", ctx_window=OVERRIDE);
    assert m._local_delegate is not None;
    assert fires_compaction(m, m._local_delegate, 0) , "Model('local:...', ctx_window=N) must forward to _local_delegate";
}
