import contextlib;
import io;
import os;
import sys;
import warnings;
import unittest.mock;

import yaml;
import from fixtures { python_lib_mode }

import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Image, Model, ModelPool, Video }
import types;
import from jaclang.byllm.mtir { MTRuntime }
import from jaclang.byllm.exceptions {
    OutputConversionError,
    ConfigurationError,
    FinishToolError,
    McpError
}
import from jaclang.byllm.mcp { McpClient, McpTool }
import from jaclang.byllm.types { Tool, Message, MessageRole }
import dataclasses;
import from jaclang { JacRuntimeInterface as Jac }
import from support_tests {
    FakeLLM,
    scripted,
    typed,
    finish,
    mk_run,
    say,
    tool_names,
    run_fixture,
    load_fixture,
    capture_logs,
    call as tool_call
}

glob jac_import = Jac.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


def _as_any(v: any) -> any {
    return v;
}


test "method tool call" {
    stdout_value = run_fixture("method_tool");
    assert "Calculator.add called with 12, 34" in stdout_value;
    assert "Result: 46" in stdout_value;
}


test "the deprecated method= parameter still runs and warns once" {
    llm = FakeLLM(replies=[say("test output")]);

    def simple_tool -> str {
        return "tool ran";
    }

    with warnings.catch_warnings(record=True) as w {
        warnings.simplefilter("always");
        def simple_task(query: str) -> str by llm(method="ReAct", tools=[simple_tool]);
        result = simple_task("hello");
    }
    assert result == "test output" , f"the call must still work, got {result!r}";
    deprecations = [
        x
        for x in w
        if issubclass(x.category, DeprecationWarning)
    ];
    assert len(deprecations) == 1 , (
        f"expected exactly one DeprecationWarning for method=, got {len(deprecations)}"
    );
    assert "'method' parameter is deprecated" in str(deprecations[0].message) , (
        f"got: {deprecations[0].message}"
    );
    assert "simple_tool" in tool_names(llm.seen[0]) , (
        "tools= must still be sent alongside the deprecated method="
    );
}


test "python lib mode" {
    person = python_lib_mode.test_get_person_info();
    assert "Alan Turing" in person.name;
    assert "1912" in str(person.birth_year);
    assert "A pioneering mathematician and computer scientist" in person.description;
    assert "breaking the Enigma code" in person.description;
}

test "enum without value" {
    import from loguru { logger }

    captured_output = io.StringIO();
    logger.remove();
    logger.add(captured_output);
    with contextlib.suppress(Exception) {
        jac_import("enum_no_value", base_path=FIXTURE_DIR + "/");
    }
    stdout_value = captured_output.getvalue();
    assert "YES" in stdout_value;
    assert "NO" in stdout_value;
}


test "visit by for routing" {
    stdout_value = run_fixture("math_poem_agents");
    assert "Agentic minds, we hold dear" in stdout_value;
    assert "Math Result: 35" in stdout_value;
}

test "streaming visit by routes and streams tokens to handler" {
    stdout_value = run_fixture("streaming_visit_by");
    assert "STREAMING_VISIT_BY_PASS" in stdout_value;

    assert "VISITED: green" in stdout_value;
    assert "VISITED: red" not in stdout_value;
}


test "api key resolves from constructor, then instance config, then global config" {
    for (why, global_key, kwargs, expected) in [
        ("constructor", None, {"api_key": "sk-constructor-key"}, "sk-constructor-key"),
        (
            "instance config",
            None,
            {"config": {"api_key": "sk-config-key"}},
            "sk-config-key"
        ),
        ("global config", "sk-global-key", {}, "sk-global-key"),
        (
            "constructor over instance config",
            None,
            {"api_key": "sk-constructor-key", "config": {"api_key": "sk-config-key"}},
            "sk-constructor-key"
        ),
        (
            "instance config over global",
            "sk-global-key",
            {"config": {"api_key": "sk-config-key"}},
            "sk-config-key"
        ),
        ("empty when none provided", "", {}, "")
    ] {
        overrides = {"api_key": global_key} if global_key is not None else {};
        with unittest.mock.patch.dict(
            _byllm_llm_mod._model_config, overrides, clear=True
        ) {
            model = Model(model_name="gpt-4o-mini", **kwargs);
        }
        assert model.api_key == expected , f"{why}: got {model.api_key!r}";
    }
}

test "api key not overwritten on dispatch" {
    model = Model(model_name="gpt-4o-mini", api_key="sk-test-key");
    _no_mt: any = None;
    with contextlib.suppress(Exception) {
        model(temperature=0.5).invoke(_no_mt);
    }
    assert model.api_key == "sk-test-key";
}

test "format_prompt never prints the api key and leaves params intact" {
    model = Model(model_name="gpt-4o-mini");
    params = {
        "model": "gpt-4o-mini",
        "api_key": "sk-test-secret-key1234",
        "api_base": None,
        "messages": [
            {"role": "system", "content": "test"},
            {"role": "user", "content": "test"}
        ],
        "tools": None,
        "response_format": None
    };
    log_output = model.format_prompt(params);
    assert "sk-test-secret-key1234" not in log_output;
    assert params["api_key"] == "sk-test-secret-key1234" , "format_prompt must not mutate params";
}

