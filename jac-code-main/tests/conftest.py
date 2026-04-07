"""Pytest configuration and shared fixtures for jac-coder tests."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

# Project root (where cli.jac lives)
PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Find the jac binary — check common venv locations
JAC_BIN = shutil.which("jac") or str(
    next(
        (p for p in [
            PROJECT_ROOT.parent / "venv" / "bin" / "jac",
            PROJECT_ROOT.parent.parent / "venv" / "bin" / "jac",
            Path.home() / "programming" / "jac-apps" / "venv" / "bin" / "jac",
            Path("/home/malitha/programming/jac-apps/venv/bin/jac"),
        ] if p.exists()),
        PROJECT_ROOT.parent / "venv" / "bin" / "jac",
    )
)


def run_jac(jac_file: str, timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a .jac file from the project root and return the result."""
    return subprocess.run(
        [JAC_BIN, "run", jac_file],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=str(PROJECT_ROOT),
    )


@pytest.fixture(scope="session", autouse=True)
def clean_jac_cache():
    """Remove persisted graph state so each test session starts fresh."""
    data_dir = PROJECT_ROOT / ".jac" / "data"
    if data_dir.exists():
        shutil.rmtree(data_dir)
    yield
    # optionally clean up after too
    if data_dir.exists():
        shutil.rmtree(data_dir)


@pytest.fixture(scope="session")
def project_root():
    return PROJECT_ROOT
