"""Plugin configuration hooks for jac-desktop.

Registers metadata and schema for the [plugins.desktop] section in jac.toml.
"""

import from importlib.metadata { version as pkg_version }
import from pathlib { Path }
import from jaclang.jac0core.runtime { hookimpl }


"""Plugin metadata for jac-desktop."""
obj PluginMetadata {
    has name: str,
        version: str,
        description: str;

    def to_dict -> dict[str, str] {
        return {
            'name': self.name,
            'version': self.version,
            'description': self.description
        };
    }
}

"""Single option spec in a plugin config schema."""
obj ConfigOptionSpec {
    has type: str,
        description: str,
        value_str: str = "",
        value_int: int = 0,
        value_bool: bool = False,
        value_list: list[str] = [],
        value_is_int: bool = False,
        value_is_bool: bool = False,
        value_is_list: bool = False,
        value_is_empty_dict: bool = False,
        nested: dict[str, ConfigOptionSpec] = {};

    def _default_value -> object {
        if self.value_is_int {
            return self.value_int;
        }
        if self.value_is_bool {
            return self.value_bool;
        }
        if self.value_is_list {
            return self.value_list;
        }
        if self.value_is_empty_dict {
            return {};
        }
        return self.value_str;
    }

    def to_dict -> dict[str, object] {
        if self.nested {
            nested_out: dict[str, object] = {};
            for (k, spec) in self.nested.items() {
                nested_out[k] = spec.to_dict();
            }
            return {
                'type': self.type,
                'default': self._default_value(),
                'description': self.description,
                'nested': nested_out
            };
        }
        return {
            'type': self.type,
            'default': self._default_value(),
            'description': self.description
        };
    }
}

"""Full plugin config schema returned by get_config_schema."""
obj PluginConfigSchema {
    has section: str,
        options: dict[str, ConfigOptionSpec];

    def to_dict -> dict[str, object] {
        options_out: dict[str, object] = {};
        for (k, spec) in self.options.items() {
            options_out[k] = spec.to_dict();
        }
        return {'section': self.section, 'options': options_out};
    }
}

def schema_str_option(value: str, description: str) -> ConfigOptionSpec {
    return ConfigOptionSpec(type="str", value_str=value, description=description);
}

def schema_int_option(value: int, description: str) -> ConfigOptionSpec {
    return ConfigOptionSpec(
        type="int", value_int=value, value_is_int=True, description=description
    );
}

def schema_bool_option(value: bool, description: str) -> ConfigOptionSpec {
    return ConfigOptionSpec(
        type="bool", value_bool=value, value_is_bool=True, description=description
    );
}

def schema_list_option(value: list[str], description: str) -> ConfigOptionSpec {
    return ConfigOptionSpec(
        type="list", value_list=value, value_is_list=True, description=description
    );
}

def schema_dict_option(
    description: str, nested: dict[str, ConfigOptionSpec] | None = None
) -> ConfigOptionSpec {
    nested_opts = nested if nested is not None else {};
    return ConfigOptionSpec(
        type="dict",
        description=description,
        nested=nested_opts,
        value_is_empty_dict=True
    );
}

"""Build the [plugins.desktop] configuration schema."""
def _desktop_config_schema -> PluginConfigSchema {
    return PluginConfigSchema(
        section="desktop",
        options={
            "name": schema_str_option("my-jac-app", "Display name for the desktop app"),
            "identifier": schema_str_option(
                "com.myapp", "Reverse-domain identifier (com.example.myapp)"
            ),
            "version": schema_str_option("1.0.0", "Desktop app version"),
            "window": schema_dict_option(
                "Window geometry: title, width, height, min_width, min_height, resizable.",
                nested={
                    "title": schema_str_option("", ""),
                    "width": schema_int_option(1200, ""),
                    "height": schema_int_option(800, ""),
                    "min_width": schema_int_option(800, ""),
                    "min_height": schema_int_option(600, ""),
                    "resizable": schema_bool_option(True, "")
                }
            )
        }
    );
}

"""Plugin configuration hooks for jac-desktop."""
class JacDesktopPluginConfig {
    @hookimpl
    static def get_plugin_metadata -> dict[str, str] {
        return PluginMetadata(
            name="desktop",
            version=pkg_version("jac-desktop"),
            description="Jac-native desktop target (webview + nacompile)."
        ).to_dict();
    }

    @hookimpl
    static def get_config_schema -> dict[str, object] {
        return _desktop_config_schema().to_dict();
    }

    """Contribute the `desktop` project-kind template to `jac create`."""
    @hookimpl
    static def register_project_template -> dict[str, object] | None {
        return _load_desktop_template();
    }
}

"""Load the bundled `desktop` project template (kind=desktop).

Mirrors jac-client's loader: the template lives in
`jac_desktop/templates/desktop/` as a directory template whose jac.toml carries
`[project] kind = "desktop"`. Reuses jac-client's `_post_create_client` hook so
the scaffolded app gets the same client bootstrap (Bun + npm deps).
"""
def _load_desktop_template -> dict[str, object] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    module_dir = Path(str(__file__)).parent;  # jac_desktop directory
    template_dir = module_dir / "templates" / "desktop";
    if not template_dir.exists() {
        import from importlib.resources { files }
        try {
            package_root = str(files("jac_desktop"));
            template_dir = Path(package_root) / "templates" / "desktop";
        } except (TypeError, ModuleNotFoundError) as e {
            console.warning(f"Failed to locate desktop template directory: {e}");
            return None;
        }
    }
    if not template_dir.exists() or not template_dir.is_dir() {
        return None;
    }
    # The `desktop` kind reuses jac-client's client bootstrap, so jac-client must
    # also be installed. Surface that explicitly -- otherwise a missing jac-client
    # makes this return None and the user is wrongly told to install jac-desktop
    # (which is already present, since this hook is running).
    try {
        import from jac_client.plugin.plugin_config { _post_create_client }
    } except ImportError {
        console.warning(
            "The 'desktop' project kind also requires jac-client (its client "
            "bootstrap). Install it with: pip install jac-client"
        );
        return None;
    }
    try {
        template = load_template_from_directory(
            template_dir, post_create_hook=_post_create_client
        );
        info = template.to_dict();
        info["post_create"] = _post_create_client;
        return info;
    } except Exception as e {
        console.warning(f"Could not load desktop template: {e}");
        return None;
    }
}