test "resolved api_base reaches the litellm call" {
    if not hasattr(_byllm_llm_mod.litellm, "completion") {
        testskip("litellm is not installed");
    }
    seen: dict[str, object] = {};

    def _fake_completion(**kwargs: object) -> dict[str, object] {
        seen.clear();
        seen.update(kwargs);
        return {
            "model": "gpt-4o-mini",
            "choices": [
                {
                    "message": {"role": "assistant", "content": "ok"},
                    "finish_reason": "stop"
                }
            ],
            "usage": {}
        };
    }
    def _dispatched_api_base(model: Model) -> any {
        with unittest.mock.patch.object(
            _byllm_llm_mod.litellm, "completion", _fake_completion
        ) {
            model.dispatch_no_streaming(mk_run(resp_type=str));
        }
        return seen.get("api_base");
    }
    configured = Model(
        model_name="gpt-4o-mini",
        api_key="sk-test",
        config={"base_url": "https://gateway.example.com/v1"}
    );
    assert _dispatched_api_base(configured) == "https://gateway.example.com/v1" , "a configured base_url must reach litellm";

    with unittest.mock.patch.dict(
        _byllm_llm_mod._model_config, {"base_url": ""}, clear=True
    ) {
        bare = Model(model_name="gpt-4o-mini", api_key="sk-test");
        assert _dispatched_api_base(bare) is None , "api_base must stay unset when nothing configures one";
    }
}


test "a verbose model logs the call without leaking the api key" {
    import from loguru { logger }
    secret = "sk-secret-test-key-do-not-leak";
    model = Model(model_name="gpt-4o-mini", api_key=secret, config={"verbose": True});

    def greet(name: str) -> str by model();

    log = io.StringIO();
    handler_id = logger.add(log);
    try {
        with scripted(model, [say("Hello, Alice!")]) {
            assert greet("Alice") == "Hello, Alice!";
        }
    } finally {
        logger.remove(handler_id);
    }
    log_value = log.getvalue();
    assert "Calling LLM" in log_value , f"a verbose model must log the call: {log_value[:300]}";
    assert secret not in log_value , "the api key must never reach the log";
}


test "builtin llm compiles without glob" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    try {
        jac_import("builtin_llm_no_override", base_path=FIXTURE_DIR + "/");
    } except Exception as e {
        assert "name 'llm' is not defined" not in str(e) , f"'llm' should be a recognized builtin, got: {e}";
    }
    sys.stdout = sys.__stdout__;
}

import from pathlib { Path }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.runtime.runtime { JacRuntime }

glob GEMINI_FIXTURE = os.path.join(FIXTURE_DIR, "jac_toml_gemini");


test "byllm config reads model from jac.toml" {
    reset_byllm_config();
    config = get_byllm_config(Path(GEMINI_FIXTURE));
    assert config.get_model_config()['default_model'] == "gemini/gemini-1.5-pro";
}

test "byllm config defaults to gpt-4o-mini when no jac.toml" {
    reset_byllm_config();
    config = get_byllm_config(Path(FIXTURE_DIR));
    assert config.get_model_config()['default_model'] == "gpt-4o-mini";
}

test "byllm config uses full_target_path to find jac.toml regardless of cwd" {
    orig = JacRuntime.get_full_target_path();
    orig_cwd = os.getcwd();
    JacRuntime.set_full_target_path(os.path.join(GEMINI_FIXTURE, "main.jac"));
    reset_byllm_config();
    os.chdir("/tmp");
    try {
        config = get_byllm_config();
        assert config.get_model_config()['default_model'] == "gemini/gemini-1.5-pro";
    } finally {
        os.chdir(orig_cwd);
        JacRuntime.set_full_target_path(orig);
        reset_byllm_config();
    }
}

glob _TestPerson = dataclasses.make_dataclass(
         "Person", [("name", str), ("age", int)]
     ),
     _TestUnionField = dataclasses.make_dataclass("UnionField", [("value", str | int)]),
     _TestFieldless = dataclasses.make_dataclass("Fieldless", []);

test "parse_response raises OutputConversionError with the raw output attached" {
    for (why, raw) in [
        ("plain text", "Alice is a 30 year old engineer."),
        ("markdown fenced json", "```json\n{\"name\": \"Alice\", \"age\": 30}\n```"),
        ("wrong json structure", "{\"foo\": \"bar\", \"baz\": 99}")
    ] {
        raised = False;
        try {
            mk_run(resp_type=_TestPerson).parse_response(raw);
        } except OutputConversionError as e {
            raised = True;
            err: any = e;
            assert err.raw_output == raw , (
                f"{why}: raw_output should carry the model output, got '{err.raw_output}'"
            );
            assert "Person" in str(e) , f"{why}: error message should name the target type";
        }
        assert raised , f"{why}: expected OutputConversionError";
    }
}

