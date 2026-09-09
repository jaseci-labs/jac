import from pathlib { Path }


class JacClientPluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "client",
            "version": "1.0.0",
            "description": "Jac client-side rendering with Vite bundling"
        };
    }

    static def get_config_schema -> dict[str, any] {
        return {
            "section": "client",
            "options": {
                "vite": {
                    "type": "dict",
                    "default": {},
                    "description": "Vite bundler configuration",
                    "nested": {
                        "plugins": {
                            "type": "list",
                            "default": [],
                            "description": "Vite plugins to include"
                        },
                        "lib_imports": {
                            "type": "list",
                            "default": [],
                            "description": "Library imports for vite.config.js"
                        },
                        "build": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite build options"
                        },
                        "server": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite dev server options"
                        },
                        "resolve": {
                            "type": "dict",
                            "default": {},
                            "description": "Vite resolve options"
                        }
                    }
                },
                "ts": {
                    "type": "dict",
                    "default": {},
                    "description": "TypeScript configuration overrides"
                },
                "configs": {
                    "type": "dict",
                    "default": {},
                    "description": "Generate config files for npm packages. Keys are config names (e.g., 'postcss', 'tailwind'), values are the config objects to export."
                },
                "npm": {
                    "type": "dict",
                    "default": {},
                    "description": "NPM registry configuration for .npmrc generation. Supports 'settings' for global options, 'scoped_registries' for scope-to-registry mappings, and 'auth' for registry authentication tokens.",
                    "nested": {
                        "settings": {
                            "type": "dict",
                            "default": {},
                            "description": "Global .npmrc settings as key-value pairs (e.g., registry, always-auth, strict-ssl, proxy)"
                        },
                        "scoped_registries": {
                            "type": "dict",
                            "default": {},
                            "description": "Map npm scopes to custom registries (e.g., '@myorg' = 'https://npm.pkg.github.com')"
                        },
                        "auth": {
                            "type": "dict",
                            "default": {},
                            "description": "Registry authentication tokens (e.g., '//npm.pkg.github.com/' = { _authToken = '${NODE_AUTH_TOKEN}' })"
                        }
                    }
                }
            }
        };
    }

    static def register_ecosystem_providers -> list {
        import from jaclang.client.npm_provider { NpmProvider }
        return [NpmProvider()];
    }

    static def client_project_templates -> list[dict[str, any]] {
        templates: list[dict[str, any]] = [];

        for template_name in ["web-app", "web-static", "mobile", "service", "cli"] {
            template = _load_template(template_name);
            if template {
                templates.append(template);
            }
        }

        return templates;
    }
}

def _load_template(template_name: str) -> dict[str, any] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    module_dir = Path(str(__file__)).parent;
    template_dir = module_dir / "templates" / template_name;

    if not template_dir.exists() {
        import from importlib.resources { files }
        try {
            package_root = str(files("jaclang"));
            template_dir = Path(package_root) / "client" / "templates" / template_name;
        } except (TypeError, ModuleNotFoundError) as e {
            console.warning(
                f"Failed to locate template directory for '{template_name}': {e}"
            );
            return None;
        }
    }

    if not template_dir.exists() or not template_dir.is_dir() {
        return None;
    }

    try {
        template = load_template_from_directory(template_dir);
        return template.to_dict();
    } except Exception as e {
        console.error(f"Warning: Could not load {template_name} template: {e}");
        return None;
    }
}
