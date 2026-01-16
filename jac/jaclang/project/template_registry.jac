"""Project template registry for plugin-provided templates.

This module provides a registry for project templates that can be
registered by plugins (e.g., client template from jac-client). The registry
allows the `jac create` command to use different project templates based on
the --template flag or plugin-specific flags like --cl.
"""

import from typing { Any, Callable }
import from pathlib { Path }

"""Represents a registered project template from a plugin.

Plugins register templates to provide different project scaffolding
options for the `jac create` command.
"""
obj ProjectTemplate {
    has name: str,  # e.g., "default", "client"
        description: str,  # e.g., "Basic Jac project"
        config: dict[str, Any],  # JacConfig-compatible dict for jac.toml
        files: dict[str, str],  # path -> content (with {{name}} placeholders)
        directories: list[str] = [],  # directories to create
        gitignore_entries: list[str] = [],  # entries for .jac/.gitignore
        root_gitignore_entries: list[str] = [],  # entries for project-root .gitignore
        post_create: Callable | None = None;  # optional callback(project_path, project_name)
}

"""Registry for plugin-provided project templates.

This is a singleton that collects all templates registered by plugins
via the register_project_template hook. The `jac create` command uses
this registry to scaffold projects based on the selected template.
"""
obj TemplateRegistry {
    has _templates: dict[str, ProjectTemplate] = {};

    """Register a new template from plugin hook data."""
    def register(template_info: dict[str, Any]) -> None;

    """Get template by name (e.g., 'default', 'client')."""
    def get(name: str) -> ProjectTemplate | None;

    """Get the default template."""
    def get_default -> ProjectTemplate;

    """List all registered templates as (name, description) tuples."""
    def list_templates -> list[tuple[str, str]];

    """Check if a template is registered."""
    def has_template(name: str) -> bool;

    """Clear all registered templates (for testing)."""
    def clear -> None;
}

# Global singleton instance
glob _registry: TemplateRegistry | None = None;

"""Get or create the global template registry."""
def get_template_registry -> TemplateRegistry;

"""Initialize the registry by registering default template and calling plugin hooks.

This should be called after plugins are loaded to collect
all registered templates from plugins.
"""
def initialize_template_registry -> None;
