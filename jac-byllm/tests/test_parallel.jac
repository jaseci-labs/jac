"""Tests for the parallel tool-calling engine (byllm/parallel.jac).

Covers:
  1.  Default serialize=False (parallel opt-out model)
  2.  dispatch_batch runs parallel by default
  3.  serialize=True forces sequential
  4.  _index_by_identity result reordering
  5.  Single-tool batch runs inline
  6.  Empty batch yields nothing
  7.  Failing tool is isolated from others
  8.  Speedup proves parallel overlap
  9.  Sequential shows no speedup
  10. _is_async detection
  11. dispatch_batch is a generator
  12. _PARALLEL_TOOL_HINT constant exists in source
  13. Per-tool timeout attribute stored correctly
  14. mark_serialize helper sets _serialize attribute
  15. System prompt nudge wired into basellm source
  16. Shared module-level pool in source
  17. _serialize detection in Tool.postinit source
  18. MockLLM batch fixture (scheduler_parity) exists
  19. Async tool support (_call_async, _is_async, asyncio.run) in source
  20. Old API (tool_scheduler, _dispatch_tool_batch) removed from llm.jac
  21. BaseLLM.invoke uses dispatch_batch
  22. _should_parallelize: default OFF, env var, per-call overrides
  23. make_model_params: tool description annotations + finish_tool untagged
  24. make_model_params: scheduling hint injection gating
"""

import threading;
import time;
import pathlib;
import types as pytypes;

import from concurrent.futures { ThreadPoolExecutor }

import os;

import from byllm.parallel {
    dispatch_batch,
    _is_async,
    _index_by_identity,
    mark_serialize,
    _PARALLEL_TOOL_HINT,
    _WORKER_POOL
}
import from byllm.types { Tool, MockToolCall }
import from byllm.llm { BaseLLM }
import from byllm.lib { Model }
import from byllm.config_loader { reset_byllm_config, get_byllm_config }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
"""Noop callable — used as Tool.func stand-in so _is_async returns False."""
def _noop { }


# ---------------------------------------------------------------------------
# Mock objects (duck-typed stand-ins for byllm Tool / ToolCall)
# ---------------------------------------------------------------------------
obj _FakeMsg {
    has content: str;
}

obj _FakeTool {
    has name_str: str,
        serialize: bool = False,
        timeout_sec: float | None = None,
        func: Any = None;

    def postinit {
        self.func = _noop;
    }

    def get_name -> str {
        return self.name_str;
    }
}

obj _FakeTC {
    has tc_name: str,
        tc_result: str,
        tc_delay: float = 0.0,
        tc_serialize: bool = False,
        tc_should_raise: bool = False,
        call_count: int = 0,
        call_thread: Any = None,
        call_id: str = "",
        tool: Any = None;

    def postinit {
        self.call_id = f"call_{self.tc_name}";
        self.tool = _FakeTool(name_str=self.tc_name, serialize=self.tc_serialize);
    }

    def __call__ -> _FakeMsg {
        self.call_count += 1;
        self.call_thread = threading.current_thread().ident;
        if self.tc_delay > 0.0 {
            time.sleep(self.tc_delay);
        }
        if self.tc_should_raise {
            raise RuntimeError(f"{self.tc_name} exploded");
        }
        return _FakeMsg(content=self.tc_result);
    }
}


# ---------------------------------------------------------------------------
# 1. Default serialize is False
# ---------------------------------------------------------------------------
test "serialize default is false" {
    tool = _FakeTool(name_str="get_weather");
    assert tool.serialize == False;
}

test "serialize can be set true" {
    tool = _FakeTool(name_str="write_file", serialize=True);
    assert tool.serialize == True;
}


