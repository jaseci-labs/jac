"""Phase 2 tests — event system timing and turn summary."""

import pytest
from conftest import run_jac


@pytest.fixture(scope="module")
def events_output():
    result = run_jac("tests/check_events.jac")
    return result


def test_events_exits_cleanly(events_output):
    assert events_output.returncode == 0, (
        f"check_events.jac failed:\n{events_output.stdout}\n{events_output.stderr}"
    )


def test_tool_status_tool_end_events(events_output):
    assert "tool_status + tool_end events: OK" in events_output.stdout


def test_tool_end_error_flag(events_output):
    assert "tool_end error flag: OK" in events_output.stdout


def test_auto_close_previous_tool(events_output):
    assert "auto-close previous tool: OK" in events_output.stdout


def test_turn_summary(events_output):
    assert "turn summary: OK" in events_output.stdout


def test_turn_summary_event_emission(events_output):
    assert "turn summary event emission: OK" in events_output.stdout


def test_empty_turn_summary(events_output):
    assert "empty turn summary: OK" in events_output.stdout
