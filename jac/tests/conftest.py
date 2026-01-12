"""Shared pytest fixtures for the tests directory."""

import contextlib
import glob
import inspect
import io
import os
import pickle
import sys
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path
from typing import Any

import pytest

import jaclang

# =============================================================================
# Test Utilities (moved from cli module)
# =============================================================================

_runtime_initialized = False


def ensure_jac_runtime() -> None:
    """Initialize Jac runtime once on first use."""
    global _runtime_initialized
    if not _runtime_initialized:
        from jaclang.pycore.runtime import JacRuntime as Jac

        Jac.setup()
        _runtime_initialized = True


def proc_file_sess(
    filename: str, session: str, root: str | None = None
) -> tuple[str, str, Any]:
    """Create JacRuntime and return the base path, module name, and runtime state.

    This is a test utility for setting up Jac runtime context.
    """
    from jaclang.pycore.runtime import JacRuntime as Jac

    base, mod = os.path.split(filename)
    base = base or "./"
    if filename.endswith(".jac") or filename.endswith(".jir"):
        mod = mod[:-4]
    elif filename.endswith(".py"):
        mod = mod[:-3]
    else:
        raise ValueError("Not a valid file! Only supports `.jac`, `.jir`, and `.py`")

    mach = Jac.create_j_context(session=session, root=root)
    Jac.set_context(mach)
    return (base, mod, mach)


def get_object(
    filename: str, id: str, session: str = "", main: bool = True
) -> dict[str, Any]:
    """Get an object by ID from a Jac program.

    This is a test utility for inspecting object state.

    Args:
        filename: Path to the .jac or .jir file
        id: Object ID to retrieve
        session: Optional session identifier
        main: Treat the module as __main__ (default: True)

    Returns:
        Dictionary containing the object's state
    """
    ensure_jac_runtime()
    from jaclang.pycore.runtime import JacRuntime as Jac

    base, mod, mach = proc_file_sess(filename, session)
    if filename.endswith(".jac"):
        Jac.jac_import(
            target=mod, base_path=base, override_name="__main__" if main else None
        )
    elif filename.endswith(".jir"):
        with open(filename, "rb") as f:
            Jac.attach_program(pickle.load(f))
            Jac.jac_import(
                target=mod, base_path=base, override_name="__main__" if main else None
            )
    else:
        mach.close()
        raise ValueError("Not a valid file! Only supports `.jac` and `.jir`")

    obj = Jac.get_object(id)
    if obj:
        data = obj.__jac__.__getstate__()
    else:
        mach.close()
        raise ValueError(f"Object with id {id} not found.")
    mach.close()
    return data


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