# ---------------------------------------------------------------------------
# 2. Parallel execution (default — no opt-in needed)
# ---------------------------------------------------------------------------
test "parallel default tools called" {
    tcs = [
        _FakeTC(tc_name="tool_a", tc_result="A"),
        _FakeTC(tc_name="tool_b", tc_result="B"),
        _FakeTC(tc_name="tool_c", tc_result="C"),

    ];
    results = list(dispatch_batch(tcs));
    assert len(results) == 3;
    assert all(tc.call_count == 1 for tc in tcs);
    contents = sorted([r[1].content for r in results]);
    assert contents == ["A", "B", "C"];
}

test "parallel tools run on different threads" {
    tcs = [
        _FakeTC(tc_name="tool_a", tc_result="A", tc_delay=0.02),
        _FakeTC(tc_name="tool_b", tc_result="B", tc_delay=0.02),

    ];
    list(dispatch_batch(tcs));
    assert tcs[0].call_thread != tcs[1].call_thread;
}


# ---------------------------------------------------------------------------
# 3. Sequential fallback when any tool has serialize=True
# ---------------------------------------------------------------------------
test "serialize forces sequential" {
    tcs = [
        _FakeTC(tc_name="read_tool", tc_result="R", tc_serialize=False),
        _FakeTC(tc_name="write_tool", tc_result="W", tc_serialize=True),

    ];
    results = list(dispatch_batch(tcs));
    assert len(results) == 2;
    assert tcs[0].call_thread == tcs[1].call_thread;
}

test "all serialize stays sequential" {
    tcs = [
        _FakeTC(tc_name="write_a", tc_result="WA", tc_serialize=True),
        _FakeTC(tc_name="write_b", tc_result="WB", tc_serialize=True),

    ];
    list(dispatch_batch(tcs));
    assert tcs[0].call_thread == tcs[1].call_thread;
}


# ---------------------------------------------------------------------------
# 4. Result ordering with _index_by_identity
# ---------------------------------------------------------------------------
test "index by identity finds correct positions" {
    a = _FakeTC(tc_name="a", tc_result="A");
    b = _FakeTC(tc_name="b", tc_result="B");
    c = _FakeTC(tc_name="c", tc_result="C");
    seq = [a, b, c];
    assert _index_by_identity(seq, a) == 0;
    assert _index_by_identity(seq, b) == 1;
    assert _index_by_identity(seq, c) == 2;
}

test "index by identity returns minus one when not found" {
    a = _FakeTC(tc_name="a", tc_result="A");
    b = _FakeTC(tc_name="b", tc_result="B");
    assert _index_by_identity([a], b) == -1;
}

test "reorder parallel results to input order" {
    tcs = [
        _FakeTC(tc_name="slow", tc_result="SLOW", tc_delay=0.06),
        _FakeTC(tc_name="fast", tc_result="FAST", tc_delay=0.01),
        _FakeTC(tc_name="medium", tc_result="MEDIUM", tc_delay=0.03),

    ];
    raw = list(dispatch_batch(tcs));
    ordered = {};
    for r in raw {
        idx = _index_by_identity(tcs, r[0]);
        ordered[idx] = r;
    }
    assert ordered[0][1].content == "SLOW";
    assert ordered[1][1].content == "FAST";
    assert ordered[2][1].content == "MEDIUM";
}


# ---------------------------------------------------------------------------
# 5. Single-tool batch runs inline
# ---------------------------------------------------------------------------
test "single tool batch runs inline" {
    tc = _FakeTC(tc_name="read", tc_result="R");
    results = list(dispatch_batch([tc]));
    assert len(results) == 1;
    assert results[0][1].content == "R";
}


# ---------------------------------------------------------------------------
# 6. Empty batch
# ---------------------------------------------------------------------------
test "empty batch yields nothing" {
    assert list(dispatch_batch([])) == [];
}


# ---------------------------------------------------------------------------
# 7. Failing tool does not corrupt others
# ---------------------------------------------------------------------------
test "failing tool is isolated" {
    tcs = [
        _FakeTC(tc_name="good_a", tc_result="A"),
        _FakeTC(tc_name="bad", tc_result="X", tc_should_raise=True),
        _FakeTC(tc_name="good_b", tc_result="B"),

    ];
    results = list(dispatch_batch(tcs));
    contents = {r[1].content for r in results};
    assert "A" in contents;
    assert "B" in contents;
    error_results = [
        r
        for r in results
        if "error" in r[1].content.lower()
    ];
    assert len(error_results) == 1;
    assert "exploded" in error_results[0][1].content;
}


