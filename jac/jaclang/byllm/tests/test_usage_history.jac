"""Tests for usage/token tracking reaching every invocation shape (#8462).

Covers: usage is captured on mt_run (not the shared model instance, which
would corrupt concurrent invocations), the non-streaming primitives record
usage the same way the streaming ones already did, calls made by byLLM's own
machinery (final-answer restream, recovery, compaction) are tagged with a
call_kind distinct from ordinary ReAct iterations, the aggregate reaches
application code via register_agent_callback's "tokens" field, and async
invocations get the same treatment as sync ones.
"""

import asyncio;
import unittest.mock;
import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model, MockLLM }
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.types { Tool, Message, MessageRole, MockToolCall }
import from jaclang.byllm.telemetry { register_agent_callback, _agent_callbacks }
import dataclasses;
import types;

glob _Person = dataclasses.make_dataclass(
         "Person8462", [("name", str), ("age", int)]
     );


def _response(usage: dict, content: str = "hi") -> dict {
    return {
        "model": "gpt-4o-mini",
        "choices": [
            {
                "message": {"role": "assistant", "content": content, "tool_calls": []},
                "finish_reason": "stop"
            }
        ],
        "usage": usage
    };
}


def _finish_env(arguments: str, usage: dict) -> tuple {
    model = Model(model_name="test-model");
    mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="You are a helpful assistant."),
            Message(role=MessageRole.USER, content="Who?")
        ],
        resp_type=_Person,
        stream=False,
        tools=[Tool.make_finish_tool(_Person)],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );
    fake_fn = types.SimpleNamespace(name="finish_tool", arguments=arguments);
    fake_response = {
        "choices": [
            {
                "message": {
                    "content": None,
                    "tool_calls": [types.SimpleNamespace(id="call_1", function=fake_fn)]
                }
            }
        ],
        "usage": usage
    };
    return (model, mt_run, fake_response);
}


def _with_callback(cb: Callable, fn: Callable) -> object {
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


test "dispatch_no_streaming records usage on mt_run, isolated per invocation" {
    llm = Model(model_name="gpt-4o-mini");
    mt1 = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="a")
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );
    mt2 = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="b")
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );

    with unittest.mock.patch.object(
        llm,
        "model_call_no_stream",
        return_value=_response(
            {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}
        )
    ) {
        llm.dispatch_no_streaming(mt1);
    }
    with unittest.mock.patch.object(
        llm,
        "model_call_no_stream",
        return_value=_response(
            {"prompt_tokens": 20, "completion_tokens": 2, "total_tokens": 22}
        )
    ) {
        llm.dispatch_no_streaming(mt2);
    }

    assert len(mt1._usage_history) == 1 , "mt1 should see exactly its own call";
    assert len(mt2._usage_history) == 1 , "mt2 should see exactly its own call";
    assert mt1._usage_history[0]["prompt_tokens"] == 10;
    assert mt2._usage_history[0]["prompt_tokens"] == 20;
    assert mt1._usage_history[0]["call_kind"] == "react_iteration";
    assert mt1._usage_history[0]["model"] == "gpt-4o-mini";
}


test "adispatch_no_streaming also records usage on mt_run" {
    llm = Model(model_name="gpt-4o-mini");
    mt_run = MTRuntime(
        messages=[
            Message(role=MessageRole.SYSTEM, content="s"),
            Message(role=MessageRole.USER, content="a")
        ],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None
    );

    async def _fake(params: dict) -> dict {
        return _response(
            {"prompt_tokens": 5, "completion_tokens": 1, "total_tokens": 6}
        );
    }

    with unittest.mock.patch.object(llm, "model_call_no_stream_async", _fake) {
        asyncio.run(llm.adispatch_no_streaming(mt_run));
    }

    assert len(mt_run._usage_history) == 1;
    assert mt_run._usage_history[0]["total_tokens"] == 6;
}


test "a plain non-streaming by llm() call surfaces tokens via register_agent_callback" {
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    # Model wraps a MockLLM delegate but is the layer that actually owns
    # telemetry emission (Model.invoke) - a bare MockLLM never fires it.
    llm = Model(
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

    def my_task(q: str) -> str by llm(tools=[finish_tool]);

    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }

    result = _with_callback(cb, lambda { return my_task("test"); });

    assert result == "ok";
    assert len(captured) == 1;
    tokens = captured[0]["tokens"];
    assert tokens["requests"] == 1 , f"Expected 1 recorded call, got {tokens}";
    assert tokens["total"]["total_tokens"] == 110;
    assert "react_iteration" in tokens["by_kind"];
    assert tokens["by_kind"]["react_iteration"]["total_tokens"] == 110;
}


