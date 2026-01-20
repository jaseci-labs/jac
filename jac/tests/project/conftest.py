"""Pytest fixtures for project module tests."""

from __future__ import annotations

import os
import shutil
import tempfile
from collections.abc import Callable, Generator
from pathlib import Path

import pytest


@pytest.fixture
def temp_dir() -> Generator[Path, None, None]:
    """Create a temporary directory for tests."""
    tmp = tempfile.mkdtemp(prefix="jac_test_")
    yield Path(tmp)
    shutil.rmtree(tmp, ignore_errors=True)


@pytest.fixture
def temp_project(temp_dir: Path) -> Generator[Path, None, None]:
    """Create a temporary project directory with jac.toml."""
    project_dir = temp_dir / "test_project"
    project_dir.mkdir()

    # Create a minimal jac.toml
    jac_toml = project_dir / "jac.toml"
    jac_toml.write_text("""[project]
name = "test-project"
version = "0.1.0"
description = "A test project"
entry-point = "main.jac"

[dependencies]
requests = ">=2.28.0"

[dev-dependencies]
pytest = ">=8.0.0"

[run]
main = true
cache = true

[scripts]
test = "jac test"
""")

    # Create src directory with main.jac
    src_dir = project_dir / "src"
    src_dir.mkdir()
    main_jac = src_dir / "main.jac"
    main_jac.write_text('''"""Test main file."""

with entry {
    print("Hello, World!");
}
''')

    yield project_dir


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
    """Return absolute path to a fixture file."""
    base_dir = Path(__file__).parent / "fixtures"

    def _get_path(filename: str) -> str:
        path = base_dir / filename
        if not path.exists():
            raise FileNotFoundError(f"Fixture not found: {path}")
        return str(path)

    return _get_path


@pytest.fixture
def env_vars() -> Generator[dict[str, str], None, None]:
    """Set and restore environment variables."""
    original_env = os.environ.copy()
    test_vars: dict[str, str] = {}

    def set_var(name: str, value: str) -> None:
        test_vars[name] = value
        os.environ[name] = value

    yield test_vars

    # Restore original environment
    for key in test_vars:
        if key in original_env:
            os.environ[key] = original_env[key]
        else:
            os.environ.pop(key, None)


@pytest.fixture(autouse=True)
def reset_config() -> Generator[None, None, None]:
    """Reset the global config singleton between tests."""
    from jaclang.project import config

    config._config = None
    yield
    config._config = None
