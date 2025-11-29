"""Pytest configuration and fixtures for runtimelib tests."""

from __future__ import annotations

import inspect
import os

import pytest

import jaclang
from jaclang.runtimelib.utils import read_file_with_encoding


@pytest.fixture
def fixture_path():
    """Get the path to the fixtures directory for the calling test file."""
    # Get the caller's frame to find the test file
    frame = inspect.currentframe()
    if frame is None or frame.f_back is None:
        raise ValueError("Unable to get the previous stack frame.")

    caller_module = inspect.getmodule(frame.f_back)
    if caller_module is None or caller_module.__file__ is None:
        raise ValueError("Unable to determine the file of the module.")

    test_file = caller_module.__file__
    return os.path.join(os.path.dirname(test_file), "fixtures")


@pytest.fixture
def examples_path():
    """Get the path to the examples directory."""
    fixture_src = jaclang.__file__
    file_path = os.path.join(os.path.dirname(os.path.dirname(fixture_src)), "examples")
    return os.path.abspath(file_path)


@pytest.fixture
def load_fixture():
    """Return a function that loads fixture content from the fixtures directory."""

    def _load_fixture(fixture: str) -> str:
        """Load fixture from fixtures directory."""
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")

        caller_module = inspect.getmodule(frame.f_back)
        if caller_module is None or caller_module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")

        test_file = caller_module.__file__
        fixture_path = os.path.join(os.path.dirname(test_file), "fixtures", fixture)
        return read_file_with_encoding(fixture_path)

    return _load_fixture


def fixture_abs_path(fixture: str) -> str:
    """Get absolute path of a fixture from fixtures directory.

    This is a helper function for use in tests that need paths.
    """
    frame = inspect.currentframe()
    if frame is None or frame.f_back is None:
        raise ValueError("Unable to get the previous stack frame.")

    caller_module = inspect.getmodule(frame.f_back)
    if caller_module is None or caller_module.__file__ is None:
        raise ValueError("Unable to determine the file of the module.")

    test_file = caller_module.__file__
    file_path = os.path.join(os.path.dirname(test_file), "fixtures", fixture)
    return os.path.abspath(file_path)