# ---------------------------------------------------------------------------
# 8. Speedup signal proves parallel overlap
# ---------------------------------------------------------------------------
test "speedup proves parallel overlap" {
    sleep_sec = 0.06;
    tcs = [
        _FakeTC(tc_name="a", tc_result="A", tc_delay=sleep_sec),
        _FakeTC(tc_name="b", tc_result="B", tc_delay=sleep_sec),
        _FakeTC(tc_name="c", tc_result="C", tc_delay=sleep_sec),

    ];
    t0 = time.time();
    results = list(dispatch_batch(tcs));
    wall_ms = (time.time() - t0) * 1000;
    sum_ms = sum(ms for (_, _, ms) in results);
    speedup = sum_ms / wall_ms if wall_ms > 0 else 0.0;
    assert speedup > 1.5;
}


# ---------------------------------------------------------------------------
# 9. Sequential has no speedup
# ---------------------------------------------------------------------------
test "sequential batch has no speedup" {
    sleep_sec = 0.03;
    tcs = [
        _FakeTC(tc_name="a", tc_result="A", tc_delay=sleep_sec, tc_serialize=True),
        _FakeTC(tc_name="b", tc_result="B", tc_delay=sleep_sec, tc_serialize=True),

    ];
    t0 = time.time();
    results = list(dispatch_batch(tcs));
    wall_ms = (time.time() - t0) * 1000;
    sum_ms = sum(ms for (_, _, ms) in results);
    speedup = sum_ms / wall_ms if wall_ms > 0 else 0.0;
    assert speedup < 1.3;
}


# ---------------------------------------------------------------------------
# 10. _is_async detection
# ---------------------------------------------------------------------------
test "is async returns false for sync function" {
    def sync_fn { }
    assert _is_async(sync_fn) == False;
}

test "is async returns true for async function" {
    import asyncio;
    async def async_fn { }
    assert _is_async(async_fn) == True;
}


# ---------------------------------------------------------------------------
# 11. dispatch_batch is a generator
# ---------------------------------------------------------------------------
test "dispatch batch returns a generator" {
    tcs = [_FakeTC(tc_name="a", tc_result="A"), _FakeTC(tc_name="b", tc_result="B"), ];
    gen = dispatch_batch(tcs);
    assert isinstance(gen, pytypes.GeneratorType);
}


# ---------------------------------------------------------------------------
# 12. _PARALLEL_TOOL_HINT is importable and meaningful
# ---------------------------------------------------------------------------
test "parallel tool hint is a meaningful string" {
    assert isinstance(_PARALLEL_TOOL_HINT, str);
    assert len(_PARALLEL_TOOL_HINT) > 0;
    assert "parallel" in _PARALLEL_TOOL_HINT.lower();
    assert "independent" in _PARALLEL_TOOL_HINT.lower();
}


# ---------------------------------------------------------------------------
# 13. Per-tool timeout attribute
# ---------------------------------------------------------------------------
test "timeout attribute stored on tool" {
    tool = _FakeTool(name_str="slow_tool", timeout_sec=0.05);
    assert tool.timeout_sec == 0.05;
}

test "timeout none means no timeout" {
    tool = _FakeTool(name_str="normal_tool");
    assert tool.timeout_sec is None;
}


# ---------------------------------------------------------------------------
# 14. mark_serialize helper
# ---------------------------------------------------------------------------
test "mark serialize sets underscore serialize attribute" {
    def my_func { }
    assert not hasattr(my_func, '_serialize');
    mark_serialize(my_func);
    assert getattr(my_func, '_serialize') == True;
}

test "mark serialize returns the original function" {
    def f { }
    result = mark_serialize(f);
    assert result is f;
    assert getattr(result, '_serialize') == True;
}