test "parse_response passes through str returns and valid typed json" {
    raw = "This is not JSON at all";
    assert mk_run(resp_type=str).parse_response(raw) == raw , (
        "str return type should return the raw response as-is"
    );
    person = mk_run(resp_type=_TestPerson).parse_response(
        "{\"schema_object_wrapper\": {\"name\": \"Alice\", \"age\": 30}}"
    );
    assert (person.name, person.age) == ("Alice", 30) , f"got {person}";
}

test "bare container return types are a configuration error" {
    for bare in [list, dict] {
        raised = False;
        try {
            mk_run(resp_type=bare).get_output_schema();
        } except ConfigurationError as e {
            raised = True;
            assert bare.__name__ in str(e).lower() , (
                f"error message should mention '{bare.__name__}', got: {e}"
            );
        }
        assert raised , f"expected ConfigurationError for bare {bare.__name__}";
    }
}

test "unregistered tool call is recovered not fatal" {
    model = Model(model_name="test-model");
    # resp_type is immaterial here; the subject is how an unknown tool name is
    # handled, so the default str return keeps the run valid.
    mt_run = mk_run(finish=False);

    fake_fn = types.SimpleNamespace(name="nonexistent_tool", arguments="{}");
    fake_tool_call = types.SimpleNamespace(id="call_abc", function=fake_fn);
    fake_response = {
        "choices": [{"message": {"content": None, "tool_calls": [fake_tool_call]}}],

    };

    with unittest.mock.patch.object(
        model, "model_call_no_stream", return_value=fake_response
    ) {
        result = model.dispatch_no_streaming(mt_run);
    }

    assert len(result.tool_calls) == 1 , "Expected one recovered tool call";
    err_result = result.tool_calls[0]();
    assert "nonexistent_tool" in str(err_result.content) , (
        f"Recovered result should name the tool, got: {err_result.content}"
    );
    assert "Tool error" in str(err_result.content) , (
        f"Recovered result should be a tool error, got: {err_result.content}"
    );
}

test "finish tool error on type mismatch" {
    finish_tool = Tool.make_finish_tool(_TestPerson);

    raised = False;
    try {
        finish_tool({"wrong_key": "value"});
    } except FinishToolError as e {
        raised = True;
        assert "Person" in str(e) , f"Error should name the target type, got: {e}";
    }
    assert raised , "Expected FinishToolError for mismatched input type";
}

test "finish tool error not raised for valid type" {
    finish_tool = Tool.make_finish_tool(_TestPerson);
    result = finish_tool({"name": "Alice", "age": 30});
    assert result.name == "Alice" , f"Expected name='Alice', got '{result.name}'";
    assert result.age == 30 , f"Expected age=30, got '{result.age}'";
}

test "finish tool argument resolution heals recoverable shapes" {
    finish_tool = Tool.make_finish_tool(_TestPerson);
    person = {"name": "Bob", "age": 25};
    for (sent, why) in [
        ({"final_output": person}, "canonical name"),
        ({"output": person}, "misnamed argument"),
        (person, "flattened kwargs")
    ] {
        parsed = finish_tool.parse_arguments(sent);
        assert parsed["final_output"].name == "Bob" , f"{why}: got {parsed}";
    }
    bare = Tool.make_finish_tool(str).parse_arguments("just the answer");
    assert bare == {"final_output": "just the answer"} , f"bare payload: got {bare}";

    self_named = dataclasses.make_dataclass(
        "_SelfNamed", [("final_output", str), ("score", int)]
    );
    parsed = Tool.make_finish_tool(self_named).parse_arguments(
        {"final_output": "ok", "score": 5}
    );
    assert parsed["final_output"].score == 5 , f"self-named flattened: got {parsed}";
}

test "unusable tool arguments raise recoverable errors" {
    finish_tool = Tool.make_finish_tool(_TestPerson);
    def _sample_tool(city: str) -> str {
        return city;
    }
    regular = Tool(func=_sample_tool);
    for (tool, sent, needle) in [
        (finish_tool, {}, "final_output"),
        (finish_tool, {"a": 1, "b": 2}, "final_output"),
        (regular, {"location": "Paris"}, "'city'"),
        (regular, {"return": "Paris"}, "'city'"),
        (regular, ["Paris"], "JSON object")
    ] {
        raised = False;
        try {
            tool.parse_arguments(sent);
        } except ValueError as e {
            raised = True;
            assert needle in str(e) , f"{sent}: got {e}";
        }
        assert raised , f"Expected ValueError for {sent}";
    }
}

test "finish tool invocation failure raises FinishToolError not TypeError" {
    finish_tool = Tool.make_finish_tool(_TestPerson);
    raised = False;
    try {
        finish_tool();
    } except FinishToolError as e {
        raised = True;
        assert "final_output" in str(e) , f"got: {e}";
    }
    assert raised , "Expected FinishToolError for argument-less finish call";
}

glob _WELL_FORMED_FINISH = '{"final_output": {"name": "Amy", "age": 30}}',
     _HEALABLE_FINISH = '{"output": {"name": "Dana", "age": 33}}',
     _UNUSABLE_FINISH = '{"a": 1, "b": 2}';

