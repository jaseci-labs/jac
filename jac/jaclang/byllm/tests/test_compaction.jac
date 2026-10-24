"""Integration tests for the byLLM auto-compaction feature."""

import litellm;

import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model, ModelPool, MockLLM }
import from jaclang.byllm.llm { BaseLLM, LocalLLM }
import from jaclang.byllm.types { MockToolCall }
import from jaclang.byllm.exceptions { CompactionNotEffectiveError, ConfigurationError }
import from jaclang.byllm.config_loader { reset_byllm_config, get_byllm_config }
import from pathlib { Path }
import from support {
    call,
    capture_loguru,
    event_types,
    events_of,
    fail,
    finish,
    fixture_path,
    scripted
}


glob COMPACTION_TOML_FIXTURE = fixture_path("compaction_config");


def step_a -> str {
    return "stepped";
}


def finish_tool(final_output: str) -> str {
    return final_output;
}


# Pipeline tests compact through a hook so they check when compaction fires,
# not how _default_compact slices; that is verified separately.
test "above threshold compacts and next iteration sees shortened messages" {
    def new_list(msgs: list[any], keep_recent: int) -> list[any] {
        return [msgs[0], msgs[1]];
    }

    def in_place(msgs: list[any], keep_recent: int) -> list[any] {
        del msgs[2:];
        return msgs;
    }

    for (label, hook) in [
        ("hook returns a new list", new_list),
        ("hook shrinks the list in place", in_place)
    ] {
        llm = MockLLM(
            ctx_window=1000,
            outputs=[
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),
                (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
                (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
            ]
        );

        hook_calls = [0];
        def counted(msgs: list[any], keep_recent: int) -> list[any] {
            hook_calls[0] += 1;
            return hook(msgs, keep_recent);
        }

        def my_task(q: str) -> str by llm(
            tools=[step_a], threshold_ratio=0.80, on_compaction=counted
        );

        assert my_task("test") == "ok" , f"{label}: the call must finish";
        assert hook_calls[0] == 1 , f"{label}: the hook must run once, ran {hook_calls[
            0
        ]}";
        # Without compaction iter 3 would be at 6 messages; the hook collapses it to 3.
        iter_msgs = [len(sent) for sent in llm.sent("messages")];
        assert iter_msgs == [2, 4, 3] , f"{label}: expected [2, 4, 3], got {iter_msgs}";
    }
}


test "default compactor produces system user summary and kept-tail structure" {
    sys_msg = {"role": "system", "content": "You are a helpful assistant."};
    user_msg = {"role": "user", "content": "Do the thing."};
    def make_round(idx: int) -> list[any] {
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
    summariser = MockLLM(outputs=[summary_text]);

    result: list[any] = list(_byllm_llm_mod._default_compact(messages, 1, summariser));

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
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            (
                MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                {"prompt_tokens": 100}
            )
        ]
    );

    def my_task(q: str) -> str by llm(tools=[step_a], threshold_ratio=0.80);
    result = my_task("test");

    assert result == "ok";
    assert llm.config["outputs"] == [];
}


