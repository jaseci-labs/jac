"""Editable installer for Jac projects.

This module provides functionality to install Jac projects in editable mode.
It reads jac.toml configuration and performs:
- Installation of Python dependencies into the project venv
- Making the project importable via a .pth file in site-packages
- Registering Jac plugin entry points via a .dist-info directory
"""

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
    def _create_pth_file(site_packages: Path) -> None;
    def _create_dist_info(site_packages: Path) -> None;
}

"""Check if a package is installed in the current environment."""
def is_package_installed(name: str) -> bool;