test "dispatch heals a misnamed finish argument and recovers an unusable one" {
    import asyncio;
    for (why, arguments, use_async, expect_typed) in [
        ("sync healed", _HEALABLE_FINISH, False, True),
        ("async healed", _HEALABLE_FINISH, True, True),
        ("sync unusable", _UNUSABLE_FINISH, False, False),
        ("async unusable", _UNUSABLE_FINISH, True, False)
    ] {
        llm = FakeLLM(
            model_name="test-model", replies=[tool_call("finish_tool", arguments)]
        );
        mt_run = mk_run(resp_type=_TestPerson, finish=True);
        result: any = None;
        if use_async {
            coro: any = llm.adispatch_no_streaming(mt_run);
            result = asyncio.run(coro);
        } else {
            result = llm.dispatch_no_streaming(mt_run);
        }
        tc = result.tool_calls[0];
        if expect_typed {
            assert tc.is_finish_call() , f"{why}: healed call should still be the finish call";
            assert tc.get_output().name == "Dana" , f"{why}: expected healed typed output";
        } else {
            assert not tc.is_finish_call() , (
                f"{why}: recovered error call must not masquerade as the finish call"
            );
            content = str(tc().content);
            assert "Tool error" in content and "final_output" in content , f"{why}: got: {content}";
        }
    }
}

test "response format requests always carry the json word" {
    def _params(resp_type: type, tools: list) -> dict {
        model = Model(model_name="test-model");
        mt_run = mk_run(resp_type=resp_type, tools=tools, finish=False);
        return model.make_model_params(mt_run);
    }
    for (label, resp_type, tools, want_rf) in [
        ("typed no tools", _TestPerson, [], True),
        ("scalar no tools", int, [], True),
        ("union field", _TestUnionField, [], True),
        ("fieldless obj", _TestFieldless, [], True),
        ("plain str", str, [], False),
        ("typed with tools", _TestPerson, [Tool.make_finish_tool(_TestPerson)], False)
    ] {
        params = _params(resp_type, tools);
        has_rf = params.get("response_format") is not None;
        has_json = "json" in str(params.get("messages", [])).lower();
        assert has_rf == want_rf , f"{label}: unexpected response_format={has_rf}";
        assert has_json == want_rf , f"{label}: json-word={has_json} but rf={has_rf}";
    }
}

test "litellm debug config toggles litellm's verbose loggers" {
    import from litellm._logging {
        verbose_logger,
        verbose_router_logger,
        verbose_proxy_logger
    }
    loggers = [verbose_logger, verbose_router_logger, verbose_proxy_logger];
    for (debug, expect_disabled) in [(False, True), (True, False)] {
        for lg in loggers {
            lg.disabled = False;
        }
        with unittest.mock.patch.dict(
            _byllm_llm_mod._litellm_config,
            {"debug": debug, "drop_params": True},
            clear=True
        ) {
            Model(model_name="gpt-4o-mini");
        }
        for lg in loggers {
            assert lg.disabled == expect_disabled , (
                f"debug={debug}: {lg.name} disabled={lg.disabled}"
            );
        }
    }
}

test "litellm debug defaults to False and get_litellm_config exposes it" {
    import from jaclang.byllm.config_loader { JacByllmConfig }
    config = JacByllmConfig();
    assert config.get_default_config()["litellm"]["debug"] == False , (
        "litellm debug should default to False"
    );
    assert isinstance(config.get_litellm_config().get("debug"), bool) , (
        "get_litellm_config should expose 'debug' as a bool"
    );
}

import litellm;
import from jaclang.byllm.exceptions {
    AuthenticationError,
    RateLimitError,
    ModelNotFoundError
}

import from loguru { logger as _loguru_logger }

test "provider errors map to byllm exceptions and log at ERROR regardless of debug" {
    rows: list = [
        (False, "AuthenticationError", AuthenticationError, "Invalid API key"),
        (True, "RateLimitError", RateLimitError, "Rate limit exceeded"),
        (False, "RateLimitError", RateLimitError, "quota exceeded"),
        (False, "NotFoundError", ModelNotFoundError, "model not found")
    ];
    for (debug, litellm_name, expected, message) in rows {
        provider_error = getattr(litellm.exceptions, litellm_name)(
            message=message, llm_provider="openai", model="gpt-4o-mini"
        );
        log_output = io.StringIO();
        _loguru_logger.remove();
        handler_id = _loguru_logger.add(log_output, level="ERROR");
        raised: any = None;
        try {
            with unittest.mock.patch.dict(
                _byllm_llm_mod._litellm_config,
                {"debug": debug, "drop_params": True},
                clear=True
            ) {
                model = Model(model_name="gpt-4o-mini");
                with unittest.mock.patch(
                    "litellm.completion", side_effect=provider_error
                ) {
                    try {
                        model.model_call_no_stream(
                            {"model": "gpt-4o-mini", "messages": []}
                        );
                    } except Exception as e {
                        raised = e;
                    }
                }
            }
        } finally {
            _loguru_logger.remove(handler_id);
        }
        why = f"debug={debug} litellm.{litellm_name}";
        assert isinstance(raised, expected) , (
            f"{why}: expected byllm's {expected.__name__}, got {type(
                raised
            ).__module__}.{raised!r}"
        );
        assert message in str(raised) , f"{why}: message lost, got {raised}";
        assert f"LLM {expected.__name__}" in log_output.getvalue() , (
            f"{why}: logger.error should record it, got: {log_output.getvalue()}"
        );
    }
}


