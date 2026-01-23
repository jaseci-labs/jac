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
        packages_dir: Path | None = None,
        verbose: bool = False;

    def postinit -> None;
    def ensure_packages_dir -> None;
    def _run_pip(args: list[str]) -> tuple[int, str, str];
    def _cleanup_old_package(name: str) -> None;
    def install_all(include_dev: bool = False) -> bool;
    def install_package(name: str, version: str = "") -> bool;
    def install_git_package(name: str, git_url: str, branch: str = "") -> bool;
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

def add_packages_to_path(config: JacConfig | None = None) -> None;

def remove_packages_from_path(config: JacConfig | None = None) -> None;

def is_packages_in_path(config: JacConfig | None = None) -> bool;