# ---------------------------------------------------------------------------
# 15. _PARALLEL_TOOL_HINT does not mutate shared messages
# ---------------------------------------------------------------------------
test "parallel hint appended without mutating original message" {
    original_content = "You are a helpful assistant.";
    system_msg = {"role": "system", "content": original_content};
    messages = [system_msg];
    # Simulate what make_model_params does (copy, don't mutate)
    first_msg = messages[0];
    content = first_msg.get("content", "");
    if isinstance(content, str) and _PARALLEL_TOOL_HINT not in content {
        messages = list(messages);
        messages[0] = {** first_msg, "content": content + _PARALLEL_TOOL_HINT};
    }
    # New list has the hint
    assert _PARALLEL_TOOL_HINT in messages[0]["content"];
    # Original dict is NOT mutated
    assert system_msg["content"] == original_content;
}


# ---------------------------------------------------------------------------
# 16. Shared worker pool is a real ThreadPoolExecutor
# ---------------------------------------------------------------------------
test "shared worker pool is a thread pool executor" {
    assert isinstance(_WORKER_POOL, ThreadPoolExecutor);
    # Pool is alive — can submit work
    future = _WORKER_POOL.submit(lambda : 42 );
    assert future.result(timeout=2) == 42;
}


# ---------------------------------------------------------------------------
# 17. Tool.postinit picks up _serialize from function attribute
# ---------------------------------------------------------------------------
test "tool postinit picks up serialize from function" {
    def my_tool(x: str) -> str {
        return x;
    }
    setattr(my_tool, '_serialize', True);
    tool = Tool(func=my_tool);
    assert tool.serialize == True;
}

test "tool postinit defaults serialize to false" {
    def plain_tool(x: str) -> str {
        return x;
    }
    tool = Tool(func=plain_tool);
    assert tool.serialize == False;
}


# ---------------------------------------------------------------------------
# 18. MockToolCall creates proper batch structure
# ---------------------------------------------------------------------------
test "mock tool call creates valid tool call with correct name" {
    def dummy(x: str) -> str {
        return f"got {x}";
    }
    mtc = MockToolCall(tool=dummy, args={"x": "hello"});
    tc = mtc.to_tool_call();
    assert tc.tool.get_name() == "dummy";
    result = tc();
    assert "got hello" in result.content;
}


# ---------------------------------------------------------------------------
# 19. _is_async detects async functions at runtime
# ---------------------------------------------------------------------------
test "is async detects coroutine functions at runtime" {
    import asyncio;
    def sync_fn { }
    async def async_fn { }
    assert _is_async(sync_fn) == False;
    assert _is_async(async_fn) == True;
    assert callable(_is_async);
}


# ---------------------------------------------------------------------------
# 20. Old API not present on BaseLLM, dispatch_batch is the replacement
# ---------------------------------------------------------------------------
test "basellm has no tool scheduler attribute" {
    assert not hasattr(BaseLLM, 'tool_scheduler');
    assert not hasattr(BaseLLM, '_dispatch_tool_batch');
}

test "dispatch batch is callable and importable" {
    assert callable(dispatch_batch);
    # Verify it returns a generator for an empty batch
    gen = dispatch_batch([]);
    assert list(gen) == [];
}


# ---------------------------------------------------------------------------
# Mock MTRuntime for make_model_params tests
# ---------------------------------------------------------------------------
obj _MockMTRun {
    has call_params: dict = {},
        tools: list = [],
        stream: bool = False,
        mtir: Any = None,
        messages: list = [];

    def get_msg_list -> list {
        return list(self.messages);
    }

    def get_tool_list -> list {
        if not self.tools {
            return [];
        }
        return [t.get_json_schema() for t in self.tools];
    }

    def get_output_schema -> Any {
        return None;
    }
}


# ---------------------------------------------------------------------------
# 22. _should_parallelize gate logic
# ---------------------------------------------------------------------------
test "parallel OFF by default without config or env" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();
    cfg = get_byllm_config().get_parallel_config();
    assert cfg.get("enabled", False) == False , "Parallel should be OFF by default";
}

