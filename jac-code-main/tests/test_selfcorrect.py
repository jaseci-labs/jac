"""Phase 1 tests — self-correcting tools and metadata persistence."""

import pytest
from conftest import run_jac


@pytest.fixture(scope="module")
def selfcorrect_output():
    """Run self-correction test suite once, share output across tests."""
    result = run_jac("tests/check_selfcorrect.jac")
    return result


def test_selfcorrect_exits_cleanly(selfcorrect_output):
    assert selfcorrect_output.returncode == 0, (
        f"check_selfcorrect.jac failed:\n{selfcorrect_output.stdout}\n{selfcorrect_output.stderr}"
    )


# write_code / edit_code
def test_write_checked_valid_jac(selfcorrect_output):
    assert "write_code valid .jac: OK" in selfcorrect_output.stdout


def test_write_checked_broken_jac_graceful(selfcorrect_output):
    assert "write_code broken .jac (graceful): OK" in selfcorrect_output.stdout


def test_edit_checked_valid_jac(selfcorrect_output):
    assert "edit_code valid .jac: OK" in selfcorrect_output.stdout


def test_edit_checked_bad_old_string(selfcorrect_output):
    assert "edit_code bad old_string: OK" in selfcorrect_output.stdout


def test_write_checked_py_no_validation(selfcorrect_output):
    assert "write_code .py (no validation): OK" in selfcorrect_output.stdout


def test_write_checked_json_no_validation(selfcorrect_output):
    assert "write_code .json (no validation): OK" in selfcorrect_output.stdout


# _enforce_check logic (pure string parsing)
def test_enforce_check_validation_errors(selfcorrect_output):
    assert "enforce_check VALIDATION ERRORS: OK" in selfcorrect_output.stdout


def test_enforce_check_runtime_errors(selfcorrect_output):
    assert "enforce_check RUNTIME ERRORS: OK" in selfcorrect_output.stdout


def test_enforce_check_permission_denied(selfcorrect_output):
    assert "enforce_check permission denied: OK" in selfcorrect_output.stdout


def test_enforce_check_non_jac(selfcorrect_output):
    assert "enforce_check non-jac: OK" in selfcorrect_output.stdout


def test_enforce_check_clean_passthrough(selfcorrect_output):
    assert "enforce_check clean passthrough: OK" in selfcorrect_output.stdout


# Metadata persistence
def test_persist_response_with_metadata(selfcorrect_output):
    assert "persist_response with metadata: OK" in selfcorrect_output.stdout


def test_persist_response_without_metadata(selfcorrect_output):
    assert "persist_response without metadata: OK" in selfcorrect_output.stdout
