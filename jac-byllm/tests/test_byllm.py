"""Tests for Integration with Jaclang."""

import contextlib
import io
import os
import sys
from collections.abc import Callable

import pytest
import yaml
from fixtures import python_lib_mode

from jaclang import JacRuntimeInterface as Jac

# Import the jac_import function from JacRuntimeInterface
jac_import = Jac.jac_import


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Fixture to get the absolute path of fixtures directory."""

    def _fixture_abs_path(fixture: str) -> str:
        """Get absolute path of a fixture from fixtures directory."""
        # Get the directory of the current test file
        test_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(test_dir, "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_abs_path


def test_llm_mail_summerize(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("llm_mail_summerize", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    summaries = [
        "AetherGuard reports a login to your account from a new device in Berlin and advises a password reset if the activity was unauthorized.",
        "Claire from Novelink invites writers to a biweekly Writer's Circle this Friday for sharing work and receiving feedback in a supportive environment.",
        "Marcus Bentley from FinTracker reports a weekly spending total of $342.65, mainly on Groceries, Transport, and Dining, with a link for detailed insights.",
        "TechNews from DailyByte highlights how quantum computing is set to transform fields like cryptography and climate modeling, with more details in the full article.",
        "Nora Hartwell from Wanderlust Travels offers a 30% discount on international trips booked this week, urging recipients to take advantage of the limited-time travel deal.",
    ]
    for summary in summaries:
        assert summary in stdout_value


def test_method_include_context(fixture_path: Callable[[str], str]) -> None:
    """Test the method include context functionality."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("method_incl_ctx", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()

    # Check if the output contains the expected context information
    assert "Average marks for Alice : 86.75" in stdout_value