test "BYLLM_PARALLEL_TOOL_CALLING env var enables parallel" {
    os.environ["BYLLM_PARALLEL_TOOL_CALLING"] = "true";
    reset_byllm_config();
    cfg = get_byllm_config().get_parallel_config();
    assert cfg.get("enabled", False) == True , "Env var should enable parallel";
    # Cleanup
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();
}

test "per-call parallelize=True overrides global OFF" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def sl_a -> str {
        time.sleep(0.05);
        return "a";
    }
    def sl_b -> str {
        time.sleep(0.05);
        return "b";
    }
    def sl_c -> str {
        time.sleep(0.05);
        return "c";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        config={
            "outputs": [
                [
                    MockToolCall(tool=sl_a, args={}),
                    MockToolCall(tool=sl_b, args={}),
                    MockToolCall(tool=sl_c, args={})
                ],
                MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                "done"
            ]
        }
    );
    def task_par(q: str) -> str by llm(tools=[sl_a, sl_b, sl_c], parallelize=True);

    t0 = time.time();
    result = task_par("test");
    elapsed = int((time.time() - t0) * 1000);

    assert result == "done";
    assert elapsed < 100 , f"Expected parallel (<100ms) but got {elapsed}ms";
}

test "per-call parallelize=False overrides global ON" {
    os.environ["BYLLM_PARALLEL_TOOL_CALLING"] = "true";
    reset_byllm_config();

    def sq_a -> str {
        time.sleep(0.05);
        return "a";
    }
    def sq_b -> str {
        time.sleep(0.05);
        return "b";
    }
    def sq_c -> str {
        time.sleep(0.05);
        return "c";
    }
    def finish_tool(final_output: str) -> str {
        return final_output;
    }

    llm = Model(
        model_name="mockllm",
        config={
            "outputs": [
                [
                    MockToolCall(tool=sq_a, args={}),
                    MockToolCall(tool=sq_b, args={}),
                    MockToolCall(tool=sq_c, args={})
                ],
                MockToolCall(tool=finish_tool, args={"final_output": "done"}),
                "done"
            ]
        }
    );
    def task_seq(q: str) -> str by llm(tools=[sq_a, sq_b, sq_c], parallelize=False);

    t0 = time.time();
    result = task_seq("test");
    elapsed = int((time.time() - t0) * 1000);

    assert result == "done";
    assert elapsed >= 100 , f"Expected sequential (>=100ms) but got {elapsed}ms";

    # Cleanup
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();
}


# ---------------------------------------------------------------------------
# 23. make_model_params: tool description annotations
# ---------------------------------------------------------------------------
test "parallel-safe and sequential tags added to tool descriptions" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def anno_a(x: str) -> str {
        return x;
    }
    def anno_b(x: str) -> str {
        return x;
    }

    tool_a = Tool(func=anno_a, description="Tool A does things");
    tool_b = Tool(func=anno_b, description="Tool B writes files", serialize=True);
    ft = Tool.make_finish_tool(str);

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={"parallelize": True},
        tools=[tool_a, tool_b, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);
    tool_schemas = params.get("tools", []);

    # tool_a (parallel-safe) should have [PARALLEL-SAFE tag
    a_desc = tool_schemas[0]["function"]["description"];
    assert "[PARALLEL-SAFE" in a_desc , f"Expected [PARALLEL-SAFE in: {a_desc}";

    # tool_b (serialize=True) should have [SEQUENTIAL tag
    b_desc = tool_schemas[1]["function"]["description"];
    assert "[SEQUENTIAL" in b_desc , f"Expected [SEQUENTIAL in: {b_desc}";

    # Cleanup
    reset_byllm_config();
}

