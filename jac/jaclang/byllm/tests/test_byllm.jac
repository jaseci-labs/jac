"""Tests for Integration with Jaclang."""

import contextlib;
import io;
import os;
import sys;
import warnings;
import unittest.mock;

import yaml;
import from fixtures { python_lib_mode }

import jaclang.byllm.llm as _byllm_llm_mod;
import from jaclang.byllm.lib { Model }
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

"""Identity cast that keeps duck-typed test payloads out of nominal checks."""
def _as_any(v: any) -> any {
    return v;
}

test "llm mail summerize" {
    stdout_value = run_fixture("llm_mail_summerize");
    summaries = [
        "AetherGuard reports a login to your account from a new device in Berlin and advises a password reset if the activity was unauthorized.",
        "Claire from Novelink invites writers to a biweekly Writer's Circle this Friday for sharing work and receiving feedback in a supportive environment.",
        "Marcus Bentley from FinTracker reports a weekly spending total of $342.65, mainly on Groceries, Transport, and Dining, with a link for detailed insights.",
        "TechNews from DailyByte highlights how quantum computing is set to transform fields like cryptography and climate modeling, with more details in the full article.",
        "Nora Hartwell from Wanderlust Travels offers a 30% discount on international trips booked this week, urging recipients to take advantage of the limited-time travel deal.",

    ];
    for summary in summaries {
        assert summary in stdout_value;
    }
}

test "method include context" {
    stdout_value = run_fixture("method_incl_ctx");
    assert "Average marks for Alice : 86.75" in stdout_value;
}

test "with llm function" {
    stdout_value = run_fixture("with_llm_function");
    assert "\U0001f464\u27a1\ufe0f\U0001f5fc" in stdout_value;
}

test "method tool call" {
    stdout_value = run_fixture("method_tool");
    assert "Calculator.add called with 12, 34" in stdout_value;
    assert "Result: 46" in stdout_value;
}

test "params format" {
    stdout_value = run_fixture("llm_params");
    dict_str = stdout_value[stdout_value.find("{"):stdout_value.rfind("}") + 1];
    extracted_dict = yaml.safe_load(dict_str);

    required_keys = [
        "model",
        "api_base",
        "messages",
        "tools",
        "response_format",
        "max_tokens",

    ];
    for key in required_keys {
        assert key in extracted_dict , f"Missing key: {key}";
    }

    # Temperature is omitted entirely when the caller never sets one, so the
    # provider (or an aggregator like OpenRouter) applies its own default
    # instead of byLLM forcing an unsupported value. See issue #7687.
    assert "temperature" not in extracted_dict , "temperature must be omitted when unset";

    add_message = extracted_dict["messages"];
    assert add_message[0]["role"] == "system" , "First message should be of role 'system'";
    assert add_message[1]["role"] == "user" , "Second message should be of role 'user'";
    assert add_message[3]["role"] == "tool" , "Fourth message should be of role 'tool'";
    assert (
        add_message[3]["content"]
        == "The current wind speed in Puttalam is about 18-22 km/h."
    ) , "Content mismatch";

    add_tool = extracted_dict["tools"][0];
    assert add_tool["type"] == "function" , "First tool should be of type 'function'";
    assert add_tool["function"]["name"] == "get_live_wind_speed" , "First tool function should be 'get_live_wind_speed'";
    assert "city" in add_tool["function"]["parameters"]["properties"] , "get_live_wind_speed function should have 'city' parameter";
}

test "temperature passed through when set" {
    stdout_value = run_fixture("llm_params_temp");
    dict_str = stdout_value[stdout_value.find("{"):stdout_value.rfind("}") + 1];
    extracted_dict = yaml.safe_load(dict_str);

    assert "temperature" in extracted_dict , "temperature must be present when the caller sets it";
    assert extracted_dict["temperature"] == 0.3 , f"expected temperature 0.3, got {extracted_dict.get(
        'temperature'
    )}";
}

test "image input" {
    stdout_value = run_fixture("image_test");
    assert "The image shows a hot air balloon shaped like a heart" in stdout_value;
}

test "image param with sem string doesn't crash Message.to_dict" {
    stdout_value = run_fixture("image_with_sem");
    assert "IMAGE_SEM_PASS" in stdout_value;
}

test "streaming output" {
    stdout_value = run_fixture("streaming_output");
    assert (
        "The orca whale, or killer whale, is one of the most intelligent and adaptable marine predators"
        in stdout_value
    );
}

test "streaming with react" {
    stdout_value = run_fixture("streaming_with_react");
    assert "29-10-2025" in stdout_value;
    assert "100" in stdout_value;
    assert "Test passed!" in stdout_value;
}

