"""Tool function tests — filesystem, search, shell, jac_tools."""

import pytest
from conftest import run_jac


@pytest.fixture(scope="module")
def tools_output():
    """Run tool test suite once, share output across tests."""
    result = run_jac("tests/check_tools.jac")
    return result


def test_tools_exit_cleanly(tools_output):
    assert tools_output.returncode == 0, (
        f"test_tools.jac failed:\n{tools_output.stdout}\n{tools_output.stderr}"
    )


def test_read_file(tools_output):
    assert "read_file: OK" in tools_output.stdout


def test_write_and_edit_file(tools_output):
    assert "write_file + edit_file: OK" in tools_output.stdout


def test_list_files(tools_output):
    assert "list_files: OK" in tools_output.stdout


def test_grep_search(tools_output):
    assert "grep_search: OK" in tools_output.stdout


def test_find_files(tools_output):
    assert "find_files: OK" in tools_output.stdout


def test_bash_exec(tools_output):
    assert "bash_exec: OK" in tools_output.stdout


def test_jac_check(tools_output):
    assert "jac_check: OK" in tools_output.stdout
