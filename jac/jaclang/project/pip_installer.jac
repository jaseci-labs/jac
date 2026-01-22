"""Pip-style editable installer for Jac projects.

This module provides functionality to install Jac projects in editable mode,
similar to 'pip install -e .'. It reads jac.toml configuration and performs:
- Installation of Python dependencies
- Registration of package entry points
- Setting up editable install via .pth files or pip editable
"""

import subprocess;
import sys;
import from pathlib { Path }
import from typing { Any, TYPE_CHECKING }

with entry {
    if TYPE_CHECKING {
        import from jaclang.project.config { JacConfig }
    }
}

obj JacPipInstaller {
    has config: "JacConfig",
        project_path: Path,
        verbose: bool = False;

    def postinit -> None;
    def install_editable(
        deps: bool = True, include_dev: bool = False, extras: list[str] = []
    ) -> bool;

    def _setup_editable_install -> bool;
}

"""Generate a minimal pyproject.toml from jac.toml for pip editable install."""
def generate_pyproject_from_jac_toml(config: "JacConfig") -> str;

"""Check if a package is installed in the current environment."""
def is_package_installed(name: str) -> bool;