test "final_answer_restream call is tagged separately from react iterations" {
    (model, mt_run, fake_response) = _finish_env(
        '{"output": {"name": "Gus", "age": 29}}',
        {"prompt_tokens": 50, "completion_tokens": 5, "total_tokens": 55}
    );
    mt_run.stream = True;

    def _fake_stream(params: dict) -> object {
        return [
            types.SimpleNamespace(
                usage=None,
                choices=[
                    types.SimpleNamespace(delta=types.SimpleNamespace(content="Gus"))
                ]
            ),
            types.SimpleNamespace(
                usage=types.SimpleNamespace(
                    prompt_tokens=50, completion_tokens=5, total_tokens=55
                ),
                choices=[]
            )
        ];
    }

    with unittest.mock.patch.object(model, "model_call_with_stream", _fake_stream) {
        list(model._stream_final_answer(mt_run));
    }

    assert len(mt_run._usage_history) == 1;
    assert mt_run._usage_history[0]["call_kind"] == "final_answer_restream";
    # The temporary override must not leak onto later calls on the same mt_run.
    assert mt_run._call_kind == "react_iteration";
}


test "recovery call is tagged separately from react iterations" {
    (model, mt_run, fake_response) = _finish_env(
        '{"output": {"name": "Gus", "age": 29}}',
        {"prompt_tokens": 15, "completion_tokens": 3, "total_tokens": 18}
    );
    with unittest.mock.patch.object(
        model, "model_call_no_stream", return_value=fake_response
    ) {
        model._attempt_recovery(mt_run);
    }

    assert len(mt_run._usage_history) == 1;
    assert mt_run._usage_history[0]["call_kind"] == "recovery";
    assert mt_run._call_kind == "react_iteration";
}


test "compaction call usage merges into the parent invocation under its own tag" {
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
                    {"prompt_tokens": 850, "total_tokens": 850}
                ),
                (
                    MockToolCall(tool=finish_tool, args={"final_output": "ok"}),
                    {"prompt_tokens": 10, "total_tokens": 10}
                )
            ]
        }
    );

    def hook(msgs: list, keep_recent: int) -> list {
        return [msgs[0], msgs[1]];
    }

    def my_task(q: str) -> str by llm(
        tools=[step_a], threshold_ratio=0.80, on_compaction=hook
    );

    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }

    result = _with_callback(cb, lambda { return my_task("test"); });

    assert result == "ok";
    assert len(captured) == 1;
    by_kind = captured[0]["tokens"]["by_kind"];
    assert "react_iteration" in by_kind , f"Expected react_iteration usage, got {by_kind}";
    # on_compaction hooks don't make an LLM call themselves, so no "compaction"
    # bucket is expected here - covered separately by the default-compactor path.
}


test "default compactor's summarisation call is tagged compaction on the parent mt_run" {
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

    # MockLLM's (output, usage) tuple convention only recognizes tool-call
    # outputs (see mockllm.impl.jac's first_is_tool check) - compaction's
    # summariser call returns a plain string, so a real Model with a mocked
    # response is used here to inject usage.
    summariser = Model(model_name="test-model");
    parent_mt = MTRuntime(
        messages=[], resp_type=str, stream=False, tools=[], call_params={}, mtir=None
    );

    with unittest.mock.patch.object(
        summariser,
        "model_call_no_stream",
        return_value=_response(
            {"prompt_tokens": 200, "completion_tokens": 20, "total_tokens": 220},
            "a summary"
        )
    ) {
        _byllm_llm_mod._default_compact(messages, 1, summariser, parent_mt);
    }

    assert len(parent_mt._usage_history) == 1;
    assert parent_mt._usage_history[0]["call_kind"] == "compaction";
    assert parent_mt._usage_history[0]["total_tokens"] == 220;
}


test "async by llm() call with no tools surfaces telemetry and tokens the same as sync" {
    # No-tools, non-streaming is the branch BaseLLM.ainvoke dispatches directly
    # (_ainvoke_typed_retry) rather than delegating to the already-telemetered
    # sync Model.invoke via asyncio.to_thread - this is the branch that had no
    # telemetry at all before Model.ainvoke existed.
    llm = Model(model_name="test-model");

    async def _fake(params: dict) -> dict {
        return _response(
            {"prompt_tokens": 12, "completion_tokens": 2, "total_tokens": 14},
            "async-ok"
        );
    }

    async def my_async_task(q: str) -> str by llm();

    captured: list = [];
    def cb(record: dict) {
        captured.append(record);
    }

    def _run -> str {
        with unittest.mock.patch.object(llm, "model_call_no_stream_async", _fake) {
            return asyncio.run(my_async_task("test"));
        }
    }
    result = _with_callback(cb, _run);

    assert result == "async-ok";
    assert len(captured) == 1 , "async invocation should emit telemetry exactly once";
    assert captured[0]["status"] == "success";
    assert captured[0]["tokens"]["total"]["total_tokens"] == 14;
}


test "usage StreamEvent always terminates a logging=True stream, even with no usage data" {
    llm = MockLLM(model_name="mockllm", config={"outputs": ["hello there"]});

    def my_task(q: str) -> str by llm(stream=True, logging=True);

    events = list(my_task("test"));
    assert events , "expected at least the usage event";
    assert events[-1].event_type == "usage" , (
        f"usage must be the last event even with no measurable tokens, got "
        f"{events[-1].event_type}"
    );
    assert events[-1].data["total"] == {};
    assert events[-1].data["per_call"] == [];
    assert events[-1].data["by_kind"] == {};
    assert events[-1].data["requests"] == 0;
}
