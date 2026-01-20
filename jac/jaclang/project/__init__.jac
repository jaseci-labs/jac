"""Project configuration and management for Jac projects.

This module provides the jac.toml configuration system, including:
- JacConfig: Central configuration class for project settings
- Project discovery: Auto-detection of jac.toml in parent directories
- Dependency management: Install, add, remove dependencies
"""
import from jaclang.project { config, dependencies }
import from jaclang.project.config {
    BuildConfig,
    CacheConfig,
    CheckConfig,
    DotConfig,
    EnvironmentConfig,
    FormatConfig,
    JacConfig,
    PluginsConfig,
    ProjectConfig,
    RunConfig,
    ServeConfig,
    TestConfig,
    find_project_root,
    get_config,
    interpolate_env_vars,
    is_in_project,
    set_config
}
import from jaclang.project.dependencies {
    DependencyInstaller,
    DependencyResolver,
    ResolvedDependency,
    add_packages_to_path,
    is_packages_in_path,
    remove_packages_from_path
}
import from jaclang.project.template_registry { ProjectTemplate }
import from jaclang.project.template_loader {
    load_template_from_directory,
    load_template_from_json,
    bundle_template,
    resolve_post_create_hook
}

glob __all__ = [
         'JacConfig',
         'ProjectConfig',
         'RunConfig',
         'BuildConfig',
         'TestConfig',
         'ServeConfig',
         'FormatConfig',
         'CheckConfig',
         'DotConfig',
         'CacheConfig',
         'PluginsConfig',
         'EnvironmentConfig',
         'get_config',
         'set_config',
         'find_project_root',
         'is_in_project',
         'interpolate_env_vars',
         'DependencyInstaller',
         'DependencyResolver',
         'ResolvedDependency',
         'add_packages_to_path',
         'remove_packages_from_path',
         'is_packages_in_path',
         'ProjectTemplate',
         'load_template_from_directory',
         'load_template_from_json',
         'bundle_template',
         'resolve_post_create_hook'
     ];
