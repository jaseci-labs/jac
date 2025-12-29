"""Pytest configuration and shared fixtures for jac-client tests.

This module provides session-scoped fixtures to optimize test execution by:
1. Running npm install once per session and caching node_modules
2. Providing shared Vite build infrastructure
3. Mocking npm install for tests that only need jac.toml manipulation
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Generator
from pathlib import Path
from unittest.mock import patch

import pytest

from jaclang.pycore.runtime import JacRuntime as Jac


def _get_jac_command() -> list[str]:
    """Get the jac command with proper path handling."""
    # Try to find jac in PATH or use python -m jaclang
    jac_path = shutil.which("jac")
    if jac_path:
        return [jac_path]
    # Fall back to running via python module
    return [sys.executable, "-m", "jaclang"]


def _get_env_with_npm() -> dict[str, str]:
    """Get environment dict with npm in PATH."""
    env = os.environ.copy()
    # npm might be installed via nvm, ensure PATH includes common locations
    npm_path = shutil.which("npm")
    if npm_path:
        npm_dir = str(Path(npm_path).parent)
        current_path = env.get("PATH", "")
        if npm_dir not in current_path:
            env["PATH"] = f"{npm_dir}:{current_path}"
    return env


@pytest.fixture(autouse=True)
def reset_jac_machine() -> Generator[None, None, None]:
    """Reset Jac machine before and after each test."""
    Jac.reset_machine()
    yield
    Jac.reset_machine()


# Session-scoped cache for npm installation
_npm_cache_dir: Path | None = None


def _get_minimal_jac_toml() -> str:
    """Get minimal jac.toml content for npm cache setup."""
    return """[project]
name = "npm-cache"
version = "0.0.1"
description = "Cached npm modules"
entry-point = "app.jac"

[plugins.client.vite.build]
minify = false
"""


@pytest.fixture(scope="session")
def npm_cache_dir() -> Generator[Path, None, None]:
    """Session-scoped fixture that provides a directory with npm packages installed.

    This runs npm install once per test session and provides the path to the
    .jac-client.configs directory containing node_modules.
    """
    global _npm_cache_dir

    if _npm_cache_dir is not None and _npm_cache_dir.exists():
        yield _npm_cache_dir
        return

    # Create a persistent temp directory for the session
    cache_dir = Path(tempfile.mkdtemp(prefix="jac_npm_cache_"))

    # Create jac.toml
    jac_toml = cache_dir / "jac.toml"
    jac_toml.write_text(_get_minimal_jac_toml())

    # Run jac add --cl to install packages
    jac_cmd = _get_jac_command()
    env = _get_env_with_npm()
    result = subprocess.run(
        [*jac_cmd, "add", "--cl"],
        cwd=cache_dir,
        capture_output=True,
        text=True,
        env=env,
    )

    if result.returncode != 0:
        # Clean up on failure
        shutil.rmtree(cache_dir, ignore_errors=True)
        pytest.skip(f"Failed to set up npm cache: {result.stderr}")

    _npm_cache_dir = cache_dir
    yield cache_dir

    # Cleanup after all tests complete
    shutil.rmtree(cache_dir, ignore_errors=True)


@pytest.fixture
def vite_project_dir(npm_cache_dir: Path, tmp_path: Path) -> Path:
    """Fixture that provides a project directory with pre-installed node_modules.

    This copies node_modules from the session cache instead of running npm install.
    """
    # Create jac.toml in the temp directory
    jac_toml = tmp_path / "jac.toml"
    jac_toml.write_text(_get_minimal_jac_toml())

    # Copy .jac-client.configs directory (contains package.json)
    source_configs = npm_cache_dir / ".jac-client.configs"
    dest_configs = tmp_path / ".jac-client.configs"
    if source_configs.exists():
        shutil.copytree(source_configs, dest_configs, symlinks=True)

    # Copy node_modules from project root (npm installs there, not in .jac-client.configs)
    source_node_modules = npm_cache_dir / "node_modules"
    dest_node_modules = tmp_path / "node_modules"
    if source_node_modules.exists():
        shutil.copytree(source_node_modules, dest_node_modules, symlinks=True)

    # Create required directories
    (tmp_path / "dist").mkdir(exist_ok=True)
    (tmp_path / "compiled").mkdir(exist_ok=True)
    (tmp_path / "build").mkdir(exist_ok=True)

    return tmp_path


@pytest.fixture
def vite_project_with_antd(npm_cache_dir: Path, tmp_path: Path) -> Path:
    """Fixture that provides a project directory with antd pre-installed."""
    # Create jac.toml with antd dependency
    jac_toml_content = """[project]
name = "antd-test"
version = "0.0.1"
description = "Test project with antd"
entry-point = "app.jac"

[plugins.client.vite.build]
minify = false

[dependencies.npm]
antd = "^6.0.0"
"""
    jac_toml = tmp_path / "jac.toml"
    jac_toml.write_text(jac_toml_content)

    # Copy base .jac-client.configs first for faster install
    source_configs = npm_cache_dir / ".jac-client.configs"
    dest_configs = tmp_path / ".jac-client.configs"
    if source_configs.exists():
        shutil.copytree(source_configs, dest_configs, symlinks=True)

    # Copy base node_modules for faster install (npm will add antd on top)
    source_node_modules = npm_cache_dir / "node_modules"
    dest_node_modules = tmp_path / "node_modules"
    if source_node_modules.exists():
        shutil.copytree(source_node_modules, dest_node_modules, symlinks=True)

    # Install antd on top (uses cached node_modules as base)
    jac_cmd = _get_jac_command()
    env = _get_env_with_npm()
    result = subprocess.run(
        [*jac_cmd, "add", "--cl"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        pytest.skip(f"Failed to install antd: {result.stderr}")

    # Create required directories
    (tmp_path / "dist").mkdir(exist_ok=True)
    (tmp_path / "compiled").mkdir(exist_ok=True)
    (tmp_path / "build").mkdir(exist_ok=True)

    return tmp_path


@pytest.fixture
def mock_npm_install():
    """Fixture that mocks npm install for tests that only test jac.toml manipulation.

    Use this for CLI tests (add/remove commands) that don't need actual npm packages.
    """
    with patch(
        "jac_client.plugin.src.package_installer.PackageInstaller._regenerate_and_install"
    ) as mock:
        yield mock


@pytest.fixture
def cli_test_dir(tmp_path: Path) -> Path:
    """Fixture that provides a minimal test directory for CLI tests."""
    return tmp_path


def create_test_jac_toml(
    path: Path,
    deps: str = "",
    dev_deps: str = "",
    name: str = "test-project",
) -> Path:
    """Helper to create a jac.toml file for testing.

    Args:
        path: Directory to create jac.toml in
        deps: Dependencies to add (TOML format, e.g., 'lodash = "^4.17.21"')
        dev_deps: Dev dependencies to add (TOML format)
        name: Project name

    Returns:
        Path to the created jac.toml file
    """
    deps_section = f"\n{deps}" if deps else ""
    dev_deps_section = f"\n{dev_deps}" if dev_deps else ""

    content = f"""[project]
name = "{name}"
version = "1.0.0"
description = "Test project"
entry-point = "app.jac"

[dependencies.npm]{deps_section}

[dependencies.npm.dev]{dev_deps_section}
"""
    config_path = path / "jac.toml"
    config_path.write_text(content)
    return config_path