test "ctx_window priority - call_params beats self.ctx_window" {
    reset_byllm_config();

    llm = MockLLM(
        ctx_window=10000,
        outputs=[
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850}),
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
        ]
    );

    compaction_fired = [False];
    def hook(msgs: list[any], keep_recent: int) -> list[any] {
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

        llm = MockLLM(ctx_window=1000);
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

    llm = MockLLM(
        model_name="definitely-not-a-real-model-zzz",
        outputs=[
            (
                MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                {"prompt_tokens": 999_999}
            )
        ]
    );

    compaction_fired = [False];
    def hook(msgs: list[any], keep_recent: int) -> list[any] {
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
    llm1 = MockLLM(
        ctx_window=1000,
        outputs=[
            (
                MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                {"prompt_tokens": 950}
            )
        ]
    );

    proactive_fired = [False];
    def hook1(msgs: list[any], keep_recent: int) -> list[any] {
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

    llm2 = MockLLM(
        outputs=[
            fail(
                litellm.exceptions.ContextWindowExceededError(
                    message="ctx", model="mockllm", llm_provider="openai"
                )
            )
        ]
    );

    def task2(q: str) -> str by llm2(tools=[step_a], compaction_enabled=False);

    raised = False;
    try {
        task2("test");
    } except litellm.exceptions.ContextWindowExceededError {
        raised = True;
    }
    assert raised;
    assert len(llm2.seen) == 1 , (
        f"a disabled compactor must not retry, got {len(llm2.seen)} calls"
    );
}


# Hook used instead of default compactor: at first dispatch mt_run has only
# [system, user] = 2 messages, too few for the default slice to be non-empty.
test "ContextWindowExceededError triggers emergency compaction and retries" {
    # No tools are offered, so the retried call answers in plain text.
    llm = MockLLM(
        outputs=[
            fail(
                litellm.exceptions.ContextWindowExceededError(
                    message="ctx exceeded", model="mockllm", llm_provider="openai"
                )
            ),
            "recovered"
        ]
    );

    hook_called = [False];
    def hook(msgs: list[any], keep_recent: int) -> list[any] {
        hook_called[0] = True;
        return msgs[:2];
    }

    def my_task(q: str) -> str by llm(tools=[], on_compaction=hook);

    result = my_task("test");

    assert hook_called[0];
    assert result == "recovered";
    assert len(llm.seen) == 2 , (
        f"expected the failed call and one retry, got {len(llm.seen)}"
    );
    assert llm.exhausted();
}


test "a proactive compaction that does not reduce the history lets the call continue" {
    llm = MockLLM(
        ctx_window=1000,
        outputs=[
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100}),
            (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900}),
            (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
        ]
    );

    hook_calls = [0];
    def noop_hook(msgs: list[any], keep_recent: int) -> list[any] {
        hook_calls[0] += 1;
        return msgs;
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=noop_hook
    );

    with capture_loguru() as logs {
        assert my_task("test") == "ok";
    }
    assert hook_calls[0] == 1;
    assert "could not reduce the message history" in logs.text();
}


test "an emergency compaction raises CompactionNotEffectiveError only when it does not reduce the history" {
    def noop(msgs: list[any], keep_recent: int) -> list[any] {
        return msgs;
    }

    def in_place(msgs: list[any], keep_recent: int) -> list[any] {
        del msgs[2:];
        return msgs;
    }

    # (label, hook, raises)
    for (label, hook, raises) in [
        ("hook changes nothing", noop, True),
        ("hook shrinks the list in place", in_place, False)
    ] {
        llm = MockLLM(
            outputs=[
                (MockToolCall(tool=step_a, args={}), {}),
                fail(
                    litellm.exceptions.ContextWindowExceededError(
                        message="ctx exceeded", model="mockllm", llm_provider="openai"
                    )
                ),
                (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {})
            ]
        );

        def my_task(q: str) -> str by llm(tools=[step_a], on_compaction=hook);

        raised = False;
        try {
            assert my_task("test") == "ok" , f"{label}: the retried call must finish";
        } except CompactionNotEffectiveError as e {
            raised = True;
            assert "no reduction" in str(e) , f"{label}: unexpected message {e}";
        }
        assert raised == raises , f"{label}: raised={raised}, want {raises}";
        (calls, want_calls) = (len(llm.seen), 2 if raises else 3);
        assert calls == want_calls , f"{label}: want {want_calls} calls, got {calls}";
    }
}


