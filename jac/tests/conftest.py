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
    from jaclang.jac0core.runtime import JacRuntimeImpl, plugin_manager

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
    from jaclang.jac0core.runtime import plugin_manager

    global _external_plugins
    for name, plugin in _external_plugins:
        with contextlib.suppress(ValueError):
            plugin_manager.register(plugin, name=name)
    _external_plugins.clear()