glob _dummy_mcp_client = McpClient(url="http://example.invalid/mcp");

test "McpTool implements Tool interface" {
    tool = McpTool(
        name="get_weather",
        description="Fetch weather for a city.",
        input_schema={
            "type": "object",
            "properties": {"city": {"type": "string"}},
            "required": ["city"]
        },
        _client=_dummy_mcp_client
    );
    assert tool.get_name() == "get_weather";
    assert not tool.is_finish_tool();

    assert tool.parse_arguments({"city": "Paris"}) == {"city": "Paris"};
}

test "McpTool.get_json_schema wraps MCP inputSchema in OpenAI envelope" {
    input_schema = {
        "type": "object",
        "properties": {"q": {"type": "string"}},
        "required": ["q"]
    };
    tool = McpTool(
        name="search",
        description="Search the web.",
        input_schema=input_schema,
        _client=_dummy_mcp_client
    );
    schema = tool.get_json_schema();
    assert schema["type"] == "function";
    assert schema["function"]["name"] == "search";
    assert schema["function"]["description"] == "Search the web.";
    assert schema["function"]["parameters"] == input_schema;
}

test "McpTool plugs into MTRuntime.get_tool() polymorphically" {
    mcp_tool = McpTool(
        name="lookup",
        description="Look something up.",
        input_schema={"type": "object", "properties": {}},
        _client=_dummy_mcp_client
    );
    mt_run = mk_run(messages=[], finish=False);

    getattr(mt_run, "tools").append(mcp_tool);
    found = mt_run.get_tool("lookup");
    assert found is mcp_tool , "MTRuntime.get_tool should resolve McpTool by name";
    assert mt_run.get_tool("nonexistent") is None;

    schemas = mt_run.get_tool_list();
    assert len(schemas) == 1;
    assert schemas[0]["function"]["name"] == "lookup";
}

test "McpClient errors when neither command nor url is set" {
    client = McpClient();
    err: McpError | None = None;
    try {
        client.connect();
    } except McpError as e {
        err = e;
    }
    assert err is not None , "McpClient must require command or url";
}

test "McpClient raises McpError when mcp package is missing" {
    with unittest.mock.patch.dict(
        sys.modules, {"mcp": None, "mcp.client": None, "mcp.client.session": None}
    ) {
        client = McpClient(command="echo", args=["test"]);
        err: McpError | None = None;
        try {
            client.connect();
        } except McpError as e {
            err = e;
        }
        assert err is not None , "connect() must raise McpError when mcp is not installed";
        assert "pip install" in str(err);
    }
}


import from jaclang.byllm.llm {
    _is_prompt_caching_eligible,
    _apply_prompt_caching,
    _CACHE_CONTROL_EPHEMERAL
}

test "prompt caching marks system, last non-system message, and last tool for anthropic models" {
    assert _is_prompt_caching_eligible("anthropic/claude-sonnet-4-20250514") == True;
    assert _is_prompt_caching_eligible("claude-3-opus-20240229") == True;
    assert _is_prompt_caching_eligible("gpt-4o") == False;

    messages = [
        {"role": "system", "content": "You are an agent."},
        {"role": "user", "content": "Do something"},
        {"role": "assistant", "content": "Calling a tool."},
        {
            "role": "tool",
            "content": [
                {"type": "text", "text": "first"},
                {"type": "text", "text": "last"}
            ]
        }
    ];
    tools = [
        {"type": "function", "function": {"name": "read_file"}},
        {"type": "function", "function": {"name": "finish_tool"}}
    ];
    _apply_prompt_caching(messages, tools);

    assert messages[0].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;
    assert "cache_control" not in messages[1];
    assert "cache_control" not in messages[2];
    tool_content: any = messages[3].get("content");
    assert "cache_control" not in tool_content[0];
    assert tool_content[-1].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;

    assert "cache_control" not in tools[0];
    assert tools[-1].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;
}

test "prompt caching disabled via config" {
    with unittest.mock.patch.object(
        _byllm_llm_mod._byllm_config,
        'get_prompt_caching_config',
        return_value={'enabled': False}
    ) {
        assert _is_prompt_caching_eligible("anthropic/claude-sonnet-4-20250514")
            == False;
    }
}

test "_stream_final_answer keeps the tools array intact" {
    def tool_a(x: str) -> str {
        return x;
    }
    def tool_b(y: str) -> str {
        return y;
    }

    llm = FakeLLM(model_name="anthropic/claude-test", replies=[say("Done.")]);
    mt_run = mk_run(tools=[tool_a, tool_b], stream=True);
    expected = [t.get_name() for t in mt_run.tools];

    list(llm._stream_final_answer(mt_run));

    assert len(llm.seen) == 1;
    assert tool_names(llm.seen[0]) == expected , (
        "the narration call must send the same tools as the rest of the "
        "conversation, or Anthropic's cache prefix breaks"
    );
    assert llm.seen[0]["tool_choice"] == "none" , "must still forbid tool calls";
    assert [t.get_name() for t in mt_run.tools] == expected , "mt_run.tools was mutated";
}

