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

    kind = template_info.get("kind")
    or config.get("project", {}).get("kind", "")
    or "cli";

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

    self._templates[name] = template;
}

impl TemplateRegistry.get(name: str) -> ProjectTemplate | None {
    import from jaclang.project.template_registry { ProjectTemplate }
    return self._templates.get(name);
}

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

impl TemplateRegistry.get_default -> ProjectTemplate {
    import from jaclang.project.template_registry { ProjectTemplate }
    default_tmpl = self.get_by_kind("cli");
    if default_tmpl is None {
        raise RuntimeError("Default (cli) template not registered");
    }
    return default_tmpl;
}

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

impl TemplateRegistry.is_empty -> bool {
    return not self._templates;
}

impl TemplateRegistry.clear -> None {
    self._templates.clear();
}

impl get_template_registry -> TemplateRegistry {
    import from jaclang.project.template_registry { TemplateRegistry }
    global _registry;
    if _registry is None {
        _registry = TemplateRegistry();
    }
    return _registry;
}

impl initialize_template_registry -> None {
    registry = get_template_registry();

    _register_core_templates(registry);

    _register_builtin_client_templates(registry);

    _register_builtin_shadcn_template(registry);
}

def _register_builtin_shadcn_template(registry: TemplateRegistry) -> None {
    try {
        import from jaclang.cli.shadcn.cli { register_project_template }
    } except Exception {
        return;
    }
    results = register_project_template();
    for entry in _iter_template_dicts(results) {
        try {
            registry.register(entry);
        } except Exception as e {
            import from jaclang.cli.console { console }
            console.warning(f"Skipping invalid project template: {e}");
        }
    }
}

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

def _register_builtin_client_templates(registry: TemplateRegistry) -> None {
    try {
        import from jaclang.runtimelib.client.plugin_config { JacClientPluginConfig }
        import from jaclang.runtimelib.client.desktop_plugin_config {
            JacDesktopPluginConfig
        }
    } except Exception {
        return;
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
            "cli-native",
            "Natively-compiled Jac program (compiled and run)",
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
            "native-lib",
            "Natively-compiled shared library (.so / .dylib / .dll)",
            "main.na.jac",
            {"main.na.jac": _shared}
        ),
        _core_template(
            "service",
            "Headless Jac API service (server walkers, no client)",
            "main.sv.jac",
            {"main.sv.jac": _service}
        ),
        _core_template(
            "service-mesh",
            "Jac microservice (server walkers; auto-starts providers)",
            "main.sv.jac",
            {"main.sv.jac": _service}
        ),
        _core_template(
            "py-package",
            "Distributable Python package (built into a wheel)",
            "lib.jac",
            {"lib.jac": _lib}
        ),
        _core_template(
            "js-package",
            "Distributable npm package (built into a tarball)",
            "lib.jac",
            {"lib.jac": _lib}
        )
    ] {
        registry.register(info);
    }
}
