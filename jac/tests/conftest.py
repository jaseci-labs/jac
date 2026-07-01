"""Shared pytest fixtures for jac/tests directory.

Plugin management is configured here to apply only to core jac tests,
not to package-specific tests like jac-byllm, jac-client, etc.
"""

import contextlib
from typing import Any

import pytest

# =============================================================================
# Console Output Normalization - Disable Rich styling during tests
# =============================================================================


@pytest.fixture(autouse=True)
def disable_rich_console_formatting(monkeypatch: pytest.MonkeyPatch) -> None:
    """Disable Rich console formatting for consistent test output.

    Sets NO_COLOR and NO_EMOJI environment variables to ensure tests
    get plain text output without ANSI codes or emoji prefixes.
    """
    monkeypatch.setenv("NO_COLOR", "1")
    monkeypatch.setenv("NO_EMOJI", "1")


