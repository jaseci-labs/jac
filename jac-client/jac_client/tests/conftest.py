"""Pytest configuration and shared fixtures for jac-client tests."""

from __future__ import annotations

import inspect
import os
from pathlib import Path

import pytest
from jaclang.runtimelib.utils import read_file_with_encoding


@pytest.fixture
def fixture_path() -> callable:
    """Fixture to get absolute path of a fixture from fixtures directory.

    Returns a function that takes a fixture name and returns its absolute path.
    """
    def _get_fixture_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None or frame.f_back.f_back is None:
            raise ValueError("Unable to get the calling stack frame.")
        module = inspect.getmodule(frame.f_back.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    return _get_fixture_path


@pytest.fixture
def examples_path() -> callable:
    """Fixture to get absolute path of an example from examples directory.

    Returns a function that takes an example name and returns its absolute path.
    """
    def _get_examples_path(example: str) -> str:
        # Get the jac_client module path
        tests_dir = Path(__file__).parent
        jac_client_root = tests_dir.parent
        file_path = jac_client_root / "examples" / example
        return str(file_path.absolute())

    return _get_examples_path


@pytest.fixture
def load_fixture() -> callable:
    """Fixture to load fixture content from fixtures directory.

    Returns a function that takes a fixture name and returns its content.
    """
    def _load_fixture(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None or frame.f_back.f_back is None:
            raise ValueError("Unable to get the calling stack frame.")
        module = inspect.getmodule(frame.f_back.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        fixture_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return read_file_with_encoding(fixture_path)

    return _load_fixture
