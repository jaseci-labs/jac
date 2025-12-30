"""Pytest configuration for jac-scale tests."""

import contextlib
import glob
from pathlib import Path

import pytest


def _remove_anchor_store_files() -> None:
    """Remove anchor_store.db files created by ShelfDB."""
    for pattern in [
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir",
    ]:
        for file in glob.glob(pattern):
            with contextlib.suppress(Exception):
                Path(file).unlink()


def pytest_sessionstart(session: pytest.Session) -> None:
    """Clean up anchor_store.db files at the start of the test session."""
    _remove_anchor_store_files()


def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    """Clean up anchor_store.db files at the end of the test session."""
    _remove_anchor_store_files()
