"""Override the repo-root autouse fixture for pure-Python bridge tests."""

from __future__ import annotations

import pathlib
from collections.abc import Generator

import pytest


@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: pathlib.Path) -> Generator[pathlib.Path, None, None]:
    yield tmp_path
