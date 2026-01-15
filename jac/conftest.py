"""Root conftest for jac package - applies to all tests including examples.

This conftest ensures:
1. External plugins (jac-scale, etc.) are disabled during tests
2. Each test has isolated Jac context to prevent database locking issues
"""

import contextlib
import glob
import os
from collections.abc import Generator
from pathlib import Path

import pytest

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


def _cleanup_db_files() -> None:
    """Remove database files that may be created by tests or plugins."""
    for pattern in [
        # SQLite files (WAL mode creates -wal and -shm files)
        "*.db",
        "*.db-wal",
        "*.db-shm",
        # Legacy shelf files
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
    _cleanup_db_files()
    yield
    _cleanup_db_files()


@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: Path) -> Generator[Path, None, None]:
    """Ensure each test has its own isolated Jac context.

    Each test gets a unique temp directory to prevent parallel test
    interference. Tests that call proc_file or set_base_path will
    skip setting base_path if one is already set, so this provides
    default isolation.
    """
    from jaclang.pycore.runtime import JacRuntime as Jac

    original_base_path = Jac.base_path_dir
    original_exec_ctx = Jac.exec_ctx
    # Set base_path to unique temp directory for each test
    # This ensures parallel tests don't share database files
    Jac.set_base_path(str(tmp_path))
    Jac.exec_ctx = None  # Force new context creation
    yield tmp_path
    # Restore original state
    Jac.set_base_path(original_base_path)
    Jac.exec_ctx = original_exec_ctx
