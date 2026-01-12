"""Implementation of base plugin configuration infrastructure."""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }

"""Deep merge two dictionaries recursively."""
impl deep_merge(base: dict[str, Any], override_dict: dict[str, Any]) -> dict[str, Any] {
    result = base.copy();
    for (key, value) in override_dict.items() {
        if (
            (key in result)
            and isinstance(result[key], dict)
            and isinstance(value, dict)
        ) {
            result[key] = deep_merge(result[key], value);
        } else {
            result[key] = value;
        }
    }
    return result;
}

"""Initialize config loader with project directory."""
impl PluginConfigBase.postinit{
    if self.project_dir is None {
        self.project_dir = Path.cwd();
    } else {
        self.project_dir = self.project_dir;
    }
    self.config_file = self.project_dir / 'jac.toml';
    self._config = None;
    self._jac_config = None;
}

"""Load configuration from jac.toml, merging with defaults."""
impl PluginConfigBase.load -> dict[str, Any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    jac_config = self.get_jac_config();
    # Get plugin config from [plugins.<plugin_name>] section
    plugin_name = self.get_plugin_name();
    plugin_config = jac_config.get_plugin_config(plugin_name);
    # Deep merge defaults with user configuration
    self._config = deep_merge(default_config, plugin_config);
    return self._config;
}

"""Get or load the core JacConfig instance."""
impl PluginConfigBase.get_jac_config -> JacConfig {
    if self._jac_config is None {
        if self.config_file.exists() {
            self._jac_config = JacConfig.load(self.config_file);
        } else {
            # Create a new config with project root
            self._jac_config = JacConfig();
            self._jac_config.toml_path = self.config_file;
            self._jac_config.project_root = self.project_dir;
        }
    }
    return self._jac_config;
}

"""Get a configuration section with optional defaults."""
impl PluginConfigBase.get_section(
    section: str, defaults: dict[str, Any] | None = None
) -> dict[str, Any] {
    config = self.load();
    section_config = config.get(section, {});
    if defaults is not None {
        # Merge section config with defaults (section_config takes precedence)
        return {k: section_config.get(k, v) for (k, v) in defaults.items()};
    }
    return section_config;
}

"""Invalidate the cached configuration."""
impl PluginConfigBase.invalidate -> None {
    self._config = None;
}
