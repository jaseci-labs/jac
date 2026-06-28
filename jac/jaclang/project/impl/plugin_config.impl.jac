import from pathlib { Path }
import from jaclang.project.config { JacConfig, find_project_root }
import from jaclang.jac0core.runtime { JacRuntime }

impl deep_merge(base: dict[str, any], override_dict: dict[str, any]) -> dict[str, any] {
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

impl PluginConfigBase.postinit{
    full_target = JacRuntime.get_full_target_path();
    project_root_result = find_project_root(Path(full_target)) if full_target else None;
    self.project_dir = (
        self.project_dir
            if self.project_dir is not None
            else project_root_result[0] if project_root_result else Path.cwd()
    );
    self.config_file = self.project_dir / 'jac.toml';
    self._config = None;
    self._jac_config = None;
}

impl PluginConfigBase.load -> dict[str, any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    jac_config = self.get_jac_config();

    plugin_name = self.get_plugin_name();
    plugin_config = jac_config.get_plugin_config(plugin_name);

    if plugin_config is not None {
        self._config = deep_merge(default_config, plugin_config);
    } else {
        self._config = default_config;
    }
    return self._config;
}

impl PluginConfigBase.get_jac_config -> JacConfig {
    if self._jac_config is None {
        if self.config_file.exists() {
            self._jac_config = JacConfig.load(self.config_file);
        } else {
            self._jac_config = JacConfig();
            self._jac_config.toml_path = self.config_file;
            self._jac_config.project_root = self.project_dir;
        }
    }
    return self._jac_config;
}

impl PluginConfigBase.get_section(
    section: str, defaults: dict[str, any] | None = None
) -> dict[str, any] {
    config = self.load();
    section_config = config.get(section, {});
    if defaults is not None {
        return {k: section_config.get(k, v) for (k, v) in defaults.items()};
    }
    return section_config;
}

impl PluginConfigBase.invalidate -> None {
    self._config = None;
}
