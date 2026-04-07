"""Interact walker tests — graph traversal and optional LLM integration."""

import os

import pytest

from conftest import run_jac


@pytest.fixture(scope="module")
def interact_output():
    """Run interact test suite once, share output across tests."""
    result = run_jac("tests/check_interact.jac", timeout=120)
    return result


def test_interact_exits_cleanly(interact_output):
    assert interact_output.returncode == 0, (
        f"test_interact.jac failed:\n{interact_output.stdout}\n{interact_output.stderr}"
    )


def test_session_created(interact_output):
    assert "Session created:" in interact_output.stdout


def test_session_agent_connectivity(interact_output):
    assert "Session->MainAgent edges: 1" in interact_output.stdout


def test_graph_structure_ok(interact_output):
    assert "Graph structure: OK" in interact_output.stdout


@pytest.mark.skipif(
    not os.environ.get("OPENAI_API_KEY")
    or os.environ.get("OPENAI_API_KEY") == "your-api-key-here",
    reason="OPENAI_API_KEY not set — skipping LLM integration test",
)
def test_llm_full_flow(interact_output):
    assert "Full LLM flow: OK" in interact_output.stdout