test "finish_tool exit sends an identical tools payload on the narration call" {
    def search_files(query: str) -> str {
        return f"found: {query}";
    }

    llm = FakeLLM(
        model_name="anthropic/claude-test",
        replies=[finish("Fixed it."), say("Fixed it.")]
    );
    mt_run = mk_run(tools=[search_files], stream=True);

    list(llm._invoke_streaming(mt_run));

    sent = llm.sent("tools");
    assert len(sent) == 2 and llm.exhausted() , (
        f"expected exactly 2 LLM calls, got {len(sent)}"
    );
    assert sent[0] == sent[1] , (
        f"the narration call must send a byte-identical tools payload "
        f"(cache_control included); got {sent[1]} vs {sent[0]}"
    );
}

test "forced answer and recovery force finish_tool, keep the tools array, and heal" {
    def extra_tool(x: str) -> str {
        return x;
    }
    forced_choice = {"type": "function", "function": {"name": "finish_tool"}};

    for (why, arguments, expected_name) in [
        ("well-formed", _WELL_FORMED_FINISH, "Amy"),
        ("healable", _HEALABLE_FINISH, "Dana"),
        ("unusable", _UNUSABLE_FINISH, None)
    ] {
        expect_typed = expected_name is not None;
        llm = FakeLLM(
            model_name="anthropic/claude-test",
            replies=[tool_call("finish_tool", arguments)]
        );
        mt_run = mk_run(resp_type=_TestPerson, tools=[extra_tool]);
        expected = [t.get_name() for t in mt_run.tools];
        out: any = llm._force_final_answer(mt_run);
        assert tool_names(llm.seen[0]) == expected , (
            f"force {why}: sent {tool_names(llm.seen[0])}, expected {expected}"
        );
        assert llm.seen[0]["tool_choice"] == forced_choice , (
            f"force {why}: must force finish_tool specifically, not just narrow the tools list"
        );
        if expect_typed {
            assert out.name == expected_name , f"force {why}: expected the typed output, got: {out}";
        } else {
            assert not isinstance(out, _TestPerson) , f"force {why}: expected degradation, got: {out}";
        }

        llm = FakeLLM(
            model_name="anthropic/claude-test",
            replies=[tool_call("finish_tool", arguments)]
        );
        mt_run = mk_run(resp_type=_TestPerson, tools=[extra_tool]);
        recovery = llm._attempt_recovery(mt_run);
        assert recovery is not None , f"recover {why}: recovery should run for a structured resp_type";
        assert tool_names(llm.seen[0]) == expected , (
            f"recover {why}: sent {tool_names(llm.seen[0])}, expected {expected}"
        );
        assert llm.seen[0]["tool_choice"] == forced_choice , f"recover {why}: must force finish_tool";
        recovered: any = recovery.tool_calls[0];
        assert recovered.is_finish_call() == expect_typed , (
            f"recover {why}: is_finish_call should be {expect_typed}"
        );
        if expect_typed {
            assert recovered.get_output().name == expected_name , f"recover {why}: expected typed output";
        }
    }
}

import asyncio;
import inspect;

test "acall_llm proxy is a coroutine function" {
    assert inspect.iscoroutinefunction(Jac.acall_llm) , (
        "Jac.acall_llm must be an async function so async walkers can await it"
    );
}

test "model_call_no_stream_async raises and logs AuthenticationError" {
    log_output = io.StringIO();
    _loguru_logger.remove();
    handler_id = _loguru_logger.add(log_output, level="ERROR");
    try {
        with unittest.mock.patch.dict(
            _byllm_llm_mod._litellm_config,
            {"debug": False, "drop_params": True},
            clear=True
        ) {
            model = Model(model_name="gpt-4o-mini");
            auth_err = litellm.exceptions.AuthenticationError(
                message="Invalid API key", llm_provider="openai", model="gpt-4o-mini"
            );
            async def _run_no_stream_auth {
                with unittest.mock.patch("litellm.acompletion", side_effect=auth_err) {
                    raised = False;
                    try {
                        await model.model_call_no_stream_async(
                            {"model": "gpt-4o-mini", "messages": []}
                        );
                    } except AuthenticationError as e {
                        raised = True;
                        assert "Invalid API key" in str(e);
                    }
                    assert raised , "AuthenticationError should propagate from async path";
                }
            }
            asyncio.run(_run_no_stream_auth());
            log_value = log_output.getvalue();
            assert "LLM AuthenticationError" in log_value , (
                f"logger.error should fire for async AuthenticationError, got: {log_value}"
            );
        }
    } finally {
        _loguru_logger.remove(handler_id);
    }
}

