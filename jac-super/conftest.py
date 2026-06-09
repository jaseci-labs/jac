"""Pytest configuration for jac-super tests.

Overrides the root conftest's isolate_jac_context fixture since ink_compile
tests don't need Jac runtime isolation.
"""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: Path) -> Generator[Path, None, None]:
    """Override root conftest — ink_compile tests don't need Jac context isolation."""
    yield tmp_path
