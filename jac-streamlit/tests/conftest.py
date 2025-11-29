"""Pytest configuration for jac-streamlit tests."""

from pathlib import Path

import pytest


@pytest.fixture
def fixture_path():
    """Get absolute path of a fixture from fixtures directory.

    Usage:
        fixture_path("sample.jac") returns absolute path to tests/fixtures/sample.jac
    """

    def _fixture_path(fixture: str) -> str:
        """Get absolute path for a fixture file."""
        tests_dir = Path(__file__).parent
        fixture_file = tests_dir / "fixtures" / fixture
        return str(fixture_file.absolute())

    return _fixture_path
