"""Tests for Integration with Jaclang."""

import contextlib;
import io;
import os;
import sys;
import warnings;
import unittest.mock;

import pytest;
import yaml;
import from fixtures { python_lib_mode }

import byllm.llm as _byllm_llm_mod;
import from byllm.lib { Model }
import types;
import from byllm.mtir { MTRuntime }
import from byllm.exceptions {
    OutputConversionError,
    ConfigurationError,
    UnknownToolError,
    FinishToolError,
    McpError
}
import from byllm.mcp { McpClient, McpTool }
import from byllm.types { Tool, Message, MessageRole }
import dataclasses;
import from jaclang { JacRuntimeInterface as Jac }

glob jac_import = Jac.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");

test "llm mail summerize" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("llm_mail_summerize", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("method_incl_ctx", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Average marks for Alice : 86.75" in stdout_value;
}

test "with llm function" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_function", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "\U0001f464\u27a1\ufe0f\U0001f5fc" in stdout_value;
}

test "method tool call" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("method_tool", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Calculator.add called with 12, 34" in stdout_value;
    assert "Result: 46" in stdout_value;
}

test "params format" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("llm_params", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    dict_str = stdout_value[stdout_value.find("{"):stdout_value.rfind("}") + 1];
    extracted_dict = yaml.safe_load(dict_str);

    required_keys = [
        "model",
        "api_base",
        "messages",
        "tools",
        "response_format",
        "temperature",
        "max_tokens",

    ];
    for key in required_keys {
        assert key in extracted_dict , f"Missing key: {key}";
    }

    add_message = extracted_dict["messages"];
    assert add_message[0]["role"] == "system" , "First message should be of role 'system'";
    assert add_message[1]["role"] == "user" , "Second message should be of role 'user'";
    assert add_message[3]["role"] == "tool" , "Fourth message should be of role 'tool'";
    assert (
        add_message[3]["content"] == "The current wind speed in Puttalam is about 18-22 km/h."
    ) , "Content mismatch";

    add_tool = extracted_dict["tools"][0];
    assert add_tool["type"] == "function" , "First tool should be of type 'function'";
    assert add_tool["function"]["name"] == "get_live_wind_speed" , "First tool function should be 'get_live_wind_speed'";
    assert "city" in add_tool["function"]["parameters"]["properties"] , "get_live_wind_speed function should have 'city' parameter";
}

test "image input" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("image_test", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "The image shows a hot air balloon shaped like a heart" in stdout_value;
}

test "streaming output" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("streaming_output", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert (
        "The orca whale, or killer whale, is one of the most intelligent and adaptable marine predators" in stdout_value
    );
}

test "streaming with react" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("streaming_with_react", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "29-10-2025" in stdout_value;
    assert "100" in stdout_value;
    assert "Test passed!" in stdout_value;
}

test "logging stream no tools" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("logging_stream_no_tools", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "NO_TOOLS_PASS" in stdout_value;
}

test "logging stream react" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("logging_stream_react", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "REACT_LOGGING_PASS" in stdout_value;
}

test "by expr" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("by_expr", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_method", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_lower", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert (
        "J. Robert Oppenheimer was a Introvert person who died in 1967" in stdout_value
    );
}

test "with llm type" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_type", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "14/03/1879" in stdout_value;
    assert (
        'University (University) (obj) = type(__module__="with_llm_type", __doc__=None, '
        "_jac_entry_funcs_`=[`], _jac_exit_funcs_=[], __init__=function(__wrapped__=function()))" not in stdout_value
    );
    desired_output_count = stdout_value.count(
        "Person(name='Jason Mars', dob='1994-01-01', age=30)"
    );
    assert desired_output_count == 2;
}

test "with llm image" {
    pytest.importorskip("PIL", reason="This test requires Pillow to be installed");
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_image", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "'role': 'system'" in stdout_value;
    assert "{'type': 'text', 'text': 'solve_math_question" in stdout_value;
    assert "data:image/jpeg;base64," in stdout_value[:500];
}

