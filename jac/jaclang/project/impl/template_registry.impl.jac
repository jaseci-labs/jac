"""Implementation of project template registry."""

# ===============================================================================
# ProjectTemplate Implementation
# ===============================================================================
"""Convert to dict for serialization (e.g., JSON bundling)."""
impl ProjectTemplate.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "description": self.description,
        "kind": self.kind,
        "is_default_for_kind": self.is_default_for_kind,
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
impl TemplateRegistry.register(template_info: dict[str, any]) -> None {
    import from jaclang.project.template_registry { ProjectTemplate }
    name = template_info.get("name");
    if not name {
        raise ValueError("Template must have a 'name' field");
    }
    description = template_info.get("description", "");
    if not description {
        raise ValueError(f"Template '{name}' must have a 'description' field");
    }
    config = template_info.get("config");
    if not config {
        raise ValueError(f"Template '{name}' must have a 'config' field");
    }
    # The kind is taken from the template_info, else from the template's own
    # [project] kind, else defaults to "cli" -- so a directory template only
    # has to declare `kind` once (in its jac.toml).
    kind = template_info.get("kind")
    or config.get("project", {}).get("kind", "")
    or "cli";
    # Create ProjectTemplate from the dict
    template = ProjectTemplate(
        name=name,
        description=description,
        kind=kind,
        is_default_for_kind=template_info.get("is_default_for_kind", True),
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

"""Get the canonical (default) template registered for a project kind.

Returns the template flagged `is_default_for_kind` for `kind`; if none is so
flagged (e.g. only variants exist) falls back to any template of that kind.
Returns None when no template is registered for the kind (e.g. the kind's
plugin is not installed).
"""
impl TemplateRegistry.get_by_kind(kind: str) -> ProjectTemplate | None {
    fallback: ProjectTemplate | None = None;
    for template in self._templates.values() {
        if template.kind == kind {
            if template.is_default_for_kind {
                return template;
            }
            if fallback is None {
                fallback = template;
            }
        }
    }
    return fallback;
}

"""Get the default template (the canonical `cli`-kind template)."""
impl TemplateRegistry.get_default -> ProjectTemplate {
    import from jaclang.project.template_registry { ProjectTemplate }
    default_tmpl = self.get_by_kind("cli");
    if default_tmpl is None {
        raise RuntimeError("Default (cli) template not registered");
    }
    return default_tmpl;
}

"""List all registered templates as (name, description) tuples.

The canonical `cli` template is listed first (it is the default `jac create`),
then the remaining templates sorted by name.
"""
impl TemplateRegistry.list_templates -> list[tuple[str, str]] {
    result: list[tuple[str, str]] = [];
    if "cli" in self._templates {
        result.append(("cli", self._templates["cli"].description));
    }
    for name in sorted(self._templates.keys()) {
        if name != "cli" {
            result.append((name, self._templates[name].description));
        }
    }
    return result;
}

"""List the registered project kinds as (kind, description) tuples.

Ordered by the canonical KIND_SPECS order. Only kinds with a registered
template appear (so plugin kinds show up only when the plugin is installed).
"""
impl TemplateRegistry.list_kinds -> list[tuple[str, str]] {
    import from jaclang.project.kinds { VALID_KINDS }
    by_kind: dict[str, str] = {};
    for template in self._templates.values() {
        if template.is_default_for_kind and template.kind not in by_kind {
            by_kind[template.kind] = template.description;
        }
    }
    result: list[tuple[str, str]] = [];
    for kind in VALID_KINDS {
        if kind in by_kind {
            result.append((kind, by_kind[kind]));
        }
    }
    return result;
}

"""Check if a template is registered."""
impl TemplateRegistry.has_template(name: str) -> bool {
    return name in self._templates;
}

"""True when no templates have been registered yet (registry not initialized)."""
impl TemplateRegistry.is_empty -> bool {
    return not self._templates;
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
    import from jaclang.jac0core.runtime { JacRuntime }
    registry = get_template_registry();
    # Register the core (plugin-free) kind templates first.
    _register_core_templates(registry);
    # Register the built-in client/desktop directory templates directly (they ship
    # in core now). Done here -- not via the `register_project_template` hook -- so
    # they are present whenever the registry is initialized, independent of plugin-
    # manager state (the pytest harness resets it between runs, which would otherwise
    # drop these from the aggregating hook).
    _register_builtin_client_templates(registry);
    # `register_project_template` is an aggregating hook: every plugin that
    # implements it contributes. The call returns a list with one entry per
    # implementing plugin, where each entry is itself a template dict OR a list
    # of template dicts (a plugin may provide several kinds). Flatten and
    # register all of them.
    results = JacRuntime.register_project_template();
    for entry in _iter_template_dicts(results) {
        try {
            registry.register(entry);
        } except Exception as e {
            import from jaclang.cli.console { console }
            console.warning(f"Skipping invalid project template: {e}");
        }
    }
}

"""Flatten the aggregated `register_project_template` hook result into template
dicts, accepting a dict, a list of dicts, or a list of those (firstresult-off)."""
def _iter_template_dicts(results: any) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    if results is None {
        return out;
    }
    if isinstance(results, dict) {
        out.append(results);
    } elif isinstance(results, list) {
        for item in results {
            out.extend(_iter_template_dicts(item));
        }
    }
    return out;
}

"""Register the built-in client/desktop directory templates (fullstack/client/mobile/
desktop), which ship in core. Called directly so they do not depend on plugin-hook
dispatch surviving a JacRuntime reset (e.g. the pytest harness between tests)."""
def _register_builtin_client_templates(registry: TemplateRegistry) -> None {
    try {
        import from jaclang.runtimelib.client.plugin_config { JacClientPluginConfig }
        import from jaclang.runtimelib.client.desktop_plugin_config {
            JacDesktopPluginConfig
        }
    } except Exception {
        return;  # client framework unavailable -- core remains usable
    }
    entries: list[any] = list(JacClientPluginConfig.client_project_templates());
    desktop = JacDesktopPluginConfig.desktop_project_template();
    if desktop is not None {
        entries.append(desktop);
    }
    for entry in _iter_template_dicts(entries) {
        try {
            registry.register(entry);
        } except Exception as e {
            import from jaclang.cli.console { console }
            console.warning(f"Skipping invalid client template: {e}");
        }
    }
}

"""Build a core (plugin-free) project-template dict for a kind.

Centralizes the shared scaffolding shape (project metadata, dev watchdog dep,
gitignore, .jac dir) so each kind only declares what differs: its description,
entry-point, and starter files. The kind is stamped into `[project] kind` so
the scaffolded project's bare `jac run` dispatches deterministically.
"""
def _core_template(
    kind: str,
    description: str,
    entry_file: str,
    files: dict[str, str],
    extra_config: dict[str, any] = {}
) -> dict[str, any] {
    project_section: dict[str, any] = {
        "name": "{{name}}",
        "version": "0.1.0",
        "description": description,
        "entry-point": entry_file,
        "kind": kind
    };
    config: dict[str, any] = {
        "project": project_section,
        "dependencies": {},
        "dev-dependencies": {"watchdog": ">=3.0.0"}
    };
    for (k, v) in extra_config.items() {
        config[k] = v;
    }
    return {
        "name": kind,
        "description": description,
        "kind": kind,
        "is_default_for_kind": True,
        "config": config,
        "files": files,
        "root_gitignore_entries": [".jac/", "jac.local.toml"],
        "directories": [".jac"]
    };
}

"""Register the core, plugin-free project-kind templates.

One canonical template per core kind (cli, native-app, native-binary,
shared-library, api-service, microservices, pypi-package, npm-package). The
plugin kinds (fullstack/wasm/mobile via jac-client, desktop via jac-desktop)
are contributed through the `register_project_template` hook.
"""
def _register_core_templates(registry: TemplateRegistry) {
    _hello = '"""Entry point for {{name}}."""\n\nwith entry {\n    print("Hello from {{name}}!");\n}\n';
    _lib = '"""Library module for {{name}}."""\n\ndef greet(name: str) -> str {\n    return f"Hello, {name}!";\n}\n';
    _shared = '"""Shared library for {{name}} (exported C-ABI functions)."""\n\ndef add(a: int, b: int) -> int {\n    return a + b;\n}\n';
    _service = (
        '"""API service for {{name}}.\n\n'
        'A minimal guestbook: messages are `Message` nodes on the shared `root`\n'
        'graph. The `:pub` walkers are the HTTP API the service exposes.\n'
        '"""\n\n'
        'node Message {\n    has author: str,\n        text: str;\n}\n\n'
        'walker:pub PostMessage {\n'
        '    """Append a message and report the created node."""\n'
        '    has author: str,\n        text: str,\n        reports: list[Message] = [];\n\n'
        '    can post with `root entry {\n'
        '        report here ++> Message(author=self.author, text=self.text);\n'
        '    }\n}\n\n'
        'walker:pub ListMessages {\n'
        '    """Report every message in the guestbook."""\n'
        '    has reports: list[Message] = [];\n\n'
        '    can collect with `root entry {\n        visit [-->];\n    }\n\n'
        '    can gather with Message entry {\n        report here;\n    }\n}\n'
    );

    for info in [
        _core_template(
            "cli", "Command-line Jac project", "main.jac", {"main.jac": _hello}
        ),
        _core_template(
            "native-app",
            "Natively-compiled Jac app (runs via the LLVM JIT)",
            "main.na.jac",
            {"main.na.jac": _hello}
        ),
        _core_template(
            "native-binary",
            "Natively-compiled standalone binary (built into dist/)",
            "main.na.jac",
            {"main.na.jac": _hello}
        ),
        _core_template(
            "shared-library",
            "Natively-compiled shared library (.so / .dylib / .dll)",
            "main.na.jac",
            {"main.na.jac": _shared}
        ),
        _core_template(
            "api-service",
            "Headless Jac API service (server walkers, no client)",
            "main.sv.jac",
            {"main.sv.jac": _service}
        ),
        _core_template(
            "microservices",
            "Jac microservice (server walkers; auto-starts providers)",
            "main.sv.jac",
            {"main.sv.jac": _service}
        ),
        _core_template(
            "pypi-package",
            "Distributable Python package (built into a wheel)",
            "lib.jac",
            {"lib.jac": _lib}
        ),
        _core_template(
            "npm-package",
            "Distributable npm package (built into a tarball)",
            "lib.jac",
            {"lib.jac": _lib}
        )
    ] {
        registry.register(info);
    }
}
# ===============================================================================
# Default Template
# ===============================================================================