test "logging stream no tools" {
    stdout_value = run_fixture("logging_stream_no_tools");
    assert "NO_TOOLS_PASS" in stdout_value;
}

test "logging stream react" {
    stdout_value = run_fixture("logging_stream_react");
    assert "REACT_LOGGING_PASS" in stdout_value;
}

test "logging stream str answer without finish_tool delivers on chunk" {
    # a `-> str` agent whose model skips finish_tool and
    # returns plain text must deliver that terminal text on the `chunk` channel,
    # not leave it stranded as `thought`-only.
    stdout_value = run_fixture("logging_stream_str_skip_finish");
    assert "STR_SKIP_FINISH_CHUNK_PASS" in stdout_value;
}

test "conversation kwarg writes back history with tool calls preserved" {
    stdout_value = run_fixture("conversation_param");
    assert "CONV_PARAM_PASS" in stdout_value;
}

test "streaming + conversation persists assistant message and emits dicts" {
    stdout_value = run_fixture("streaming_conversation");
    assert "STREAM_CONV_PASS" in stdout_value;
}

test "transient mid-stream drop retried on same model, output de-duplicated" {
    stdout_value = run_fixture("stream_retry");
    assert "STREAM_RETRY_PASS" in stdout_value;
}

test "streaming generator survives consumption from a foreign Context" {
    # Regression test: a streaming by llm() generator must be safe to consume
    # from a different contextvars.Context than the one that created it — e.g. a
    # thread-pool worker, which is how the scale backend's sse_frame_stream drives SSE.
    # Pre-fix, the wrapper reset a ContextVar Token across Context boundaries and
    # raised "Token was created in a different Context", killing the stream.
    stdout_value = run_fixture("streaming_cross_context");
    assert "CROSS_CONTEXT_PASS" in stdout_value;
}

test "by expr" {
    stdout_value = run_fixture("by_expr");
    expected_lines = (
        "Generated greeting: Hello, Alice! It's great to see you!",
        "[run_and_test_python_code] Executing code:",
        "[run_and_test_python_code] \"name = 'Alice'\\nprint(f'Hello, {name}! Welcome to the Python world!')\"",
        "Hello, Alice! Welcome to the Python world!",
        "[run_and_test_python_code] Code executed successfully.",
        "Generated greeting code: name = 'Alice'",
        "print(f'Hello, {name}! Welcome to the Python world!')",

    );
    for line in expected_lines {
        assert line in stdout_value;
    }
}

test "with llm method" {
    stdout_value = run_fixture("with_llm_method");
    assert "Personality.INTROVERT" in stdout_value;
}

test "deprecated method param" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    with warnings.catch_warnings(record=True) as w {
        warnings.simplefilter("always");
        jac_import("with_llm_deprecated_method", base_path=FIXTURE_DIR + "/");
    }
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "test output" in stdout_value;
    deprecation_warnings = [
        x
        for x in w
        if issubclass(x.category, DeprecationWarning)
    ];
    assert len(deprecation_warnings) >= 1;
    assert "'method' parameter is deprecated" in str(deprecation_warnings[0].message);
}

test "with llm lower" {
    stdout_value = run_fixture("with_llm_lower");
    assert (
        "J. Robert Oppenheimer was a Introvert person who died in 1967" in stdout_value
    );
}

test "with llm type" {
    stdout_value = run_fixture("with_llm_type");
    assert "14/03/1879" in stdout_value;
    assert (
        'University (University) (obj) = type(__module__="with_llm_type", __doc__=None, '
        "_jac_entry_funcs_`=[`], _jac_exit_funcs_=[], __init__=function(__wrapped__=function()))"
        not in stdout_value
    );
    desired_output_count = stdout_value.count(
        "Person(name='Jason Mars', dob='1994-01-01', age=30)"
    );
    assert desired_output_count == 2;
}

test "with llm image" {
    try {
        import PIL;
    } except ImportError {
        testskip("This test requires Pillow to be installed");
    }
    stdout_value = run_fixture("with_llm_image");
    assert "'role': 'system'" in stdout_value;
    assert "{'type': 'text', 'text': 'solve_math_question" in stdout_value;
    assert "data:image/jpeg;base64," in stdout_value[:500];
}

test "webp image support" {
    stdout_value = run_fixture("webp_support_test");
    assert "full_name='Albert Einstein'" in stdout_value;
    assert "year_of_death='1955'" in stdout_value;
}

test "with llm video" {
    try {
        import cv2;
    } except ImportError {
        testskip("This test requires OpenCV to be installed");
    }
    stdout_value = run_fixture("with_llm_video");
    video_explanation = (
        "The video features a large rabbit emerging from a burrow in a lush, green environment. "
        "The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a "
        "vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere."
    );
    assert video_explanation in stdout_value;
}