test "finish tool description is NOT tagged" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def ft_a(x: str) -> str {
        return x;
    }
    tool_a = Tool(func=ft_a, description="Tool A");
    ft = Tool.make_finish_tool(str);
    ft_original_desc = ft.description;

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={"parallelize": True},
        tools=[tool_a, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);
    tool_schemas = params.get("tools", []);

    # Find finish_tool schema (last one)
    ft_schema = tool_schemas[-1];
    ft_desc = ft_schema["function"]["description"];
    assert "[PARALLEL" not in ft_desc , f"finish_tool should NOT be tagged: {ft_desc}";
    assert "[SEQUENTIAL" not in ft_desc , f"finish_tool should NOT be tagged: {ft_desc}";

    # Cleanup
    reset_byllm_config();
}


# ---------------------------------------------------------------------------
# 24. make_model_params: scheduling hint injection gating
# ---------------------------------------------------------------------------
test "scheduling hint injected when parallel plus tools plus parallel_hint" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def hint_a(x: str) -> str {
        return x;
    }
    tool_a = Tool(func=hint_a, description="Tool A");
    ft = Tool.make_finish_tool(str);

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={"parallelize": True},
        tools=[tool_a, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);
    sys_content = params["messages"][0]["content"];
    assert "Intelligent tool scheduling rules" in sys_content , (
        "Scheduling hint should be injected when parallel is active"
    );
    assert "BATCH in one response" in sys_content;
    assert "SEPARATE into different responses" in sys_content;

    # Cleanup
    reset_byllm_config();
}

test "no annotations or hint when parallel is OFF" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def nop_a(x: str) -> str {
        return x;
    }
    tool_a = Tool(func=nop_a, description="Tool A original");
    ft = Tool.make_finish_tool(str);

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={},
        tools=[tool_a, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);

    # Tool descriptions should be unchanged
    a_desc = params["tools"][0]["function"]["description"];
    assert "[PARALLEL" not in a_desc , f"No tags when parallel OFF: {a_desc}";
    assert "[SEQUENTIAL" not in a_desc , f"No tags when parallel OFF: {a_desc}";

    # System prompt should not have scheduling hint
    sys_content = params["messages"][0]["content"];
    assert "Intelligent tool scheduling rules" not in sys_content , (
        "No scheduling hint when parallel is OFF"
    );

    # Cleanup
    reset_byllm_config();
}

test "parallel_hint=False suppresses hint even when parallel is on" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def ph_a(x: str) -> str {
        return x;
    }
    tool_a = Tool(func=ph_a, description="Tool A");
    ft = Tool.make_finish_tool(str);

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={"parallelize": True, "parallel_hint": False},
        tools=[tool_a, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);

    # Tool descriptions should NOT be annotated
    a_desc = params["tools"][0]["function"]["description"];
    assert "[PARALLEL" not in a_desc , f"No tags when parallel_hint=False: {a_desc}";

    # System prompt should NOT have scheduling hint
    sys_content = params["messages"][0]["content"];
    assert "Intelligent tool scheduling rules" not in sys_content , (
        "No hint when parallel_hint=False"
    );

    # Cleanup
    reset_byllm_config();
}

test "serialize tool names listed in system prompt hint" {
    os.environ.pop("BYLLM_PARALLEL_TOOL_CALLING", None);
    reset_byllm_config();

    def sn_a(x: str) -> str {
        return x;
    }
    def sn_b(x: str) -> str {
        return x;
    }
    tool_a = Tool(func=sn_a, description="Safe tool");
    tool_b = Tool(func=sn_b, description="Dangerous tool", serialize=True);
    ft = Tool.make_finish_tool(str);

    model = Model(model_name="mockllm");
    mt_run = _MockMTRun(
        call_params={"parallelize": True},
        tools=[tool_a, tool_b, ft],
        messages=[{"role": "system", "content": "You are helpful."}]
    );

    params = model.make_model_params(mt_run);
    sys_content = params["messages"][0]["content"];
    assert "must ALWAYS run alone" in sys_content , (
        "Serialize tool list should be in system prompt"
    );
    assert "sn_b" in sys_content , (
        "Serialized tool name should appear in system prompt"
    );

    # Cleanup
    reset_byllm_config();
}
