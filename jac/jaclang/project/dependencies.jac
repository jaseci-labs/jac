"""Dependency management for Jac projects.

This module handles installation, removal, and resolution of dependencies
for Jac projects, including Python/Jac packages, git dependencies, and
plugin-provided dependency types (npm, etc.).
"""

import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }

"""Represents a resolved dependency with version info."""
obj ResolvedDependency {
    has name: str,
        version: str,
        source: str = "pypi",
        extras: list[str] = [],
        dependencies: list[str] = [];
}

"""Manages installation of dependencies for Jac projects."""
obj DependencyInstaller {
    has config: JacConfig | None = None,
        venv_dir: Path | None = None,
        verbose: bool = False;

    def postinit -> None;
    def ensure_venv -> None;
    def _run_pip(args: list[str]) -> tuple[int, str, str];
    def _make_pip_spec(name: str, version: str) -> str;
    def _make_git_spec(name: str, git_url: str, branch: str = "") -> str;
    def get_pip_package_specs(include_dev: bool = False) -> list[str];
    def get_git_package_specs -> list[str];
    def install_package(specs: list[str]) -> bool;
    def uninstall_package(name: str) -> bool;
    def is_installed(name: str) -> bool;
    def list_installed -> list[str];
}

"""Resolves dependencies and their transitive dependencies."""
obj DependencyResolver {
    has config: JacConfig | None = None;

    def postinit -> None;
    def parse_spec(spec: str) -> tuple[str, str];
    def resolve(include_dev: bool = False) -> list[ResolvedDependency];
}

def get_venv_site_packages(venv_dir: Path) -> Path;

def add_venv_to_path(config: JacConfig | None = None) -> None;

def remove_venv_from_path(config: JacConfig | None = None) -> None;

def is_venv_in_path(config: JacConfig | None = None) -> bool;