test "webp image support" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("webp_support_test", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "full_name='Albert Einstein'" in stdout_value;
    assert "year_of_death='1955'" in stdout_value;
}

test "with llm video" {
    pytest.importorskip("cv2", reason="This test requires OpenCV to be installed");
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("with_llm_video", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    video_explanation = (
        "The video features a large rabbit emerging from a burrow in a lush, green environment. "
        "The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a "
        "vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere."
    );
    assert video_explanation in stdout_value;
}

test "semstrings" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("llm_semstrings", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("image_types", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("math_poem_agents", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "Agentic minds, we hold dear" in stdout_value;
    assert "Math Result: 35" in stdout_value;
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
    assert "Hello, Alice! It's great to meet you." in stdout_value;
    assert "You are a friendly assistant. Greet the person" in stdout_value;
    assert (
        "'api_base': 'https://your_api_base_here/v1/chat/completions'" in stdout_value
    );
}

test "max react iterations" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("react_max_iterations", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "get_live_wind_speed called for Puttalam" in stdout_value;
    assert "get_speed_unit called" in stdout_value;
    assert "RESULT: FINAL_REPORT" in stdout_value;
    assert "WIND_TOOL_CALLS: 1" in stdout_value;
    assert "UNIT_TOOL_CALLS: 1" in stdout_value;
    assert (
        "Based on the tool calls and their results above, provide only your final answer." in stdout_value
    );
}

test "max react iterations with finish tool call" {
    # Verifies that when max_react_iterations is exceeded and the LLM responds
    # with a finish_tool call (instead of plain text), the output is correctly extracted.
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("react_max_iterations_finish_tool", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "get_live_wind_speed called for Puttalam" in stdout_value;
    assert "get_speed_unit called" in stdout_value;
    assert "RESULT: FINAL_REPORT" in stdout_value;
    assert "WIND_TOOL_CALLS: 1" in stdout_value;
    assert "UNIT_TOOL_CALLS: 1" in stdout_value;
}

test "on_iteration callback ABORT and ABORT_WITH_SUMMARY" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("on_iteration_callback", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("plain_text_recovery", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "PERSON: Merchant" in stdout_value;
    assert "MESSAGE: Greetings traveller, I have wares to trade!" in stdout_value;
}

test "api key from constructor" {
    model = Model(model_name="gpt-4o-mini", api_key="sk-constructor-key");
    assert model.api_key == "sk-constructor-key";
}

test "api key from instance config" {
    model = Model(model_name="gpt-4o-mini", config={"api_key": "sk-config-key"},);
    assert model.api_key == "sk-config-key";
}

test "api key from global config" {
    with unittest.mock.patch.dict(
        _byllm_llm_mod._model_config, {"api_key": "sk-global-key"}, clear=True
    ) {
        model = Model(model_name="gpt-4o-mini");
        assert model.api_key == "sk-global-key";
    }
}

test "api key constructor over instance config" {
    model = Model(
        model_name="gpt-4o-mini",
        api_key="sk-constructor-key",
        config={"api_key": "sk-config-key"},
    );
    assert model.api_key == "sk-constructor-key";
}

test "api key instance config over global" {
    with unittest.mock.patch.dict(
        _byllm_llm_mod._model_config, {"api_key": "sk-global-key"}, clear=True
    ) {
        model = Model(model_name="gpt-4o-mini", config={"api_key": "sk-config-key"},);
        assert model.api_key == "sk-config-key";
    }
}

test "api key empty when none provided" {
    with unittest.mock.patch.dict(
        _byllm_llm_mod._model_config, {"api_key": ""}, clear=True
    ) {
        model = Model(model_name="gpt-4o-mini");
        assert model.api_key == "";
    }
}

test "api key not overwritten on dispatch" {
    model = Model(model_name="gpt-4o-mini", api_key="sk-test-key");
    with contextlib.suppress(Exception) {
        model(temperature=0.5).invoke(None);
    }
    assert model.api_key == "sk-test-key";
}

test "api key masked in log" {
    model = Model(model_name="gpt-4o-mini");
    params = {
        "model": "gpt-4o-mini",
        "api_key": "sk-test-secret-key1234",
        "api_base": None,
        "messages": [
            {"role": "system", "content": "test"},
            {"role": "user", "content": "test"},

        ],
        "tools": None,
        "response_format": None,

    };
    log_output = model.format_prompt(params);
    assert "sk-test-secret-key1234" not in log_output;
    assert params["api_key"] == "sk-test-secret-key1234";
}

test "api key masking formats" {
    model = Model(model_name="gpt-4o-mini");
    params = {
        "api_key": "sk-abcdef1234",
        "messages": [
            {"role": "system", "content": "t"},
            {"role": "user", "content": "t"},

        ],
        "tools": None,
        "response_format": None,

    };
    model.format_prompt(params);
    assert params["api_key"] == "sk-abcdef1234";

    key = str(params["api_key"]);
    masked = "*" * (len(key) - 4) + key[-4:];
    assert masked == "*********1234";
    assert "sk-abcdef" not in masked;

    key_short = "abc";
    masked_short = "*" * (len(key_short) - 1) + key_short[-1:];
    assert masked_short == "**c";

    assert len("x") <= 1;
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    jac_import("builtin_llm", base_path=FIXTURE_DIR + "/");
    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
import from byllm.config_loader { get_byllm_config, reset_byllm_config }
import from jaclang.jac0core.runtime { JacRuntime }

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
    orig = JacRuntime.full_target_path;
    orig_cwd = os.getcwd();
    JacRuntime.full_target_path = os.path.join(GEMINI_FIXTURE, "main.jac");
    reset_byllm_config();
    os.chdir("/tmp");
    try {
        config = get_byllm_config();
        assert config.get_model_config()['default_model'] == "gemini/gemini-1.5-pro";
    } finally {
        os.chdir(orig_cwd);
        JacRuntime.full_target_path = orig;
        reset_byllm_config();
    }
}

# Note: OutputConversionError tests call MTRuntime.parse_response directly because
# MockLLM.dispatch_no_streaming bypasses parse_response, returning the pre-built
# output object straight from CompletionResult. The error lives in parse_response,
# so that is the correct unit to test.
glob _TestPerson = dataclasses.make_dataclass(
         "Person", [("name", str), ("age", int)]
     );

test "output conversion error on plain text" {
    # LLM returns a narrative string instead of JSON
    mt_run = MTRuntime(
        messages=[],
        resp_type=_TestPerson,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raw = "Alice is a 30 year old engineer.";
    raised = False;
    try {
        mt_run.parse_response(raw);
    } except OutputConversionError as e {
        raised = True;
        assert e.raw_output == raw , f"Expected raw_output='{raw}', got '{e.raw_output}'";
        assert "Person" in str(e) , "Error message should name the target type";
    }
    assert raised , "Expected OutputConversionError for plain text input";
}

test "output conversion error on markdown fenced json" {
    # LLM wraps JSON in markdown code fences — json.loads fails
    mt_run = MTRuntime(
        messages=[],
        resp_type=_TestPerson,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raw = "```json\n{\"name\": \"Alice\", \"age\": 30}\n```";
    raised = False;
    try {
        mt_run.parse_response(raw);
    } except OutputConversionError as e {
        raised = True;
        assert e.raw_output == raw , f"Expected raw_output to be the fenced string, got '{e.raw_output}'";
    }
    assert raised , "Expected OutputConversionError for markdown-fenced JSON";
}

test "output conversion error on wrong json structure" {
    # LLM returns valid JSON but it doesn't match the declared type
    mt_run = MTRuntime(
        messages=[],
        resp_type=_TestPerson,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raw = "{\"foo\": \"bar\", \"baz\": 99}";
    raised = False;
    try {
        mt_run.parse_response(raw);
    } except OutputConversionError as e {
        raised = True;
        assert e.raw_output == raw , f"Expected raw_output='{raw}', got '{e.raw_output}'";
    }
    assert raised , "Expected OutputConversionError for structurally wrong JSON";
}

test "output conversion error not raised for str return type" {
    # parse_response should pass through raw strings without attempting conversion
    mt_run = MTRuntime(
        messages=[],
        resp_type=str,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raw = "This is not JSON at all";
    result = mt_run.parse_response(raw);
    assert result == raw , "str return type should return the raw response as-is";
}

test "output conversion error not raised for valid json" {
    # Valid JSON that matches the type should succeed with no exception
    mt_run = MTRuntime(
        messages=[],
        resp_type=_TestPerson,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raw = "{\"schema_object_wrapper\": {\"name\": \"Alice\", \"age\": 30}}";
    result = mt_run.parse_response(raw);
    assert result.name == "Alice" , f"Expected name='Alice', got '{result.name}'";
    assert result.age == 30 , f"Expected age=30, got '{result.age}'";
}

# ConfigurationError tests call get_output_schema directly because schema generation
# is what rejects bare unparameterized types (list, dict, set, tuple).
test "configuration error on bare list return type" {
    # Bare list (no type parameter) is rejected by schema generation
    mt_run = MTRuntime(
        messages=[],
        resp_type=list,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raised = False;
    try {
        mt_run.get_output_schema();
    } except ConfigurationError as e {
        raised = True;
        assert "list" in str(e).lower() , f"Error message should mention 'list', got: {e}";
    }
    assert raised , "Expected ConfigurationError for bare list return type";
}

test "configuration error on bare dict return type" {
    # Bare dict (no type parameters) is rejected by schema generation
    mt_run = MTRuntime(
        messages=[],
        resp_type=dict,
        stream=False,
        tools=[],
        call_params={},
        mtir=None  # type: ignore[arg-type]
    );

    raised = False;
    try {
        mt_run.get_output_schema();
    } except ConfigurationError as e {
        raised = True;
        assert "dict" in str(e).lower() , f"Error message should mention 'dict', got: {e}";
    }
    assert raised , "Expected ConfigurationError for bare dict return type";
}

# UnknownToolError is raised in BaseLLM.dispatch_no_streaming when the LLM responds
# with a tool_call whose name is not registered in MTRuntime.tools.
# model_call_no_stream is mocked so no real API key is needed.
test "unknown tool error when llm calls unregistered tool" {
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

    raised = False;
    with unittest.mock.patch.object(
        model, "model_call_no_stream", return_value=fake_response
    ) {
        try {
            model.dispatch_no_streaming(mt_run);
        } except UnknownToolError as e {
            raised = True;
            assert "nonexistent_tool" in str(e) , f"Error should name the tool, got: {e}";
        }
    }
    assert raised , "Expected UnknownToolError for unregistered tool name";
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

# =============================================================================
# LiteLLM Debug Config Tests
# =============================================================================
test "litellm debug disabled by default" {
    # Default config has debug=False, so _disable_debugging should be called
    import from litellm._logging {
        verbose_logger,
        verbose_router_logger,
        verbose_proxy_logger
    }
    with unittest.mock.patch.dict(
        _byllm_llm_mod._litellm_config,
        {"debug": False, "drop_params": True},
        clear=True
    ) {
        model = Model(model_name="gpt-4o-mini");
        # When debug is False, _disable_debugging() sets .disabled = True
        assert verbose_logger.disabled , "verbose_logger should be disabled when debug=False";
        assert verbose_router_logger.disabled , "verbose_router_logger should be disabled when debug=False";
        assert verbose_proxy_logger.disabled , "verbose_proxy_logger should be disabled when debug=False";
    }
}

test "litellm debug enabled via config" {
    # When debug=True, _disable_debugging should NOT be called
    import from litellm._logging {
        verbose_logger,
        verbose_router_logger,
        verbose_proxy_logger
    }
    # Re-enable the loggers so we can verify they stay enabled
    verbose_logger.disabled = False;
    verbose_router_logger.disabled = False;
    verbose_proxy_logger.disabled = False;

    with unittest.mock.patch.dict(
        _byllm_llm_mod._litellm_config, {"debug": True, "drop_params": True}, clear=True
    ) {
        model = Model(model_name="gpt-4o-mini");
        assert not verbose_logger.disabled , "verbose_logger should remain enabled when debug=True";
        assert not verbose_router_logger.disabled , "verbose_router_logger should remain enabled when debug=True";
        assert not verbose_proxy_logger.disabled , "verbose_proxy_logger should remain enabled when debug=True";
    }
}

test "litellm debug default config value" {
    # Verify the default config structure includes debug=False
    import from byllm.config_loader { JacByllmConfig }
    config = JacByllmConfig();
    defaults = config.get_default_config();
    assert "litellm" in defaults , "Default config should have 'litellm' section";
    assert "debug" in defaults["litellm"] , "litellm defaults should include 'debug' key";
    assert defaults["litellm"]["debug"] == False , "litellm debug should default to False";
}

test "litellm config get_litellm_config includes debug" {
    # Verify get_litellm_config returns the debug field
    import from byllm.config_loader { JacByllmConfig }
    config = JacByllmConfig();
    litellm_config = config.get_litellm_config();
    assert "debug" in litellm_config , "get_litellm_config should return 'debug' key";
    assert isinstance(litellm_config["debug"], bool) , "debug value should be a boolean";
}

import litellm;
import from byllm.exceptions { AuthenticationError, RateLimitError, ModelNotFoundError }

import from loguru { logger as _loguru_logger }

test "exception logging works with debug disabled" {
    # With debug=False, litellm verbose loggers are disabled but byllm's
    # own logger.error calls should still fire and exceptions should propagate.
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
            with unittest.mock.patch("litellm.completion", side_effect=auth_err) {
                raised = False;
                try {
                    model.model_call_no_stream(
                        {"model": "gpt-4o-mini", "messages": []}
                    );
                } except AuthenticationError as e {
                    raised = True;
                    assert "Invalid API key" in str(e);
                }
                assert raised , "AuthenticationError should propagate with debug disabled";
                log_value = log_output.getvalue();
                assert "LLM AuthenticationError" in log_value , f"logger.error should log AuthenticationError, got: {log_value}";
            }
        }
    } finally {
        _loguru_logger.remove(handler_id);
    }
}

test "exception logging works with debug enabled" {
    # With debug=True, same exception handling and logging should work identically.
    log_output = io.StringIO();
    _loguru_logger.remove();
    handler_id = _loguru_logger.add(log_output, level="ERROR");
    try {
        with unittest.mock.patch.dict(
            _byllm_llm_mod._litellm_config,
            {"debug": True, "drop_params": True},
            clear=True
        ) {
            model = Model(model_name="gpt-4o-mini");
            rate_err = litellm.exceptions.RateLimitError(
                message="Rate limit exceeded",
                llm_provider="openai",
                model="gpt-4o-mini"
            );
            with unittest.mock.patch("litellm.completion", side_effect=rate_err) {
                raised = False;
                try {
                    model.model_call_no_stream(
                        {"model": "gpt-4o-mini", "messages": []}
                    );
                } except RateLimitError as e {
                    raised = True;
                    assert "Rate limit" in str(e);
                }
                assert raised , "RateLimitError should propagate with debug enabled";
                log_value = log_output.getvalue();
                assert "LLM RateLimitError" in log_value , f"logger.error should log RateLimitError, got: {log_value}";
            }
        }
    } finally {
        _loguru_logger.remove(handler_id);
    }
}

test "all exception types log and propagate regardless of debug" {
    # Test all three exception types with debug disabled — verify both raise and log
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
            # AuthenticationError
            with unittest.mock.patch(
                "litellm.completion",
                side_effect=litellm.exceptions.AuthenticationError(
                    message="bad key", llm_provider="openai", model="gpt-4o-mini"
                )
            ) {
                raised = False;
                try {
                    model.model_call_no_stream(
                        {"model": "gpt-4o-mini", "messages": []}
                    );
                } except AuthenticationError {
                    raised = True;
                }
                assert raised , "AuthenticationError should propagate";
            }
            # RateLimitError
            with unittest.mock.patch(
                "litellm.completion",
                side_effect=litellm.exceptions.RateLimitError(
                    message="quota exceeded", llm_provider="openai", model="gpt-4o-mini"
                )
            ) {
                raised = False;
                try {
                    model.model_call_no_stream(
                        {"model": "gpt-4o-mini", "messages": []}
                    );
                } except RateLimitError {
                    raised = True;
                }
                assert raised , "RateLimitError should propagate";
            }
            # NotFoundError
            with unittest.mock.patch(
                "litellm.completion",
                side_effect=litellm.exceptions.NotFoundError(
                    message="model not found", model="gpt-fake", llm_provider="openai"
                )
            ) {
                raised = False;
                try {
                    model.model_call_no_stream({"model": "gpt-fake", "messages": []});
                } except ModelNotFoundError {
                    raised = True;
                }
                assert raised , "ModelNotFoundError should propagate";
            }
            # Verify all three were logged
            log_value = log_output.getvalue();
            assert "LLM AuthenticationError" in log_value , f"Should log AuthenticationError, got: {log_value}";
            assert "LLM RateLimitError" in log_value , f"Should log RateLimitError, got: {log_value}";
            assert "LLM ModelNotFoundError" in log_value , f"Should log ModelNotFoundError, got: {log_value}";
        }
    } finally {
        _loguru_logger.remove(handler_id);
    }
}

"""Test ModelPool fallback strategy: router is configured with unique aliases and
a fallbacks chain; successful responses are returned via the dispatch pipeline."""
test "model pool router fallback" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_pool_fallback", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "fallback_success" in stdout_value;
}

"""Test ModelPool load-balancing (simple-shuffle): all three deployments share the
pool-model alias; three independent calls all succeed and the alias is pool-model."""
test "model pool router load balance" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_pool_round_robin", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "pool_alias:pool-model" in stdout_value;
    assert stdout_value.count("load_balance_response") == 3;
}

"""Test ModelPool propagates router exceptions: when the LiteLLM Router
raises (all deployments exhausted) the exception reaches the caller."""
test "model pool router all fail" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_pool_all_fail", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "EXPECTED_ERROR: RateLimitError" in stdout_value;
    assert "UNEXPECTED" not in stdout_value;
}

"""Test ModelPool cost-based-routing uses the async path (acompletion).
LiteLLM Router only supports cost-based-routing via acompletion(); ModelPool
bridges this via ThreadPoolExecutor to stay safe in async frameworks."""
test "model pool router cost based" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_fallbacks_convenience", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
    assert "cost_based_success" in stdout_value;
}

"""Test ModelPool LiteLLM Router model_list initialisation.
Fallback strategy: unique per-model aliases + fallbacks list.
Load-balance strategy: all models share pool-model alias."""
test "model pool router init" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_pool_router_init", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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
    captured_output = io.StringIO();
    sys.stdout = captured_output;

    jac_import("model_pool_streaming_fallback", base_path=FIXTURE_DIR + "/");

    sys.stdout = sys.__stdout__;
    stdout_value = captured_output.getvalue();
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

import from byllm.llm {
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
    assert "cache_control" not in messages[3].get("content")[0];
    assert messages[3].get("content")[-1].get(
        "cache_control"
    ) == _CACHE_CONTROL_EPHEMERAL;
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
        assert _is_prompt_caching_eligible(
            "anthropic/claude-sonnet-4-20250514"
        ) == False;
    }
}
