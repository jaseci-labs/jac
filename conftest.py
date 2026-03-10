"""Pytest configuration and shared fixtures for Jaseci tests."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: Path) -> Generator[Path, None, None]:
    """Ensure each test has its own isolated Jac context.

    Each test gets a unique temp directory to prevent parallel test
    interference. Tests that call proc_file or set_base_path will
    skip setting base_path if one is already set, so this provides
    default isolation.
    """
    from jaclang.jac0core.runtime import JacRuntime as Jac

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
    if Jac.program:
        Jac.program.errors_had.clear()
        Jac.program.warnings_had.clear()
