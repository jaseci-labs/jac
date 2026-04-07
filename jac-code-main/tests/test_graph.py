"""Graph structure tests — MainAgent creation, Session wiring, idempotency."""

import pytest

from conftest import run_jac


@pytest.fixture(scope="module")
def graph_output():
    """Run graph test suite once, share output across tests."""
    result = run_jac("tests/check_graph.jac")
    return result


def test_graph_exits_cleanly(graph_output):
    assert graph_output.returncode == 0, (
        f"test_graph.jac failed:\n{graph_output.stdout}\n{graph_output.stderr}"
    )


def test_main_agent_lazy_creation(graph_output):
    assert "MainAgent: OK" in graph_output.stdout


def test_session_creation(graph_output):
    assert "Session: OK" in graph_output.stdout


def test_session_agent_edge(graph_output):
    assert "Session->MainAgent edge: OK" in graph_output.stdout


def test_ensure_main_agent_idempotent(graph_output):
    assert "ensure_main_agent idempotent: OK" in graph_output.stdout
