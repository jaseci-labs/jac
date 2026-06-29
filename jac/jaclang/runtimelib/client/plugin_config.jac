import os;
import from pathlib { Path }
import from jaclang.jac0core.runtime { hookimpl }
import from jaclang.project.config { JacConfig }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

class JacClientPluginConfig {
    @hookimpl
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "client",
            "version": "1.0.0",
            "description": "Jac client-side rendering with Vite bundling"
        };
    }

    @hookimpl
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

    @hookimpl
    static def register_dependency_type -> dict[str, any] {
        return {
            "name": "npm",
            "dev_name": "npm.dev",
            "cli_flag": "--npm",
            "install_dir": ".jac/client/configs",
            "install_handler": _npm_install_handler,
            "install_all_handler": _npm_install_all_handler,
            "remove_handler": _npm_remove_handler
        };
    }

    static def client_project_templates -> list[dict[str, any]] {
        templates: list[dict[str, any]] = [];

        for template_name in ["fullstack", "client", "mobile"] {
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
            template_dir = (
                Path(package_root) / "runtimelib" / "client" / "templates" / template_name
            );
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
        template = load_template_from_directory(
            template_dir, post_create_hook=_post_create_client
        );

        data = template.to_dict();
        data["post_create"] = _post_create_client;
        return data;
    } except Exception as e {
        console.error(f"Warning: Could not load {template_name} template: {e}");
        return None;
    }
}

def _post_create_client(project_path: Path, project_name: str) -> None {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client { get_bun }

    console.print();
    if get_bun() is None {
        console.warning("Bun is required for client development");
        console.print("  After installing Bun, run: jac add --cl\n", style="muted");
        return;
    }

    console.print("  ✔ Bun is installed", style="success");

    if os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL") {
        console.print(
            "\n  ⏭ Skipping package installation (JAC_CLIENT_SKIP_NPM_INSTALL is set)",
            style="muted"
        );
        console.print(
            "  Run 'jac add --npm' when ready to install packages.\n", style="muted"
        );
        return;
    }

    console.print();

    try {
        toml_path = project_path / "jac.toml";
        if not toml_path.exists() {
            console.error("Warning: jac.toml not found, skipping package installation");
            return;
        }

        bundler = ViteBundler(project_path);
        bundler.create_package_json(project_name=project_name);

        client_dir = bundler._get_client_dir();
        client_dir.mkdir(parents=True, exist_ok=True);

        configs_package_json = client_dir / 'configs' / 'package.json';
        if not configs_package_json.exists() {
            console.error(
                "Warning: package.json was not generated, skipping package installation"
            );
            return;
        }

        bun = get_bun();
        if not bun {
            console.warning("Bun is required but could not be found or installed.");
            console.print(
                "  💡 Install manually: https://bun.sh\n"
                "  💡 You can install packages later with: jac add --cl\n",
                style="muted"
            );
            return;
        }

        try {
            bundler.install_packages(force=True);
        } except ClientBundleError as e {
            console.warning(f"Failed to install packages: {e}");
            console.print(
                "  💡 You can install packages later with: jac add --cl\n", style="muted"
            );
        }
    } except Exception as e {
        console.warning(f"Could not install default packages: {e}");
        console.print(
            "  💡 You can install packages later with: jac add --cl\n", style="muted"
        );
    }
}

def _npm_install_handler(
    config: JacConfig,
    package_name: str,
    version: str | None = None,
    is_dev: bool = False
) {
    if config.project_root is None {
        raise RuntimeError("No project root found");
    }

    package_version: str = version or "latest";
    config.add_dependency(package_name, package_version, dev=is_dev, dep_type="npm");
    config.save();

    _regenerate_and_install(Path(str(config.project_root)));
}

def _npm_install_all_handler(config: JacConfig) {
    if config.project_root is None {
        raise RuntimeError("No project root found");
    }

    _regenerate_and_install(Path(str(config.project_root)));
}

def _npm_remove_handler(config: JacConfig, package_name: str, is_dev: bool = False) {
    if config.project_root is None {
        raise RuntimeError("No project root found");
    }

    project_dir: Path = Path(str(config.project_root));

    result = config.remove_dependency(package_name, dev=is_dev, dep_type="npm");
    if not result {
        deps_key = "dev-dependencies" if is_dev else "dependencies";
        raise RuntimeError(f'Package "{package_name}" not found in {deps_key}');
    }

    config.save();

    _regenerate_and_install(project_dir);
}

def _regenerate_and_install(project_dir: Path) {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    import from jaclang.runtimelib.client { get_bun }

    bun = get_bun();
    if not bun {
        raise RuntimeError(
            "Bun is required but could not be found or installed. "
            "Install manually: https://bun.sh"
        ) from None;
    }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();

    try {
        bundler.install_packages(force=True);
    } except ClientBundleError as e {
        raise RuntimeError(f"Failed to install packages: {e}") from e;
    }
}
