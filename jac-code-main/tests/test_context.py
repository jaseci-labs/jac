"""Phase 3 tests — smart context management and compaction."""

import pytest
from conftest import run_jac


@pytest.fixture(scope="module")
def context_output():
    """Run context test suite once, share output across tests."""
    result = run_jac("tests/check_context.jac")
    return result


def test_context_exits_cleanly(context_output):
    assert context_output.returncode == 0, (
        f"check_context.jac failed:\n{context_output.stdout}\n{context_output.stderr}"
    )


def test_estimate_tokens_basic(context_output):
    assert "estimate_tokens basic: OK" in context_output.stdout


def test_needs_compaction_short_long(context_output):
    assert "needs_compaction short/long: OK" in context_output.stdout


def test_build_context_passthrough(context_output):
    assert "build_context passthrough: OK" in context_output.stdout


def test_build_context_active_files_prefix(context_output):
    assert "build_context active_files prefix: OK" in context_output.stdout


def test_build_context_pending_errors_prefix(context_output):
    assert "build_context pending_errors prefix: OK" in context_output.stdout


def test_build_context_preserves_recent(context_output):
    assert "build_context preserves recent turns: OK" in context_output.stdout


def test_build_context_preserves_important(context_output):
    assert "build_context preserves session goal: OK" in context_output.stdout


def test_build_context_summary_entry(context_output):
    assert "build_context summary entry: OK" in context_output.stdout


def test_build_context_empty_history(context_output):
    assert "build_context empty history: OK" in context_output.stdout
