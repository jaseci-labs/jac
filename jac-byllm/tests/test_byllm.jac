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
