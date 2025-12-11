"""Shared pytest fixtures for the tests directory."""

import contextlib
import inspect
import io
import os
import sys
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path

import pytest

import jaclang


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Get absolute path to fixture file.

    Looks for fixtures in the test module's fixtures/ subdirectory,
    or falls back to tests/language/fixtures/ for tests that expect
    language fixtures.
    """

    def _fixture_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__

        # First try fixtures relative to the calling test file
        local_fixture = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        if os.path.exists(local_fixture):
            return os.path.abspath(local_fixture)

        # Fall back to tests/language/fixtures/ for language tests
        tests_root = Path(__file__).parent
        lang_fixture = tests_root / "language" / "fixtures" / fixture
        if lang_fixture.exists():
            return str(lang_fixture.resolve())

        # Return local path even if it doesn't exist (for error messages)
        return os.path.abspath(local_fixture)

    return _fixture_path


@pytest.fixture
def capture_stdout() -> Callable[[], AbstractContextManager[io.StringIO]]:
    """Capture stdout and return context manager."""

    @contextlib.contextmanager
    def _capture() -> Generator[io.StringIO, None, None]:
        captured = io.StringIO()
        old_stdout = sys.stdout
        sys.stdout = captured
        try:
            yield captured
        finally:
            sys.stdout = old_stdout

    return _capture


@pytest.fixture
def examples_path() -> Callable[[str], str]:
    """Get path to examples directory."""

    def _examples_path(path: str) -> str:
        examples_dir = Path(jaclang.__file__).parent.parent / "examples"
        return str((examples_dir / path).resolve())

    return _examples_path


@pytest.fixture
def lang_fixture_path() -> Callable[[str], str]:
    """Get path to language fixtures directory."""

    def _lang_fixture_path(file: str) -> str:
        tests_dir = Path(__file__).parent
        file_path = tests_dir / "language" / "fixtures" / file
        return str(file_path.resolve())

    return _lang_fixture_path
