"""JacConfig and related types for jac.toml project configuration."""

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

"""Author or maintainer contact info for [package] section."""
obj PersonConfig {
    has name: str = "",
        email: str = "";
}

"""File inclusion rules from [package.include]."""
obj PackageIncludeConfig {
    has packages: list[str] = [],
        data: dict[str, list[str]] = {};
}

"""PyPI-publishable package metadata from [package] section."""
obj PackageConfig {
    has name: str = "",
        version: str = "",
        description: str = "",
        authors: list[PersonConfig] = [],
        maintainers: list[PersonConfig] = [],
        license: str = "",
        readme: str = "README.md",
        keywords: list[str] = [],
        requires_python: str = "",
        urls: dict[str, str] = {},
        include: PackageIncludeConfig = PackageIncludeConfig();
}

"""Run command defaults from [run] section."""
obj RunConfig {
    has session: str = "",
        main: bool = True,
        cache: bool = True,
        autonative: bool = False,
        topology_index: bool = True,
        diagnostics: str = "error";  # "error" | "all" | "none"
}

"""Native compilation settings from [build.native] section."""
obj NativeBuildConfig {
    has opt_level: int = 2,  # LLVM optimization level (0-3)
        dump_ir: str = "";  # Path to dump optimized IR (empty = disabled)
}

"""Build command defaults and artifact directories from [build] section."""
obj BuildConfig {
    has typecheck: bool = False,
        dir: str = ".jac",  # Base directory for all build artifacts
        native: NativeBuildConfig = NativeBuildConfig();
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
    has outfile: str = "";
}

"""Lint rule configuration from [check.lint] section.

Rules use a select/ignore/exclude model:
- select: list of rule names to enable
  - "default": code-transforming rules only
  - "all": every rule including warning-only rules
  - individual rule names or W3xxx codes can be listed explicitly
- ignore: list of rule names to skip even if selected
- exclude: list of glob patterns for files to skip linting entirely

Rule names are kebab-case (e.g. "no-print", "combine-has") or
diagnostic codes (e.g. "W3001", "E3012"). See LINT_ALIASES in
diagnostics.jac for the full mapping.
"""
obj LintConfig {
    has select: list[str] = ["default"],
        ignore: list[str] = [],
        exclude: list[str] = [];
}

"""Check command defaults from [check] section."""
obj CheckConfig {
    has print_errs: bool = True,
        lint: LintConfig = LintConfig(),
        suppress: list[str] = [],
        suppress_categories: list[str] = [];
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

"""Storage settings from [storage] section."""
obj StorageConfig {
    has storage_type: str = "local",  # local, s3, gcs, azure
        base_path: str = "./storage",
        create_dirs: bool = True;
}

"""Environment configuration from [environment] section."""
obj EnvironmentConfig {
    has default_profile: str = "";
}

"""Client error reporting settings from [client_errors] section.

Tunes the behavior of the /cl/__error__ endpoint and the source-mapped
stack traces it logs.
"""
obj ClientErrorsConfig {
    # When False (default), source-mapped stack frames whose resolved file is
    # a build artifact (a `.js` under `.jac/`) are dropped from the log; the
    # frames are auto-generated and not user-actionable. Set True to keep
    # them, e.g. when diagnosing a broken or stale per-file source map.
    has verbose: bool = False;
}

# Interpolate environment variables in a string value.
# Supports ${VAR_NAME}, ${VAR_NAME:-default}, ${VAR_NAME:?error message}
def interpolate_env_vars(value: str) -> str;

# Find project root by looking for jac.toml.
def find_project_root(start: Path | None = None) -> tuple[Path, Path] | None;

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
        storage: StorageConfig = StorageConfig(),
        plugins_config: PluginsConfig = PluginsConfig(),
        environment: EnvironmentConfig = EnvironmentConfig(),
        client_errors: ClientErrorsConfig = ClientErrorsConfig(),
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
        config_files: list[Path] | None = None,
        active_profile: str = "",
        _raw_data: dict[str, Any] = {},
        # Publishing fields — populated when [package], [entrypoints],
        # or [optional-dependencies] are present in jac.toml.
        package: PackageConfig | None = None,
        entrypoints: dict[str, dict[str, str]] = {},
        optional_dependencies: dict[str, dict[str, str]] = {};

    static def discover(
        start_path: Path | None = None, profile: str | None = None
    ) -> JacConfig | None;

    static def load(toml_path: Path) -> JacConfig;
    static def from_toml_str(
        toml_str: str, toml_path: Path | None = None
    ) -> JacConfig;

    def apply_env_interpolation -> None;
    def apply_cli_overrides(args: dict[(str, Any)]) -> None;
    def apply_profile(profile_name: str, _visited: set | None = None) -> None;
    def apply_profile_overlay(profile_name: str | None = None) -> None;
    def get_plugin_deps(dep_type: str) -> dict[str, Any];
    def get_plugin_config(plugin_name: str) -> dict[str, Any];
    def get_build_dir -> Path;
    def get_cache_dir -> Path;
    def get_venv_dir -> Path;
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

    def merge_from_toml_file(toml_path: Path) -> None;
}

# Discover config files for a project in load order.
# Returns list of paths: [jac.toml, jac.<profile>.toml?, jac.local.toml?]
def discover_config_files(
    project_root: Path, profile: str | None = None
) -> list[Path];

# Parse TOML data into JacConfig object
def _parse_toml_data(data: dict[str, Any], toml_path: Path | None = None) -> JacConfig;

# Recursively apply environment variable interpolation
def _interpolate_recursive(`obj: Any) -> Any;

glob _config: JacConfig | None = None;

# Get the global configuration, discovering it if necessary.
# If start_path is provided, config will be discovered from that path
# instead of the current working directory.
def get_config(
    start_path: Path | None = None, force_discover: bool = False
) -> JacConfig | None;

# Set the global configuration
def set_config(config: JacConfig) -> None;