test "semstrings" {
    stdout_value = run_fixture("llm_semstrings");
    assert "Specific number generated: 120597" in stdout_value;

    i = stdout_value.find("Generated password:");
    password = stdout_value[i:].split("\n")[0];

    assert len(password) >= 8 , "Password should be at least 8 characters long.";
    assert any(c.isdigit() for c in password) , "Password should contain at least one digit.";
    assert any(c.isupper() for c in password) , "Password should contain at least one uppercase letter.";
    assert any(c.islower() for c in password) , "Password should contain at least one lowercase letter.";
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

test "fixtures image types" {
    stdout_value = run_fixture("image_types");
    expected_labels = [
        "PIL Image",
        "Image from file path",
        "Image from URL",
        "Image from BytesIO",
        "Image from raw bytes",
        "Image from memoryview",
        "Image from data URL",
        "Image from PathLike",
        "Image from file-like without getvalue",
        "Image from bytearray",
        "Image from gs:// URL",

    ];
    for label in expected_labels {
        assert label in stdout_value;
    }
}

test "visit by for routing" {
    stdout_value = run_fixture("math_poem_agents");
    assert "Agentic minds, we hold dear" in stdout_value;
    assert "Math Result: 35" in stdout_value;
}

test "streaming visit by routes and streams tokens to handler" {
    # `visit [-->] by model(stream=True, stream_handler=fn)` streams the routing
    # decision token-by-token to the handler (the path a live token feed
    # consumes) while the structured choice still selects the successor edge.
    stdout_value = run_fixture("streaming_visit_by");
    assert "STREAMING_VISIT_BY_PASS" in stdout_value;
    # The structured choice [1] picked the second successor edge.
    assert "VISITED: green" in stdout_value;
    assert "VISITED: red" not in stdout_value;
}

test "structured streaming without a handler is rejected" {
    # Streaming a non-str return needs a stream_handler to consume the events;
    # omitting it raises ConfigurationError up front (the guard the visit-by
    # streaming path relaxes only when a handler is supplied).
    stdout_value = run_fixture("streaming_structured_no_handler");
    assert "STREAMING_GUARD_PASS" in stdout_value;
}

test "http client with system prompt override" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import(
        "direct_http_model_call",
        base_path=os.path.join(FIXTURE_DIR, "system_prompt_override/")
    );
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();

    # Both calls' responses surface.
    assert "Hello, Alice! It's great to meet you." in stdout_value;
    assert "Hi Alice, welcome!" in stdout_value;

    # jac.toml base SYSTEM reaches the prompt for both calls.
    assert "You are a friendly assistant. Greet the person" in stdout_value;

    # Per-call `system_prompt` on `say_hello_brief` extends the base — both
    # texts must appear together in the SYSTEM payload of that second call.
    assert "Respond in three words maximum." in stdout_value;

    assert (
        "'api_base': 'https://your_api_base_here/v1/chat/completions'" in stdout_value
    );
}

test "max react iterations" {
    stdout_value = run_fixture("react_max_iterations");
    assert "get_live_wind_speed called for Puttalam" in stdout_value;
    assert "get_speed_unit called" in stdout_value;
    assert "RESULT: FINAL_REPORT" in stdout_value;
    assert "WIND_TOOL_CALLS: 1" in stdout_value;
    assert "UNIT_TOOL_CALLS: 1" in stdout_value;
    assert (
        "Based on the tool calls and their results above, provide only your final answer."
        in stdout_value
    );
}

test "max react iterations with finish tool call" {
    # Verifies that when max_react_iterations is exceeded and the LLM responds
    # with a finish_tool call (instead of plain text), the output is correctly extracted.
    stdout_value = run_fixture("react_max_iterations_finish_tool");
    assert "get_live_wind_speed called for Puttalam" in stdout_value;
    assert "get_speed_unit called" in stdout_value;
    assert "RESULT: FINAL_REPORT" in stdout_value;
    assert "WIND_TOOL_CALLS: 1" in stdout_value;
    assert "UNIT_TOOL_CALLS: 1" in stdout_value;
}

test "on_iteration callback ABORT and ABORT_WITH_SUMMARY" {
    stdout_value = run_fixture("on_iteration_callback");
    # ABORT: hook fired, only 2 tool calls (a, b), c and d skipped
    assert "ABORT_TRIGGERED" in stdout_value;
    assert "ABORT_TOOLS: 2" in stdout_value;
    assert "get_data called: a" in stdout_value;
    assert "get_data called: b" in stdout_value;
    # ABORT_WITH_SUMMARY: hook fired, only 2 tool calls (c, d), summary returned
    assert "SUMMARY_TRIGGERED" in stdout_value;
    assert "SUMMARY_TOOLS: 2" in stdout_value;
    assert "SUMMARY_RESULT" in stdout_value;
}

