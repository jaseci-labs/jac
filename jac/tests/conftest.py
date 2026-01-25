"""Shared pytest fixtures for jac/tests directory.

Plugin management is configured here to apply only to core jac tests,
not to package-specific tests like jac-byllm, jac-client, etc.
"""

import contextlib
import inspect
import io
import os
import sys
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager
from pathlib import Path
from typing import Any

import pytest

import jaclang

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


# =============================================================================
# Plugin Management - Core Jac Tests Only
# =============================================================================

# Store unregistered plugins for session-level management
_external_plugins: list[tuple[str, Any]] = []


def pytest_configure(config: pytest.Config) -> None:
    """Disable external plugins at the start of the jac test session.

    External plugins (jac-scale, jac-client, etc.) are disabled during core jac tests
    to ensure a clean test environment without MongoDB connections or other
    plugin-specific dependencies.

    NOTE: This only applies to tests in jac/tests/, not to package-specific tests.
    """
    from jaclang.pycore.runtime import JacRuntimeImpl, plugin_manager

    global _external_plugins
    for name, plugin in list(plugin_manager.list_name_plugin()):
        if plugin is JacRuntimeImpl or name in (
            "JacRuntimeImpl",
            "JacRuntimeInterfaceImpl",
        ):
            continue
        _external_plugins.append((name, plugin))
        plugin_manager.unregister(plugin=plugin, name=name)


def pytest_unconfigure(config: pytest.Config) -> None:
    """Re-register external plugins at the end of the jac test session."""
    from jaclang.pycore.runtime import plugin_manager

    global _external_plugins
    for name, plugin in _external_plugins:
        with contextlib.suppress(ValueError):
            plugin_manager.register(plugin, name=name)
    _external_plugins.clear()


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


def proc_file(filename: str, user_root: str | None = None) -> tuple[str, str, Any]:
    """Create JacRuntime and return the base path, module name, and runtime state.

    This is a test utility for setting up Jac runtime context.
    Database path is computed from base_path via TieredMemory.

    Args:
        filename: Path to .jac or .py file
        user_root: User root ID for permission boundary (None for system context)
    """
    from jaclang.pycore.runtime import JacRuntime as Jac

    base, mod = os.path.split(filename)
    base = base or "./"
    if filename.endswith(".jac"):
        mod = mod[:-4]
    elif filename.endswith(".py"):
        mod = mod[:-3]
    else:
        raise ValueError("Not a valid file! Only supports `.jac` and `.py`")

    # Only set base path if not already set (allows tests to override via jac_temp_dir fixture)
    if not Jac.base_path_dir:
        Jac.set_base_path(base)

    # Create context - db path auto-computed from base_path
    mach = Jac.create_j_context(user_root=user_root)
    Jac.set_context(mach)
    return (base, mod, mach)


def proc_file_sess(
    filename: str, base_path: str, user_root: str | None = None
) -> tuple[str, str, Any]:
    """Create JacRuntime with explicit base_path (for isolated tests).

    This sets base_path explicitly to ensure tests use isolated storage.
    The database path is computed from base_path by TieredMemory.

    Args:
        filename: Path to .jac or .py file
        base_path: Base directory for database storage
        user_root: User root ID for permission boundary (None for system context)
    """
    from jaclang.pycore.runtime import JacRuntime as Jac

    base, mod = os.path.split(filename)
    base = base or "./"
    if filename.endswith(".jac"):
        mod = mod[:-4]
    elif filename.endswith(".py"):
        mod = mod[:-3]
    else:
        raise ValueError("Not a valid file! Only supports `.jac` and `.py`")

    # Set base path explicitly for isolated storage
    Jac.set_base_path(base_path)

    # Create context - db path auto-computed from base_path
    mach = Jac.create_j_context(user_root=user_root)
    Jac.set_context(mach)
    return (base, mod, mach)


def get_object(filename: str, id: str, main: bool = True) -> dict[str, Any]:
    """Get an object by ID from a Jac program.

    This is a test utility for inspecting object state.
    Session is auto-generated based on base_path.

    Args:
        filename: Path to the .jac file
        id: Object ID to retrieve
        main: Treat the module as __main__ (default: True)

    Returns:
        Dictionary containing the object's state
    """
    ensure_jac_runtime()
    from jaclang.pycore.runtime import JacRuntime as Jac

    base, mod, mach = proc_file(filename)
    if filename.endswith(".jac"):
        Jac.jac_import(
            target=mod, base_path=base, override_name="__main__" if main else None
        )
    else:
        mach.close()
        raise ValueError("Not a valid file! Only supports `.jac`")

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


@pytest.fixture
def fresh_jac_context(tmp_path: Path) -> Generator[Path, None, None]:
    """Provide fresh, isolated Jac context for test.

    This fixture:
    - Closes any existing execution context
    - Clears user modules from sys.modules (keeps jaclang.* to preserve dataclass refs)
    - Clears loaded modules tracking
    - Creates fresh JacProgram
    - Creates fresh execution context with isolated storage
    - Cleans up after test
    """
    from concurrent.futures import ThreadPoolExecutor

    from jaclang.pycore.program import JacProgram
    from jaclang.pycore.runtime import JacRuntime, JacRuntimeInterface

    # Close any existing context if any
    if JacRuntime.exec_ctx is not None:
        JacRuntime.exec_ctx.mem.close()

    # Remove user .jac modules from sys.modules so they get re-imported fresh
    # Keep jaclang.* and __main__ to avoid breaking dataclass references
    for mod in list(JacRuntime.loaded_modules.values()):
        if not mod.__name__.startswith("jaclang.") and mod.__name__ != "__main__":
            sys.modules.pop(mod.__name__, None)
    JacRuntime.loaded_modules.clear()

    # Set up fresh state
    JacRuntime.base_path_dir = str(tmp_path)
    JacRuntime.program = JacProgram()
    JacRuntime.pool = ThreadPoolExecutor()
    JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(user_root=None)

    yield tmp_path

    # Cleanup after test
    if JacRuntime.exec_ctx is not None:
        JacRuntime.exec_ctx.mem.close()
    for mod in list(JacRuntime.loaded_modules.values()):
        if not mod.__name__.startswith("jaclang.") and mod.__name__ != "__main__":
            sys.modules.pop(mod.__name__, None)
    JacRuntime.loaded_modules.clear()


# Flag to track if template registry has been initialized
_template_registry_initialized = False


@pytest.fixture
def cli_test_dir(tmp_path: Path) -> Generator[Path, None, None]:
    """Provide a temporary directory for CLI tests with cwd switching.

    This fixture:
    - Initializes the template registry (once per session)
    - Changes cwd to the temp directory
    - Restores cwd after the test

    Use this for tests that call CLI commands directly (e.g., project.create())
    instead of spawning subprocesses for better performance.
    """
    global _template_registry_initialized

    # Initialize template registry once
    if not _template_registry_initialized:
        from jaclang.project.template_registry import initialize_template_registry

        initialize_template_registry()
        _template_registry_initialized = True

    original_cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        yield tmp_path
    finally:
        os.chdir(original_cwd)
