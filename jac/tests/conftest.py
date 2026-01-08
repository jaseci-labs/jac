"""Shared pytest fixtures for the tests directory."""

import contextlib
import glob
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


# Store unregistered plugins globally for session-level management
_external_plugins: list = []


def pytest_configure(config: pytest.Config) -> None:
    """Disable external plugins at the start of the test session.

    External plugins (jac-scale, jac-client, etc.) are disabled during tests
    to ensure a clean test environment without MongoDB connections or other
    plugin-specific dependencies.

    Uses JAC_DISABLED_PLUGINS=* for subprocess-based tests that spawn new jac processes.
    """
    from jaclang.pycore.runtime import JacRuntimeImpl, plugin_manager

    # Set env var for subprocess-based tests that spawn new jac processes
    os.environ["JAC_DISABLED_PLUGINS"] = "*"

    global _external_plugins
    for name, plugin in list(plugin_manager.list_name_plugin()):
        if plugin is JacRuntimeImpl or name == "JacRuntimeImpl":
            continue
        _external_plugins.append((name, plugin))
        plugin_manager.unregister(plugin=plugin, name=name)


def pytest_unconfigure(config: pytest.Config) -> None:
    """Re-register external plugins at the end of the test session."""
    from jaclang.pycore.runtime import plugin_manager

    # Remove env var
    os.environ.pop("JAC_DISABLED_PLUGINS", None)

    global _external_plugins
    for name, plugin in _external_plugins:
        with contextlib.suppress(ValueError):
            plugin_manager.register(plugin, name=name)
    _external_plugins.clear()


def _cleanup_shelf_db_files() -> None:
    """Remove anchor_store.db files that may be created by jac-scale plugin."""
    for pattern in [
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir",
    ]:
        for file in glob.glob(pattern):
            with contextlib.suppress(Exception):
                Path(file).unlink()


@pytest.fixture(autouse=True)
def cleanup_plugin_artifacts():
    """Clean up files created by external plugins before and after each test."""
    _cleanup_shelf_db_files()
    yield
    _cleanup_shelf_db_files()
