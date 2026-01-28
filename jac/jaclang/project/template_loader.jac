"""Template loader for file-based project templates.

This module provides functions to:
- Load templates from a directory with a jac.toml containing [jacpack] section
- Bundle a template directory into a single JSON file for distribution
- Load templates from bundled JSON files

Templates are defined using a single jac.toml file. To make a project packable
as a template, add a [jacpack] section with name and description fields.
All other sections (project, plugins, dependencies, etc.) become the config
for created projects.
"""

import from typing { Any, Callable }
import from pathlib { Path }
import from jaclang.project.template_registry { ProjectTemplate }

"""Load a template from a directory containing jac.toml with [jacpack] section.

The jac.toml should have:
- [jacpack]: Metadata with name, description, jaclang version, plugins
- [jacpack.options]: directories, files patterns, gitignore entries
- All other sections: Become the created project's jac.toml config

Returns a strongly-typed ProjectTemplate object.
"""
def load_template_from_directory(
    template_dir: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

"""Bundle a template directory into a single JSON file.

Reads all files in the template directory and embeds their content
in a JSON file for easy distribution.

Args:
    template_dir: Path to the template directory with jac.toml
    output_path: Path for the output .jacpack file (e.g., fullstack.jacpack)
"""
def bundle_template(template_dir: Path, output_path: Path) -> None;

"""Load a template from a bundled JSON file.

The JSON file should contain all template metadata and file contents
as produced by bundle_template().

Returns a strongly-typed ProjectTemplate object.
"""
def load_template_from_json(
    json_path: Path, post_create_hook: Callable | None = None
) -> ProjectTemplate;

"""Resolve a post_create hook from a string like 'module.path:function_name'.

Used when loading templates from JSON where the hook is specified as a string.
"""
def resolve_post_create_hook(hook_path: str) -> Callable | None;
