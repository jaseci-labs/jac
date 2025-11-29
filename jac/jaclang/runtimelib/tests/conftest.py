"""Pytest configuration and fixtures for runtimelib tests."""

from __future__ import annotations

from pathlib import Path


def fixture_abs_path(fixture: str) -> str:
    """Get absolute path of a fixture from the runtimelib fixtures directory.

    This is a standalone helper function for use in helper classes and functions
    that need fixture paths outside of test functions.

    Note: For test functions, use the pytest fixture_path fixture from root conftest.py.
    """
    fixtures_dir = Path(__file__).parent / "fixtures"
    return str((fixtures_dir / fixture).resolve())