test "model_call_with_stream_async raises and logs RateLimitError" {
    log_output = io.StringIO();
    _loguru_logger.remove();
    handler_id = _loguru_logger.add(log_output, level="ERROR");
    try {
        with unittest.mock.patch.dict(
            _byllm_llm_mod._litellm_config,
            {"debug": False, "drop_params": True},
            clear=True
        ) {
            model = Model(model_name="gpt-4o-mini");
            rate_err = litellm.exceptions.RateLimitError(
                message="Rate limit exceeded",
                llm_provider="openai",
                model="gpt-4o-mini"
            );
            async def _run_stream_rate {
                with unittest.mock.patch("litellm.acompletion", side_effect=rate_err) {
                    raised = False;
                    try {
                        await model.model_call_with_stream_async(
                            {"model": "gpt-4o-mini", "messages": []}
                        );
                    } except RateLimitError as e {
                        raised = True;
                        assert "Rate limit" in str(e);
                    }
                    assert raised , "RateLimitError should propagate from async stream path";
                }
            }
            asyncio.run(_run_stream_rate());
            log_value = log_output.getvalue();
            assert "LLM RateLimitError" in log_value , (
                f"logger.error should fire for async stream RateLimitError, got: {log_value}"
            );
        }
    } finally {
        _loguru_logger.remove(handler_id);
    }
}

test "model_call_http_async returns json response" {
    mock_response = unittest.mock.MagicMock();
    mock_response.json.return_value = {"choices": [{"message": {"content": "ok"}}]};
    async def _run_http_async -> any {
        mock_client = unittest.mock.AsyncMock();
        mock_client.__aenter__.return_value = mock_client;
        mock_client.post.return_value = mock_response;
        with unittest.mock.patch("httpx.AsyncClient", return_value=mock_client) {
            model = Model(model_name="gpt-4o-mini");
            result = await model.model_call_http_async(
                url="https://example.com/v1/chat/completions",
                token="test-token",
                payload={"model": "gpt-4o-mini", "messages": []},
                ca_bundle=None
            );
            return result;
        }
    }
    result = asyncio.run(_run_http_async());
    assert result == {"choices": [{"message": {"content": "ok"}}]};
}

import ast as ast3;
import from jaclang.compiler.driver.program { JacProgram }