test "plain text recovery - LLM bypasses finish_tool" {
    # Verifies the Bug 2B fix: when a model (e.g. gpt-4o) returns plain conversational
    # text instead of calling finish_tool, the invoke loop detects the failure,
    # re-prompts with only finish_tool available, and correctly extracts the typed result.
    stdout_value = run_fixture("plain_text_recovery");
    assert "PERSON: Merchant" in stdout_value;
    assert "MESSAGE: Greetings traveller, I have wares to trade!" in stdout_value;
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
    # `make_model_params` resolves api_base, then dispatch pops it off `params`
    # into `self.api_base`, an attribute only the proxy and http_client
    # branches read. On the default litellm path a configured base_url was
    # therefore dropped and requests went to the provider's own endpoint
    # (api.openai.com for gpt-*) instead of the configured gateway.
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
            model.dispatch_no_streaming(
                MTRuntime(
                    messages=[
                        Message(role=MessageRole.SYSTEM, content="s"),
                        Message(role=MessageRole.USER, content="u")
                    ],
                    resp_type=str,
                    stream=False,
                    tools=[],
                    call_params={},
                    mtir=None
                )
            );
        }
        return seen.get("api_base");
    }
    configured = Model(
        model_name="gpt-4o-mini",
        api_key="sk-test",
        config={"base_url": "https://gateway.example.com/v1"}
    );
    assert _dispatched_api_base(configured) == "https://gateway.example.com/v1" , "a configured base_url must reach litellm";

    # With nothing configured the loader's empty-string default must normalise
    # to None so litellm keeps the provider's endpoint, never DEFAULT_BASE_URL.
    with unittest.mock.patch.dict(
        _byllm_llm_mod._model_config, {"base_url": ""}, clear=True
    ) {
        bare = Model(model_name="gpt-4o-mini", api_key="sk-test");
        assert _dispatched_api_base(bare) is None , "api_base must stay unset when nothing configures one";
    }
}


test "api key not in verbose output" {
    import from loguru { logger }

    captured_output = io.StringIO();
    logger.remove();
    logger.add(captured_output);
    with contextlib.suppress(Exception) {
        jac_import("api_key_verbose", base_path=FIXTURE_DIR + "/");
    }
    log_value = captured_output.getvalue();
    assert "sk-secret-test-key-do-not-leak" not in log_value;
    assert "Calling LLM" in log_value;
}

test "builtin llm with mock override" {
    stdout_value = run_fixture("builtin_llm");
    assert "POSITIVE" in stdout_value or "positive" in stdout_value;
}

test "builtin llm compiles without glob" {
    # Verify that a file using 'by llm()' without defining glob llm
    # compiles successfully (the llm name is recognized as a builtin).
    # We suppress runtime errors since no actual LLM API key is configured.
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    try {
        jac_import("builtin_llm_no_override", base_path=FIXTURE_DIR + "/");
    } except Exception as e {
        # Runtime errors are expected (no API key), but NameError for 'llm'
        # would indicate the builtin wasn't recognized.
        assert "name 'llm' is not defined" not in str(e) , f"'llm' should be a recognized builtin, got: {e}";
    }
    sys.stdout = sys.__stdout__;
}

import from pathlib { Path }
import from jaclang.byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.runtime.runtime { JacRuntime }

glob GEMINI_FIXTURE = os.path.join(FIXTURE_DIR, "jac_toml_gemini");


test "byllm config reads model from jac.toml" {
    # Explicit project_dir pointing at a jac.toml with gemini model
    reset_byllm_config();
    config = get_byllm_config(Path(GEMINI_FIXTURE));
    assert config.get_model_config()['default_model'] == "gemini/gemini-1.5-pro";
}

test "byllm config defaults to gpt-4o-mini when no jac.toml" {
    # fixtures/ dir has no jac.toml, so built-in defaults apply
    reset_byllm_config();
    config = get_byllm_config(Path(FIXTURE_DIR));
    assert config.get_model_config()['default_model'] == "gpt-4o-mini";
}

