"""Shared pytest fixtures for jac/tests directory."""

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
# Test Utilities
# =============================================================================


def get_object(filename: str, id: str, main: bool = True) -> dict[str, Any]:
    """Get an object by ID from a Jac program.

    This is a test utility for inspecting object state. It runs under the
    system context (no user root), so access checks always pass.

    Args:
        filename: Path to the .jac file
        id: Object ID to retrieve
        main: Treat the module as __main__ (default: True)

    Returns:
        Dictionary containing the object's state
    """
    from jaclang.cli.commands.cli_helpers import proc_file
    from jaclang.jac0core.runtime import JacRuntime as Jac

    base, mod, mach = proc_file(filename)
    try:
        Jac.jac_import(
            target=mod, base_path=base, override_name="__main__" if main else None
        )
        obj = Jac.get_object(id)
        if not obj:
            raise ValueError(f"Object with id {id} not found.")
        return obj.__jac__.__getstate__()
    finally:
        mach.close()
