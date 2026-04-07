"""Phase 4 tests — cross-session project memory."""

import pytest
from conftest import run_jac


@pytest.fixture(scope="module")
def memory_output():
    """Run memory test suite once, share output across tests."""
    result = run_jac("tests/check_memory.jac")
    return result


def test_memory_exits_cleanly(memory_output):
    assert memory_output.returncode == 0, (
        f"check_memory.jac failed:\n{memory_output.stdout}\n{memory_output.stderr}"
    )


def test_find_or_create_empty_dir(memory_output):
    assert "find_or_create_memory empty dir: OK" in memory_output.stdout


def test_find_or_create_creates_node(memory_output):
    assert "find_or_create_memory creates node: OK" in memory_output.stdout


def test_find_or_create_deduplication(memory_output):
    assert "find_or_create_memory deduplication: OK" in memory_output.stdout


def test_summarize_empty(memory_output):
    assert "summarize empty memory: OK" in memory_output.stdout


def test_summarize_architecture(memory_output):
    assert "summarize with architecture: OK" in memory_output.stdout


def test_summarize_file_map(memory_output):
    assert "summarize with file_map: OK" in memory_output.stdout


def test_summarize_file_map_capped(memory_output):
    assert "summarize file_map capped: OK" in memory_output.stdout


def test_update_memory_no_crash(memory_output):
    assert "update_memory_from_session no crash: OK" in memory_output.stdout


def test_project_summary_in_build_context(memory_output):
    assert "project_summary in build_context prefix: OK" in memory_output.stdout
