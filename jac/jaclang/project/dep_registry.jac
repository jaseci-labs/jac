"""Dependency type registry for plugin-provided package managers.

This module provides a registry for dependency types that can be
registered by plugins (e.g., npm from jac-client). The registry
allows the core CLI to delegate package installation to plugin-provided
handlers based on CLI flags like --cl.
"""

import from typing { Any, Callable }
import from pathlib { Path }

"""Represents a registered dependency type from a plugin.

Plugins register dependency types to extend jac.toml with sections like
[dependencies.npm] and provide handlers for the jac add/remove commands.
"""
obj DependencyType {
    has name: str,  # e.g., "npm"
        dev_name: str,  # e.g., "npm.dev"
        cli_flag: str,  # e.g., "--cl"
        install_dir: str,  # e.g., ".jac-client.configs"
        install_handler: Callable,  # (config, name, version, is_dev) -> None
        remove_handler: Callable,  # (config, name, is_dev) -> None
        install_all_handler: Callable | None = None;  # (config) -> None
}

"""Registry for plugin-provided dependency types.

This is a singleton that collects all dependency types registered by plugins
via the register_dependency_type hook. The core CLI uses this registry to
delegate package management to the appropriate plugin handlers.
"""
obj DependencyRegistry {
    has _types: dict[str, DependencyType] = {},
        _flag_map: dict[str, str] = {};

    """Register a new dependency type from plugin hook data."""
    def register(dep_type_info: dict[(str, Any)]) -> None;

    """Get dependency type by name (e.g., 'npm')."""
    def get_by_name(name: str) -> DependencyType | None;

    """Get dependency type by CLI flag (e.g., '--cl')."""
    def get_by_flag(flag: str) -> DependencyType | None;

    """Get all registered dependency types."""
    def get_all -> dict[str, DependencyType];

    """Get all registered CLI flags."""
    def get_all_flags -> list[str];

    """Check if a dependency type is registered."""
    def has_type(name: str) -> bool;

    """Clear all registered types (for testing)."""
    def clear -> None;
}

# Global singleton instance
glob _registry: DependencyRegistry | None = None;

"""Get or create the global dependency registry."""
def get_dependency_registry -> DependencyRegistry;

"""Initialize the registry by calling plugin hooks.

This should be called after plugins are loaded to collect
all registered dependency types from plugins.
"""
def initialize_dependency_registry -> None;
