"""Test Jac cli module."""

import io
import sys
from collections.abc import Callable
from contextlib import AbstractContextManager, suppress

from jaclang.cli.commands import (  # type: ignore[attr-defined]
    analysis,  # type: ignore[attr-defined]
    execution,  # type: ignore[attr-defined]
    tools,  # type: ignore[attr-defined]
)


def test_circle_jac(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        execution.run(examples_path("manual_code/circle.jac"))

    stdout_value = output.getvalue()
    assert "Area of a circle with radius 5 using function: 78" in stdout_value
    assert "Area of a Circle with radius 5 using class: 78" in stdout_value


def test_circle_jac_test(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    stdout_block = io.StringIO()
    sys.stderr = captured_output
    sys.stdout = stdout_block

    analysis.test(examples_path("manual_code/circle.jac"))

    sys.stderr = sys.__stderr__
    sys.stdout = sys.__stdout__
    stderr_value = captured_output.getvalue()
    assert "Ran 3 tests" in stderr_value


def test_clean_circle_jac(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        execution.run(examples_path("manual_code/circle_clean.jac"))

    stdout_value = output.getvalue()
    assert stdout_value == (
        "Area of a circle with radius 5 using function: 78.53981633974483\n"
        "Area of a Circle with radius 5 using class: 78.53981633974483\n"
    )


def test_pure_circle_jac(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        execution.run(examples_path("manual_code/circle_pure.jac"))

    stdout_value = output.getvalue()
    assert stdout_value == (
        "Area of a circle with radius 5 using function: 78.53981633974483\n"
        "Area of a Circle with radius 5 using class: 78.53981633974483\n"
    )


def test_pure_circle_impl_not_double_generated(
    examples_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        tools.tool(
            "ir",
            [
                "py",
                f"{examples_path('manual_code/circle_pure.jac')}",
            ],
        )

    stdout_value = output.getvalue()
    assert "\ndef __init__(self" not in stdout_value


def test_clean_circle_jac_test(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    stdio_block = io.StringIO()
    sys.stderr = captured_output
    sys.stdout = stdio_block

    with suppress(SystemExit):
        analysis.test(examples_path("manual_code/circle_clean_tests.jac"))

    sys.stderr = sys.__stderr__
    sys.stdout = sys.__stdout__
    stderr_value = captured_output.getvalue()
    assert "Ran 3 tests" in stderr_value


def test_pure_circle_jac_test(examples_path: Callable[[str], str]) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    stdio_block = io.StringIO()
    sys.stderr = captured_output
    sys.stdout = stdio_block

    with suppress(SystemExit):
        analysis.test(examples_path("manual_code/circle_pure.test.jac"))

    sys.stderr = sys.__stderr__
    sys.stdout = sys.__stdout__
    stderr_value = captured_output.getvalue()
    assert "Ran 3 tests" in stderr_value


def test_jac_name_in_sys_mods(
    fixture_path: Callable[[str], str],
    capture_stdout: Callable[[], AbstractContextManager[io.StringIO]],
) -> None:
    """Basic test for pass."""
    with capture_stdout() as output:
        execution.run(fixture_path("abc_check.jac"))

    stdout_value = output.getvalue()
    assert "Area of a circle with radius 5 using function: 78" in stdout_value
    assert "Area of a Circle with radius 5 using class: 78" in stdout_value