def test_with_llm_function(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_function", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "👤➡️🗼" in stdout_value


def test_method_tool_call(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("method_tool", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Calculator.add called with 12, 34" in stdout_value
    assert "Result: 46" in stdout_value


def test_params_format(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("llm_params", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    dict_str = stdout_value[stdout_value.find("{") : stdout_value.rfind("}") + 1]
    extracted_dict = yaml.safe_load(dict_str)

    required_keys = [
        "model",
        "api_base",
        "messages",
        "tools",
        "response_format",
        "temperature",
        "max_tokens",
    ]
    for key in required_keys:
        assert key in extracted_dict, f"Missing key: {key}"

    add_message = extracted_dict["messages"]
    assert add_message[0]["role"] == "system", (
        "First message should be of role 'system'"
    )
    assert add_message[1]["role"] == "user", "Second message should be of role 'user'"
    assert add_message[3]["role"] == "tool", "Fourth message should be of role 'tool'"
    assert (
        add_message[3]["content"]
        == "The current wind speed in Puttalam is about 18-22 km/h."
    ), "Content mismatch"

    add_tool = extracted_dict["tools"][0]
    assert add_tool["type"] == "function", "First tool should be of type 'function'"
    assert add_tool["function"]["name"] == "get_live_wind_speed", (
        "First tool function should be 'get_live_wind_speed'"
    )
    assert "city" in add_tool["function"]["parameters"]["properties"], (
        "get_live_wind_speed function should have 'city' parameter"
    )


def test_image_input(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("image_test", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "The image shows a hot air balloon shaped like a heart" in stdout_value


def test_streaming_output(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("streaming_output", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert (
        "The orca whale, or killer whale, is one of the most intelligent and adaptable marine predators"
        in stdout_value
    )


def test_streaming_with_react(fixture_path: Callable[[str], str]) -> None:
    """Test streaming output with ReAct method (tool calling)."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("streaming_with_react", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "29-10-2025" in stdout_value
    assert "100" in stdout_value
    assert "Test passed!" in stdout_value


def test_by_expr(fixture_path: Callable[[str], str]) -> None:
    """Test by llm['as'].expression instead of llm() call."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("by_expr", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    expected_lines = (
        "Generated greeting: Hello, Alice! It's great to see you!",
        "[run_and_test_python_code] Executing code:",
        "[run_and_test_python_code] \"name = 'Alice'\\nprint(f'Hello, {name}! Welcome to the Python world!')\"",
        "Hello, Alice! Welcome to the Python world!",
        "[run_and_test_python_code] Code executed successfully.",
        "Generated greeting code: name = 'Alice'",
        "print(f'Hello, {name}! Welcome to the Python world!')",
    )
    for line in expected_lines:
        assert line in stdout_value


def test_with_llm_method(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_method", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    # TODO: Reasoning is not passed as an output, however this needs to be
    # sent to some callbacks (or other means) to the user.
    # assert "[Reasoning] <Reason>" in stdout_value
    assert "Personality.INTROVERT" in stdout_value


def test_with_llm_lower(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_lower", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    # TODO: Reasoning is not passed as an output, however this needs to be
    # sent to some callbacks (or other means) to the user.
    # assert "[Reasoning] <Reason>" in stdout_value
    assert (
        "J. Robert Oppenheimer was a Introvert person who died in 1967" in stdout_value
    )


def test_with_llm_type(fixture_path: Callable[[str], str]) -> None:
    """Parse micro jac file."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_type", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "14/03/1879" in stdout_value
    assert (
        'University (University) (obj) = type(__module__="with_llm_type", __doc__=None, '
        "_jac_entry_funcs_`=[`], _jac_exit_funcs_=[], __init__=function(__wrapped__=function()))"
        not in stdout_value
    )
    desired_output_count = stdout_value.count(
        "Person(name='Jason Mars', dob='1994-01-01', age=30)"
    )
    assert desired_output_count == 2


def test_with_llm_image(fixture_path: Callable[[str], str]) -> None:
    """Test MTLLLM Image Implementation."""
    pytest.importorskip("PIL", reason="This test requires Pillow to be installed.")
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_image", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    # Verify the system message is present in the output
    assert "'role': 'system'" in stdout_value
    # Verify the user content with text type is present
    assert "{'type': 'text', 'text': 'solve_math_question" in stdout_value
    # Verify base64 image data is in the first 500 chars (images should come later)
    assert "data:image/jpeg;base64," in stdout_value[:500]


def test_webp_image_support(fixture_path: Callable[[str], str]) -> None:
    """Test MTLLLM image support for webp format."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("webp_support_test", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "full_name='Albert Einstein'" in stdout_value
    assert "year_of_death='1955'" in stdout_value


def test_with_llm_video(fixture_path: Callable[[str], str]) -> None:
    """Test MTLLLM Video Implementation."""
    pytest.importorskip("cv2", reason="This test requires OpenCV to be installed.")
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("with_llm_video", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    video_explanation = (
        "The video features a large rabbit emerging from a burrow in a lush, green environment. "
        "The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a "
        "vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere."
    )
    assert video_explanation in stdout_value


def test_semstrings(fixture_path: Callable[[str], str]) -> None:
    """Test the semstrings with the new sem keyword.

    obj Foo {
        def bar(baz: int) -> str;
    }
    sem Foo.bar.baz = "Some semantic string for Foo.bar.baz";
    """
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("llm_semstrings", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Specific number generated: 120597" in stdout_value

    i = stdout_value.find("Generated password:")
    password = stdout_value[i:].split("\n")[0]

    assert len(password) >= 8, "Password should be at least 8 characters long."
    assert any(c.isdigit() for c in password), (
        "Password should contain at least one digit."
    )
    assert any(c.isupper() for c in password), (
        "Password should contain at least one uppercase letter."
    )
    assert any(c.islower() for c in password), (
        "Password should contain at least one lowercase letter."
    )


def test_python_lib_mode() -> None:
    """Test the Python library mode."""
    person = python_lib_mode.test_get_person_info()

    # Check if the output contains the expected person information
    assert "Alan Turing" in person.name
    assert "1912" in str(person.birth_year)
    assert "A pioneering mathematician and computer scientist" in person.description
    assert "breaking the Enigma code" in person.description


def test_enum_without_value(fixture_path: Callable[[str], str]) -> None:
    """This tests enum without values, where enum names gets into the prompt."""
    from loguru import logger

    captured_output = io.StringIO()
    logger.remove()
    logger.add(captured_output)
    with contextlib.suppress(Exception):
        # API key error is expected, but we still capture the output before the error
        jac_import("enum_no_value", base_path=fixture_path("./"))
    stdout_value = captured_output.getvalue()
    assert "YES" in stdout_value
    assert "NO" in stdout_value


def test_fixtures_image_types(fixture_path: Callable[[str], str]) -> None:
    """Test various image input types in Jaclang."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("image_types", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
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
    ]
    for label in expected_labels:
        assert label in stdout_value


def test_visit_by_for_routing(fixture_path: Callable[[str], str]) -> None:
    """Test the visit by functionality for routing."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("math_poem_agents", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Agentic minds, we hold dear" in stdout_value
    assert "Math Result: 35" in stdout_value


def test_max_react_iterations(fixture_path: Callable[[str], str]) -> None:
    """Test that max_react_iterations stops ReAct tool loop and forces a final answer."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    jac_import("react_max_iterations", base_path=fixture_path("./"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "get_live_wind_speed called for Puttalam" in stdout_value
    assert "get_speed_unit called" in stdout_value
    assert "RESULT: FINAL_REPORT" in stdout_value
    assert "WIND_TOOL_CALLS: 1" in stdout_value
    assert "UNIT_TOOL_CALLS: 1" in stdout_value
    assert (
        "Based on the tool calls and their results above, provide only your final answer."
        in stdout_value
    )