test "async by llm() codegen emits await Jac.acall_llm not call_llm" {
    code_gen = (prog := JacProgram()).compile(
        os.path.join(FIXTURE_DIR, "async_by_llm.jac")
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) , (
        "Expected a compiled Python AST module"
    );
    py_source = ast3.unparse(code_gen.gen.py_ast[0]);

    assert "acall_llm" in py_source , (
        f"Expected 'acall_llm' in generated source for async by llm(). Got:\n{py_source}"
    );

    assert "call_llm" in py_source , (
        f"Expected 'call_llm' in generated source for sync by llm(). Got:\n{py_source}"
    );

    def _is_acall_llm_call(`node: object) -> bool {
        if not (isinstance(`node, ast3.Call)) {
            return False;
        }
        func = `node.func;
        return (
            (isinstance(func, ast3.Name) and func.id == "_jac_runtime_acall_llm")
            or (isinstance(func, ast3.Attribute) and func.attr == "acall_llm")
        );
    }
    await_nodes = [
        n
        for n in ast3.walk(code_gen.gen.py_ast[0])
        if isinstance(n, ast3.Await) and _is_acall_llm_call(n.value)
    ];
    assert len(await_nodes) >= 1 , (
        "Expected at least one ast3.Await(value=Call(acall_llm, ...)) in generated AST"
    );

    all_acall_nodes = [
        n
        for n in ast3.walk(code_gen.gen.py_ast[0])
        if _is_acall_llm_call(n)
    ];
    awaited_values = {
        id(n.value)
        for n in ast3.walk(code_gen.gen.py_ast[0])
        if isinstance(n, ast3.Await)
    };
    bare_acall_nodes = [
        n
        for n in all_acall_nodes
        if id(n) not in awaited_values
    ];
    assert len(bare_acall_nodes) == 0 , (
        f"Found {len(bare_acall_nodes)} bare (non-awaited) acall_llm call(s) — "
        "async by llm() must always be awaited"
    );
}

test "async by llm() end-to-end with mocked acall_llm" {
    code_gen = (prog := JacProgram()).compile(
        os.path.join(FIXTURE_DIR, "async_by_llm.jac")
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module);

    compiled = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec");
    module = types.ModuleType("async_by_llm_fixture");
    module.__dict__["__file__"] = code_gen.loc.mod_path;

    async def _run_end_to_end -> str {
        async def _fake_acall_llm(**kwargs: object) -> any {
            return "summary";
        }

        import jaclang.lib.jaclib as _jaclib;
        with unittest.mock.patch.object(_jaclib, "acall_llm", _fake_acall_llm) {
            exec(compiled, module.__dict__);
            result = await module.__dict__["get_summary"](text="hello world");
            return result;
        }
    }
    result = asyncio.run(_run_end_to_end());
    assert result == "summary" , (
        f"Expected mocked acall_llm result 'summary', got: {result!r}"
    );
}


test "recover_tool_calls handles an object-shaped reply" {
    import from jaclang.byllm.tool_protocol { recover_tool_calls }
    import from types { SimpleNamespace }

    msg = SimpleNamespace(
        role="assistant",
        content="<tool_call>{\"name\": \"get_count\", \"arguments\": {}}</tool_call>",
        tool_calls=None
    );
    out = recover_tool_calls(msg, ["get_count", "finish_tool"]);
    assert isinstance(out, dict) , "must return a dict the ReAct loop can read";
    tcs = out.get("tool_calls");
    assert tcs , "the text tool call must be recovered into tool_calls";
    assert tcs[0].function.name == "get_count";
    assert "<tool_call>" not in (out.get("content") or "") , (
        "the consumed call text must be stripped from content"
    );
}


test "linearize_tool_messages renders calls and results as text" {
    import from jaclang.byllm.tool_protocol { linearize_tool_messages }
    import from types { SimpleNamespace }
    msgs = [
        {"role": "system", "content": "sys"},
        {"role": "user", "content": "how many?"},
        {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                SimpleNamespace(
                    function=SimpleNamespace(name="get_count", arguments="{}")
                )
            ]
        },
        {"role": "tool", "tool_call_id": "abc", "name": "get_count", "content": "7"}
    ];
    out = linearize_tool_messages(msgs);

    assert out[0]["role"] == "system";
    assert out[1]["role"] == "user";

    assert out[2]["role"] == "assistant";
    assert "<tool_call>" in out[2]["content"];
    assert "get_count" in out[2]["content"];

    assert out[3]["role"] == "user";
    assert "<tool_response>" in out[3]["content"];
    assert "7" in out[3]["content"];
}


test "gemma models default to the text tool protocol" {
    m = Model(model_name="ollama/gemma4:31b");
    assert m.supports_native_tools == False;

    m2 = Model(model_name="ollama/gemma4:31b", config={"native_tools": True});
    assert m2.supports_native_tools == True;

    m3 = Model(model_name="gpt-4o");
    assert m3.supports_native_tools == True;
}


def _needs_arg_tool(x: int) -> str {
    return str(x);
}


def _raising_tool -> str {
    raise ValueError("kaboom");
}


def _writer_tool(file_path: str, content: str) -> str {
    return f"wrote {len(content)} bytes to {file_path}";
}


test "a handled tool failure returns a Tool error at WARNING, even for a callable without __name__" {
    import functools;
    for (why, func, named) in [
        ("missing required argument", _needs_arg_tool, "_needs_arg_tool"),
        ("functools.partial without __name__", functools.partial(_raising_tool), "")
    ] {
        with capture_logs() as logs {
            result: any = Tool(func=func)();
        }
        assert isinstance(result, str) and result.startswith("Tool error:") , (
            f"{why}: unexpected return: {result!r}"
        );
        text = logs.text();
        assert "WARNING" in text , f"{why}: expected a WARNING record, got: {text!r}";
        if named {
            assert named in text , f"{why}: WARNING should name the tool, got: {text!r}";
        }
        assert "ERROR" not in text , f"{why}: handled tool failure must not log at ERROR: {text!r}";
        assert "Traceback (most recent call last)" not in text , (
            f"{why}: handled tool failure must not emit a traceback: {text!r}"
        );
    }
}

test "damaged and truncated tool calls are told apart and get the advice that fits (issue #7657)" {
    for (why, arguments, expect_damaged) in [
        (
            "cut off mid-arguments",
            '{"file_path": "/app/Landing.jac", "content": "node Landing { has t',
            True
        ),
        ("argument-less call", "", False)
    ] {
        message = {
            "tool_calls": [
                types.SimpleNamespace(
                    id="call_1",
                    function=types.SimpleNamespace(
                        name="write_code", arguments=arguments
                    ),
                    type="function"
                )
            ],
            "content": ""
        };
        damaged = _byllm_llm_mod._sanitize_tool_calls(_as_any(message));
        assert ("call_1" in damaged) == expect_damaged , f"{why}: damaged={damaged!r}";
        assert not _byllm_llm_mod._truncated_call_ids(_as_any(message), "tool_calls") , (
            f"{why}: the truncation guard must not be the thing catching this"
        );
    }

    tool = Tool(func=_writer_tool);
    def _get_tool(_name: str) -> any {
        return tool;
    }
    mt_run: any = types.SimpleNamespace(get_tool=_get_tool);
    fn = types.SimpleNamespace(name="_writer_tool", arguments='{"file_path"');
    cut = types.SimpleNamespace(id="call_1", function=fn, type="function");
    for (why, truncated, damaged, expect, forbid) in [
        ("truncated at max_tokens", `set(["call_1"]), `set(), "smaller payload", ""),
        (
            "damaged in transit",
            `set(),
            `set(["call_1"]),
            "same call again unchanged",
            "smaller payload"
        )
    ] {
        parsed = _byllm_llm_mod._parse_tool_calls(mt_run, [cut], truncated, damaged);
        tool_obj: any = parsed[0].tool;
        advice = str(tool_obj.func());
        assert expect in advice , f"{why}: expected {expect!r} in {advice!r}";
        if forbid {
            assert forbid not in advice , f"{why}: must not say {forbid!r}: {advice!r}";
        }
    }
}
