"""Implementation of project template registry."""

import from typing { Any }

# ===============================================================================
# ProjectTemplate Implementation
# ===============================================================================
"""Convert to dict for serialization (e.g., JSON bundling)."""
impl ProjectTemplate.to_dict -> dict[str, Any] {
    return {
        "name": self.name,
        "description": self.description,
        "config": self.config,
        "files": self.files,
        "directories": self.directories,
        "root_gitignore_entries": self.root_gitignore_entries
    };
}

# ===============================================================================
# TemplateRegistry Implementation
# ===============================================================================
"""Register a new template from plugin hook data."""
impl TemplateRegistry.register(template_info: dict[str, Any]) -> None {
    import from jaclang.project.template_registry { ProjectTemplate }
    name = template_info.get("name");
    if not name {
        raise ValueError("Template must have a 'name' field") ;
    }
    description = template_info.get("description", "");
    if not description {
        raise ValueError(f"Template '{name}' must have a 'description' field") ;
    }
    config = template_info.get("config");
    if not config {
        raise ValueError(f"Template '{name}' must have a 'config' field") ;
    }
    # Create ProjectTemplate from the dict
    template = ProjectTemplate(
        name=name,
        description=description,
        config=config,
        files=template_info.get("files", {}),
        directories=template_info.get("directories", []),
        root_gitignore_entries=template_info.get("root_gitignore_entries", []),
        post_create=template_info.get("post_create")
    );
    # Register the template
    self._templates[name] = template;
}

"""Get template by name (e.g., 'default', 'client')."""
impl TemplateRegistry.get(name: str) -> ProjectTemplate | None {
    import from jaclang.project.template_registry { ProjectTemplate }
    return self._templates.get(name);
}

"""Get the default template."""
impl TemplateRegistry.get_default -> ProjectTemplate {
    import from jaclang.project.template_registry { ProjectTemplate }
    default_tmpl = self._templates.get("default");
    if default_tmpl is None {
        raise RuntimeError("Default template not registered") ;
    }
    return default_tmpl;
}

"""List all registered templates as (name, description) tuples."""
impl TemplateRegistry.list_templates -> list[tuple[str, str]] {
    result: list[tuple[str, str]] = [];
    # Put "default" first if it exists
    if "default" in self._templates {
        result.append(("default", self._templates["default"].description));
    }
    # Add other templates sorted by name
    for name in sorted(self._templates.keys()) {
        if name != "default" {
            result.append((name, self._templates[name].description));
        }
    }
    return result;
}

"""Check if a template is registered."""
impl TemplateRegistry.has_template(name: str) -> bool {
    return name in self._templates;
}

"""Clear all registered templates (for testing)."""
impl TemplateRegistry.clear -> None {
    self._templates.clear();
}

# ===============================================================================
# Module-level Functions Implementation
# ===============================================================================
"""Get or create the global template registry."""
impl get_template_registry -> TemplateRegistry {
    import from jaclang.project.template_registry { TemplateRegistry }
    global _registry;
    if _registry is None {
        _registry = TemplateRegistry();
    }
    return _registry;
}

"""Initialize the registry by registering default template and calling plugin hooks."""
impl initialize_template_registry -> None {
    import from jaclang.pycore.runtime { JacRuntime }
    registry = get_template_registry();
    # Register the default template first
    _register_default_template(registry);
    # Call the hook - may return a single dict or list of dicts
    results = JacRuntime.register_project_template();
    if results is None {
        return;
    }
    # Handle both single result (dict) and multiple results (list)
    if isinstance(results, dict) {
        # Single plugin returned a dict
        registry.register(results);
    } elif isinstance(results, list) {
        # Multiple plugins, each returning a dict
        for result in results {
            if result and isinstance(result, dict) {
                registry.register(result);
            }
        }
    }
}

"""Register the default Jac project template."""
def _register_default_template(registry: TemplateRegistry) -> None {
    registry.register(
        {
            "name": "default",
            "description": "Basic Jac project",
            "config": {
                "project": {
                    "name": "{{name}}",
                    "version": "0.1.0",
                    "description": "A Jac project",
                    "entry-point": "main.jac"
                },
                "dependencies": {},
                "dev-dependencies": {"watchdog": ">=3.0.0"}
            },
            "files": {
                "main.jac": '"""Main entry point for {{name}}."""\n\nwith entry {\n    print("Hello from {{name}}!");\n}\n'
            },
            "root_gitignore_entries": [".jac/", "jac.local.toml"],
            "directories": [".jac"],

        }
    );
}
# ===============================================================================
# Default Template
# ===============================================================================