test "byllm config uses full_target_path to find jac.toml regardless of cwd" {
    # cwd is /tmp, but full_target_path points at the gemini fixture —
    # the correct jac.toml must still be picked up
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

# Note: OutputConversionError tests call MTRuntime.parse_response directly because
# MockLLM.dispatch_no_streaming bypasses parse_response, returning the pre-built
# output object straight from CompletionResult. The error lives in parse_response,
# so that is the correct unit to test.
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

# Schema generation is what rejects bare unparameterized containers.
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

# An unregistered tool name is recovered, not fatal: dispatch_no_streaming
# returns a tool call that reports the error back so the model can retry,
# rather than crashing the whole turn.
# model_call_no_stream is mocked so no real API key is needed.
test "unregistered tool call is recovered not fatal" {
    model = Model(model_name="test-model");
    messages_list = [
        Message(role=MessageRole.SYSTEM, content="You are a helpful assistant."),
        Message(role=MessageRole.USER, content="Do something."),

    ];
    mt_run = MTRuntime(
        messages=messages_list,
        resp_type=None,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    # Fake LLM response referencing a tool not registered in mt_run.tools
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
    # No exception: the unknown tool is surfaced as a recoverable tool result.
    assert len(result.tool_calls) == 1 , "Expected one recovered tool call";
    err_result = result.tool_calls[0]();
    assert "nonexistent_tool" in str(err_result.content) , (
        f"Recovered result should name the tool, got: {err_result.content}"
    );
    assert "Tool error" in str(err_result.content) , (
        f"Recovered result should be a tool error, got: {err_result.content}"
    );
}

# FinishToolError is raised inside the finish_tool closure when the final output
# fails pydantic validation against the declared return type.
test "finish tool error on type mismatch" {
    # Input missing required Person fields cannot be validated — raises FinishToolError
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
    # Valid input matching the declared type should return the constructed instance
    finish_tool = Tool.make_finish_tool(_TestPerson);
    result = finish_tool({"name": "Alice", "age": 30});
    assert result.name == "Alice" , f"Expected name='Alice', got '{result.name}'";
    assert result.age == 30 , f"Expected age=30, got '{result.age}'";
}

# finish_tool argument robustness (issue #8169).
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
    bare = Tool.make_finish_tool(str).parse_arguments("just the answer");  # type: ignore[arg-type]
    assert bare == {"final_output": "just the answer"} , f"bare payload: got {bare}";
    # Output type whose OWN field is named final_output, sent flattened.
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

# finish_tool argument robustness end to end (issue #8169): a misnamed
# argument is healed into the typed output; an unusable one comes back as a
# recoverable tool error that must not masquerade as the finish call.
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

# Some backends downgrade json_schema to json_object and reject requests whose
# messages lack the word "json" (issue #8114).
test "response format requests always carry the json word" {
    def _params(resp_type: type, tools: list) -> dict {
        model = Model(model_name="test-model");
        mt_run = MTRuntime(
            messages=[
                Message(role=MessageRole.SYSTEM, content="sys"),
                Message(role=MessageRole.USER, content="do the thing")
            ],
            resp_type=resp_type,
            stream=False,
            tools=tools,
            call_params={},
            mtir=None  # type: ignore[arg-type]
        );
        return model.make_model_params(mt_run);
    }
    for (label, resp_type, tools, want_rf) in [
        ("typed no tools", _TestPerson, [], True),
        ("scalar no tools", int, [], True),
        # A union field compiles to anyOf with no top-level type, and a fieldless
        # obj to empty properties: both yield no schema hint lines, so the lead
        # sentence must not depend on those lines existing.
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

# =============================================================================
# LiteLLM debug config and provider-error mapping
# =============================================================================
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

# Provider errors map to byllm's own exceptions and log at ERROR through byllm's
# logger whatever the litellm debug flag says. litellm.completion is the seam
# here because the mapping under test lives in Model.model_call_no_stream.
test "provider errors map to byllm exceptions and log at ERROR regardless of debug" {
    # Rows carry byllm's classes; litellm's AuthenticationError and RateLimitError
    # share those names, so matching by name would let an unmapped error through.
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


"""Test ModelPool fallback strategy: router is configured with unique aliases and
a fallbacks chain; successful responses are returned via the dispatch pipeline."""
test "model pool router fallback" {
    stdout_value = run_fixture("model_pool_fallback");
    assert "fallback_success" in stdout_value;
}

"""Test ModelPool load-balancing (simple-shuffle): all three deployments share the
pool-model alias; three independent calls all succeed and the alias is pool-model."""
test "model pool router load balance" {
    stdout_value = run_fixture("model_pool_round_robin");
    assert "pool_alias:pool-model" in stdout_value;
    assert stdout_value.count("load_balance_response") == 3;
}

"""Test ModelPool propagates router exceptions: when the LiteLLM Router
raises (all deployments exhausted) the exception reaches the caller."""
test "model pool router all fail" {
    stdout_value = run_fixture("model_pool_all_fail");
    assert "EXPECTED_ERROR: RateLimitError" in stdout_value;
    assert "UNEXPECTED" not in stdout_value;
}

"""Test ModelPool cost-based-routing uses the async path (acompletion).
LiteLLM Router only supports cost-based-routing via acompletion(); ModelPool
bridges this via ThreadPoolExecutor to stay safe in async frameworks."""
test "model pool router cost based" {
    stdout_value = run_fixture("model_fallbacks_convenience");
    assert "cost_based_success" in stdout_value;
}

"""Test ModelPool LiteLLM Router model_list initialisation.
Fallback strategy: unique per-model aliases + fallbacks list.
Load-balance strategy: all models share pool-model alias."""
test "model pool router init" {
    stdout_value = run_fixture("model_pool_router_init");
    assert "fb_pool_alias:pool-primary" in stdout_value;
    assert "fb_deploy_count:2" in stdout_value;
    assert "fb_fallbacks_has_primary:True" in stdout_value;
    assert "fb_fallbacks_has_chain:True" in stdout_value;
    assert "lb_pool_alias:pool-model" in stdout_value;
    assert "lb_deploy_count:3" in stdout_value;
    assert "lb_all_share_alias:True" in stdout_value;
}

# MCP integration tests
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
    # parse_arguments is a passthrough — MCP schema is the source of truth.
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
    mt_run = MTRuntime(
        messages=[],
        resp_type=None,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );
    # Mutate tools list via dynamic access — IDE type checker flags
    # list[Tool | McpTool] as invariant, but the actual compiler accepts it.
    getattr(mt_run, "tools").append(mcp_tool);
    found = mt_run.get_tool("lookup");
    assert found is mcp_tool , "MTRuntime.get_tool should resolve McpTool by name";
    assert mt_run.get_tool("nonexistent") is None;
    # get_tool_list calls get_json_schema on every tool — must not blow up.
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

"""Test ModelPool streaming fallback path."""
test "model pool streaming fallback" {
    stdout_value = run_fixture("model_pool_streaming_fallback");
    assert "output:stream_fallback_success" in stdout_value;
    assert "primary_tried:True" in stdout_value;
    assert "fallback_tried:True" in stdout_value;
    assert "order_correct:True" in stdout_value;
    # Scenario B: mid-stream failure — exception must propagate, no fallback
    assert "mid_raised:True" in stdout_value;
    assert "mid_partial_received:True" in stdout_value;
    assert "mid_fallback_not_tried:True" in stdout_value;
    assert "mid_should_not_appear:True" in stdout_value;
}

import from jaclang.byllm.llm {
    _is_prompt_caching_eligible,
    _apply_prompt_caching,
    _CACHE_CONTROL_EPHEMERAL
}

test "prompt caching marks system, last non-system message, and last tool for anthropic models" {
    # Eligibility: Anthropic yes, others no
    assert _is_prompt_caching_eligible("anthropic/claude-sonnet-4-20250514") == True;
    assert _is_prompt_caching_eligible("claude-3-opus-20240229") == True;
    assert _is_prompt_caching_eligible("gpt-4o") == False;

    # Multi-turn ReAct conversation, with list-content on the last message
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

    # System marked, intermediate messages NOT marked, last message's last block marked
    assert messages[0].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;
    assert "cache_control" not in messages[1];
    assert "cache_control" not in messages[2];
    tool_content: any = messages[3].get("content");
    assert "cache_control" not in tool_content[0];
    assert tool_content[-1].get("cache_control") == _CACHE_CONTROL_EPHEMERAL;
    # Only last tool marked
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

# Regression guard for jac#8381: tools serialize ahead of messages in Anthropic's
# wire format, so shrinking mt_run.tools on the narration call broke the cached
# prefix. The terminal paths that force finish_tool must keep the array too.
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

# A structured resp_type still needs finish_tool callable, so the terminal
# paths force it via tool_choice instead of tool_choice="none". Neither path
# has a retry loop: heal a misnamed argument or degrade, never raise.
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

# jac#8932: adispatch_streaming awaits model_call_with_stream_async, so the base
# must be a coroutine returning an async iterator, not an async generator.
# FakeLLM implements only the sync provider call, so it inherits the base method,
# which is the shape LocalLLM and ModelPool have.
async def _drain_8932(llm: _byllm_llm_mod.BaseLLM) -> str {
    stream: any = llm.adispatch_streaming(mk_run(stream=True));
    out: list[object] = [];
    async for chunk in stream {
        out.append(chunk);
    }
    return "".join([str(c) for c in out]);
}


test "BaseLLM.model_call_with_stream_async is a coroutine, not an async generator" {
    fn = _byllm_llm_mod.BaseLLM.model_call_with_stream_async;
    assert not inspect.isasyncgenfunction(fn) , "awaiting one raises TypeError";
    assert inspect.iscoroutinefunction(fn) , "must be a coroutine, matching Model";
}


test "async streaming works on a subclass that inherits the base method" {
    llm = FakeLLM(model_name="fake-8932", replies=[say("hello world")]);
    assert asyncio.run(_drain_8932(llm)) == "hello world";
}


test "async streaming works on MockLLM" {
    llm = _byllm_llm_mod.MockLLM(
        model_name="mockllm", config={"outputs": ["hello world"]}
    );
    assert asyncio.run(_drain_8932(llm)) == "hello world";
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
    # Compile the fixture that has both an async and a sync by llm() function.
    code_gen = (prog := JacProgram()).compile(
        os.path.join(FIXTURE_DIR, "async_by_llm.jac")
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module) , (
        "Expected a compiled Python AST module"
    );
    py_source = ast3.unparse(code_gen.gen.py_ast[0]);

    # Async function must use acall_llm, wrapped in await.
    assert "acall_llm" in py_source , (
        f"Expected 'acall_llm' in generated source for async by llm(). Got:\n{py_source}"
    );

    # Sync function must still use call_llm (no await).
    assert "call_llm" in py_source , (
        f"Expected 'call_llm' in generated source for sync by llm(). Got:\n{py_source}"
    );

    # The async body must contain an Await node whose value is a Call to acall_llm.
    # The codegen imports acall_llm directly (Name node), not as Jac.acall_llm (Attribute).
    def _is_acall_llm_call(`node: object) -> bool {
        if not (isinstance(`node, ast3.Call)) {
            return False;
        }
        func = `node.func;
        return (
            (isinstance(func, ast3.Name) and func.id == "acall_llm")
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

    # All acall_llm calls must be wrapped in Await — no bare unawaited calls.
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
    # Compile the fixture and execute it with acall_llm mocked to return "summary".
    code_gen = (prog := JacProgram()).compile(
        os.path.join(FIXTURE_DIR, "async_by_llm.jac")
    );
    assert not prog.errors_had , f"Compilation errors: {prog.errors_had}";
    assert code_gen.gen.py_ast and isinstance(code_gen.gen.py_ast[0], ast3.Module);

    compiled = compile(code_gen.gen.py_ast[0], filename="<ast>", mode="exec");
    module = types.ModuleType("async_by_llm_fixture");
    module.__dict__["__file__"] = code_gen.loc.mod_path;

    async def _run_end_to_end -> str {
        # Patch acall_llm so no real API call is made.
        async def _fake_acall_llm(**kwargs: object) -> any {
            return "summary";
        }
        # acall_llm is imported directly from jaclang.lib.jaclib into the
        # compiled module's namespace, so we patch it there.
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


"""Text tool protocol: a reply object carrying a tool call as plain text must
be recovered into a structured `tool_calls` field.

Regression for the ollama/gemma loop: `recover_tool_calls` only handled dict
replies, so the litellm path (which yields a `Message` *object*) silently
no-opped -- the model's `<tool_call>` text was never executed and the agent
re-issued the same call forever. The fix coerces object replies to a dict and
returns it, so callers pick up the recovered call.
"""
test "recover_tool_calls handles an object-shaped reply" {
    import from jaclang.byllm.tool_protocol { recover_tool_calls }
    import from types { SimpleNamespace }
    # Mimics a litellm Message object: attribute access, no dict-ness.
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


"""Text tool protocol: tool-call and tool-result history must linearise to text
for models whose chat template has no `tool` role (e.g. gemma)."""
test "linearize_tool_messages renders calls and results as text" {
    import from jaclang.byllm.tool_protocol { linearize_tool_messages }
    import from types { SimpleNamespace }
    msgs = [
        {"role": "system", "content": "sys"},
        {"role": "user", "content": "how many?"},
        # assistant tool-call message (object-shaped tool_calls, content stripped)
        {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                SimpleNamespace(
                    function=SimpleNamespace(name="get_count", arguments="{}")
                )
            ]
        },
        # tool result (identified by tool_call_id)
        {"role": "tool", "tool_call_id": "abc", "name": "get_count", "content": "7"}
    ];
    out = linearize_tool_messages(msgs);
    # System + user pass through untouched.
    assert out[0]["role"] == "system";
    assert out[1]["role"] == "user";
    # Assistant tool call becomes <tool_call> text.
    assert out[2]["role"] == "assistant";
    assert "<tool_call>" in out[2]["content"];
    assert "get_count" in out[2]["content"];
    # Tool result becomes a readable user message (no dropped tool role).
    assert out[3]["role"] == "user";
    assert "<tool_response>" in out[3]["content"];
    assert "7" in out[3]["content"];
}


"""Gemma-family models route through the text tool protocol automatically,
since their chat template cannot consume `role:tool` results."""
test "gemma models default to the text tool protocol" {
    m = Model(model_name="ollama/gemma4:31b");
    assert m.supports_native_tools == False;
    # An explicit override still wins.
    m2 = Model(model_name="ollama/gemma4:31b", config={"native_tools": True});
    assert m2.supports_native_tools == True;
    # A model without the gemma template keeps native tools.
    m3 = Model(model_name="gpt-4o");
    assert m3.supports_native_tools == True;
}


# ---------------------------------------------------------------------------
# Typed-output retry, driven through real `by llm()` calls
# ---------------------------------------------------------------------------
# The llm_typed_retry fixture declares `by llm()` functions backed by MockLLM:
# MockRawResponse routes text through parse_response, MockError raises a
# non-conversion error, and each MockLLM records the prompt it saw per attempt.
# The module is imported once per test so the mock outputs are consumed exactly
# once, and exception classes are matched by name because a jac_import can carry
# a distinct class object.
test "typed retry regenerates after broken json, then gives up after the configured attempts" {
    mod = load_fixture("llm_typed_retry");
    for (why, person, llm, name, age) in [
        ("sync", mod.get_person_recovering(), mod.recover_llm, "Ada", 36),
        (
            "async",
            asyncio.run(mod.aget_person_recovering()),
            mod.arecover_llm,
            "Zoe",
            27
        )
    ] {
        assert (person.name, person.age) == (name, age) , (
            f"{why}: malformed-then-valid JSON should retry and recover, got {person}"
        );
        assert len(llm.seen_prompts) == 2 , (
            f"{why}: expected one retry (2 attempts), got {len(llm.seen_prompts)}"
        );
        retry_prompt = llm.seen_prompts[1];
        broken = '{"name": "' + name + '", "age":';
        assert broken in retry_prompt , f"{why}: retry prompt missing the broken output:\n{retry_prompt}";
        assert "age" in retry_prompt , f"{why}: retry prompt should re-show the schema";
    }

    for (why, run, llm, attempts, retries) in [
        ("default limit", mod.get_person_failing, mod.exhaust_llm, 4, 3),
        ("instance limit of 1", mod.get_person_limited, mod.limited_llm, 2, 1)
    ] {
        err: any = None;
        try {
            run();
        } except Exception as e {
            err = e;
        }
        assert type(err).__name__ == "OutputConversionError" , (
            f"{why}: expected OutputConversionError once retries are exhausted, got {err!r}"
        );
        assert len(llm.seen_prompts) == attempts , (
            f"{why}: expected exactly {attempts} attempts, got {len(llm.seen_prompts)}"
        );
        assert f"{attempts} attempt" in str(err) and f"{retries} retries" in str(err) , (
            f"{why}: final error should report the counts, got: {err}"
        );
    }

    reset_byllm_config();
    cfg = get_byllm_config(Path(FIXTURE_DIR));
    assert cfg.get_call_params_config().get("max_output_retries") == 3 , (
        "default config flow should expose max_output_retries=3"
    );
    reset_byllm_config();
}

test "typed retry only fires for structured output failures" {
    mod = load_fixture("llm_typed_retry");
    assert mod.get_person_passthrough() == "Average: 86.75" , (
        "a non-empty string should pass through for a structured type"
    );
    assert len(mod.passthrough_llm.seen_prompts) == 1 , "passthrough must not retry";

    assert mod.get_text() == "" , "empty str return should pass through";
    assert len(mod.str_llm.seen_prompts) == 1 , "str return must not retry";

    raised = False;
    try {
        mod.get_person_erroring();
    } except ValueError {
        raised = True;
    }
    assert raised , "a ValueError must propagate, not be retried";
    assert len(mod.error_llm.seen_prompts) == 1 , (
        f"non-conversion error must not retry, got {len(mod.error_llm.seen_prompts)}"
    );
}


"""A tool requiring an argument; calling it with none raises inside Tool.__call__."""
def _needs_arg_tool(x: int) -> str {
    return str(x);
}


"""A tool body that raises at call time."""
def _raising_tool -> str {
    raise ValueError("kaboom");
}


"""A tool with required parameters, for the damaged/truncated split."""
def _writer_tool(file_path: str, content: str) -> str {
    return f"wrote {len(content)} bytes to {file_path}";
}


# Issue #7657: a handled tool failure is returned to the model as a "Tool error"
# observation and logged once at WARNING with no traceback, never at ERROR. A
# callable without __name__ (functools.partial) used to escape as AttributeError.
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

# Streaming leaves finish_reason empty exactly when a call was cut short, so a
# corrupted call is reported by the sanitizer, not the max_tokens guard, and the
# two causes get different advice: only a genuinely truncated call should split.
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
