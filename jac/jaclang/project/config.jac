"""Jac project configuration module.

This module provides the JacConfig class and related types for managing
project configuration from jac.toml files.
"""

import os;
import re;
import sys;
import tomllib;
import from pathlib { Path }
import from typing { Any }

"""Project metadata from [project] section."""
obj ProjectConfig {
    has name: str = "",
        version: str = "0.1.0",
        description: str = "",
        authors: list[str] = [],
        license: str = "",
        readme: str = "README.md",
        jac_version: str = "",
        entry_point: str = "main.jac",
        urls: dict[str, str] = {};
}

"""Run command defaults from [run] section."""
obj RunConfig {
    has session: str = "",
        main: bool = True,
        cache: bool = True;
}

"""Build command defaults and artifact directories from [build] section."""
obj BuildConfig {
    has typecheck: bool = False,
        dir: str = ".jac";  # Base directory for all build artifacts
}

"""Test command defaults from [test] section."""
obj TestConfig {
    has directory: str = "",
        filter: str = "",
        verbose: bool = False,
        fail_fast: bool = False,
        max_failures: int = 0;
}

"""Serve command defaults from [serve] section."""
obj ServeConfig {
    has port: int = 8000,
        session: str = "",
        main: bool = True,
        cl_route_prefix: str = "cl",
        base_route_app: str = "";
}

"""Format command defaults from [format] section."""
obj FormatConfig {
    has outfile: str = "",
        fix: bool = False;
}

"""Check command defaults from [check] section."""
obj CheckConfig {
    has print_errs: bool = True,
        warnonly: bool = False;
}

"""Dot/graph visualization defaults from [dot] section."""
obj DotConfig {
    has depth: int = -1,
        traverse: bool = False,
        bfs: bool = False,
        edge_limit: int = 512,
        node_limit: int = 512,
        format: str = "dot";
}

"""Cache settings from [cache] section."""
obj CacheConfig {
    has enabled: bool = True,
        dir: str = ".jac_cache";
}

"""Plugin settings from [plugins] section."""
obj PluginsConfig {
    has discovery: str = "auto",
        enabled: list[str] = [],
        disabled: list[str] = [];  # Plugins temporarily bypassed by user
}

"""Environment configuration from [environment] section."""
obj EnvironmentConfig {
    has default_profile: str = "";
}

# Interpolate environment variables in a string value.
# Supports ${VAR_NAME}, ${VAR_NAME:-default}, ${VAR_NAME:?error message}
def interpolate_env_vars(
    value: str
) -> str;

# Find project root by looking for jac.toml.
def find_project_root(
    start: Path | None = None
) -> tuple[Path, Path] | None;

# Check if currently in a Jac project.
def is_in_project -> bool;

"""Central configuration class for Jac projects.

This class manages all configuration from jac.toml files, including:
- Project metadata
- Dependencies (Python/Jac, git, npm)
- Command defaults (run, build, test, etc.)
- Plugin configuration
- Environment profiles
"""
obj JacConfig {
    has project: ProjectConfig = ProjectConfig(),
        run: RunConfig = RunConfig(),
        build: BuildConfig = BuildConfig(),
        test: TestConfig = TestConfig(),
        serve: ServeConfig = ServeConfig(),
        format: FormatConfig = FormatConfig(),
        check: CheckConfig = CheckConfig(),
        dot: DotConfig = DotConfig(),
        cache: CacheConfig = CacheConfig(),
        plugins_config: PluginsConfig = PluginsConfig(),
        environment: EnvironmentConfig = EnvironmentConfig(),
        # Dependencies
        dependencies: dict[str, str] = {},
        dev_dependencies: dict[str, str] = {},
        git_dependencies: dict[str, dict[str, str]] = {},
        plugin_dependencies: dict[str, dict[str, Any]] = {},
        scripts: dict[str, str] = {},
        plugins: dict[str, dict[str, Any]] = {},
        environments: dict[str, dict[str, Any]] = {},
        project_root: Path | None = None,
        toml_path: Path | None = None,
        _raw_data: dict[str, Any] = {};

    static def discover(start_path: Path | None = None) -> JacConfig | None;
    static def load(toml_path: Path) -> JacConfig;
    static def from_toml_str(toml_str: str, toml_path: Path | None = None) -> JacConfig;
    def apply_env_interpolation -> None;
    def apply_cli_overrides(args: dict[(str, Any)]) -> None;
    def apply_profile(profile_name: str) -> None;
    def get_plugin_deps(dep_type: str) -> dict[str, Any];
    def get_plugin_config(plugin_name: str) -> dict[str, Any];
    def get_build_dir -> Path;
    def get_cache_dir -> Path;
    def get_packages_dir -> Path;
    def get_data_dir -> Path;
    def get_client_dir -> Path;
    def is_valid -> bool;
    def save -> None;
    def add_dependency(
        name: str, version: str, dev: bool = False, dep_type: str = "python"
    ) -> None;

    def remove_dependency(
        name: str, dev: bool = False, dep_type: str = "python"
    ) -> bool;
}

# Parse TOML data into JacConfig object
def _parse_toml_data(
    data: dict[str, Any], toml_path: Path | None = None
) -> JacConfig;

# Recursively apply environment variable interpolation
def _interpolate_recursive(
    obj: Any
) -> Any;

glob _config: JacConfig | None = None;

# Get the global configuration, discovering it if necessary
def get_config(
    force_discover: bool = False
) -> JacConfig | None;

# Set the global configuration
def set_config(config: JacConfig) -> None;