test "on_compaction hook returning invalid types raises ConfigurationError" {
    def run_with_hook(hook: object) -> any {
        llm = MockLLM(
            ctx_window=1000,
            outputs=[(MockToolCall(tool=step_a, args={}), {"prompt_tokens": 900})]
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

    def hook_none(msgs: list[any], keep_recent: int) -> any {
        return None;
    }
    e1 = run_with_hook(hook_none);
    assert isinstance(e1, ConfigurationError) , f"Got {type(e1).__name__}: {e1}";
    assert "on_compaction hook" in str(e1);

    def hook_empty(msgs: list[any], keep_recent: int) -> list[any] {
        return [];
    }
    e2 = run_with_hook(hook_empty);
    assert isinstance(e2, ConfigurationError);
    assert "at least 2 messages" in str(e2);

    def hook_dict(msgs: list[any], keep_recent: int) -> any {
        return {"role": "user", "content": "wrong shape"};
    }
    e3 = run_with_hook(hook_dict);
    assert isinstance(e3, ConfigurationError);
}


test "streaming reports each applied compaction once and respects compaction_enabled" {
    def overflow -> Exception {
        return litellm.exceptions.ContextWindowExceededError(
            message="ctx exceeded", model="mockllm", llm_provider="openai"
        );
    }

    def shrink(msgs: list[any], keep_recent: int) -> list[any] {
        return msgs[:2];
    }

    def unchanged(msgs: list[any], keep_recent: int) -> list[any] {
        return msgs;
    }

    step = (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 100});
    big = (MockToolCall(tool=step_a, args={}), {"prompt_tokens": 850});
    done = (MockToolCall(tool=finish_tool, args={"final_output": "ok"}), {});
    over = [step, big, done, "ok"];
    retry = [step, fail(overflow()), done, "ok"];
    retry_fails = [step, fail(overflow()), fail(overflow())];
    applied = {
        "reason": "threshold",
        "by": "hook",
        "iteration": 2,
        "messages_before": 5,
        "messages_after": 2
    };
    overflowed = {"reason": "overflow", "by": "hook"};
    # (label, model script, hook, compaction_enabled, event fields (None = no event), raises)
    rows: list[tuple[str, list[any], any, bool, dict[str, any] | None, bool]] = [
        ("applied compaction", over, shrink, True, applied, False),
        ("compaction disabled", over, shrink, False, None, False),
        ("discarded compaction", over, unchanged, True, None, False),
        ("emergency compaction", retry, shrink, True, overflowed, False),
        ("emergency retry that fails", retry_fails, shrink, True, overflowed, True)
    ];
    for (label, outputs, hook, enabled, want, raises) in rows {
        llm = MockLLM(model_name="test-model", ctx_window=1000, outputs=list(outputs));
        hook_calls = [0];
        def counted(msgs: list[any], keep_recent: int) -> list[any] {
            hook_calls[0] += 1;
            return hook(msgs, keep_recent);
        }

        def task(q: str) -> str by llm(
            tools=[step_a],
            stream=True,
            logging=True,
            threshold_ratio=0.80,
            compaction_enabled=enabled,
            on_compaction=counted
        );

        seen: list[any] = [];
        raised = False;
        try {
            for event in task("go") {
                seen.append(event);
            }
        } except litellm.exceptions.ContextWindowExceededError {
            raised = True;
        }
        assert raised == raises , f"{label}: raised={raised}, want {raises}";
        assert (hook_calls[0] > 0) == enabled , f"{label}: hook ran {hook_calls[
            0
        ]} times";
        kinds = event_types(seen);
        reported = events_of(seen, "compaction");
        assert len(reported) == (0 if want is None else 1) , f"{label}: events {kinds}";
        if want is not None {
            info = reported[0].data;
            for (key, value) in want.items() {
                assert info[key] == value , f"{label}: {key} is {info[key]!r}, want {value!r}";
            }
            assert 0 < info["tokens_after"] < info["tokens_before"] , f"{label}: tokens {info}";
            if not raises {
                assert kinds.index("compaction") < kinds.index("steps_done") , f"{label}: {kinds}";
            }
        }
    }
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

    # Drive `by target(...)` with the given call_params; report whether
    # compaction fired. `served` is the LLM whose network calls answer: the
    # target itself for LocalLLM, its _local_delegate for Model.
    def fires_compaction(
        target: BaseLLM, served: BaseLLM, ctx_window_in_call: int
    ) -> bool {
        fired = [False];
        def hook(msgs: list[any], keep_recent: int) -> list[any] {
            fired[0] = True;
            return msgs[:2];
        }
        def task(q: str) -> str by target(
            tools=[step_a],
            ctx_window=ctx_window_in_call,
            threshold_ratio=0.80,
            on_compaction=hook
        );
        with scripted(
            served,
            [
                call("step_a", call_id="call_step", usage={"prompt_tokens": 850}),
                finish("ok")
            ]
        ) {
            task("test");
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
    own_llm = LocalLLM(model_name="local:gemma-4-e4b", ctx_window=OVERRIDE);
    assert fires_compaction(own_llm, own_llm, 0) , "self.ctx_window override must reach compaction";

    # call_params rung (highest priority).
    direct = LocalLLM(model_name="local:gemma-4-e4b");
    assert fires_compaction(direct, direct, OVERRIDE) , "by llm(ctx_window=...) must reach compaction";

    # Model wrapper must forward ctx_window to _local_delegate.
    m = Model(model_name="local:gemma-4-e4b", ctx_window=OVERRIDE);
    delegate = m._local_delegate;
    assert delegate is not None;
    assert fires_compaction(m, delegate, 0) , "Model('local:...', ctx_window=N) must forward to _local_delegate";
}
