import from pathlib { Path }
import from jaclang.project.config { JacConfig, find_project_root, get_config_for_path }
import from jaclang.runtime.runtime { JacRuntime }

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
    full_target = self.entry_path or JacRuntime.get_full_target_path();
    project_root_result = find_project_root(Path(full_target)) if full_target else None;
    self.project_dir = (
        self.project_dir
            if self.project_dir is not None
            else project_root_result[0] if project_root_result else Path.cwd()
    );
    self.config_file = self.project_dir / 'jac.toml';
    self._config = None;
    self._config_app = '';
    self._jac_config = None;
}

impl PluginConfigBase.effective_jac_config -> JacConfig {
    jac_config = self.get_jac_config();
    app = jac_config.app_for_target(self.entry_path);
    if app is None {
        return jac_config;
    }
    try {
        return jac_config.effective_for_app(app.name);
    } except ValueError {
        return jac_config;
    }
}

impl PluginConfigBase.load -> dict[str, any] {
    jac_config = self.get_jac_config();
    app = jac_config.app_for_target(self.entry_path);
    app_name = app.name if app is not None else '';
    if self._config is not None and self._config_app == app_name {
        return self._config;
    }
    plugin_name = self.get_plugin_name();
    schema = self.get_config_schema();
    section = str(schema.get("section") or plugin_name);
    self._validate_layer(jac_config.get_plugin_config(plugin_name), schema, section);
    if app is not None {
        self._validate_layer(
            app.overlays.get(plugin_name),
            self.get_app_config_schema(),
            f"apps.{app_name}.{section}"
        );
    }
    self._config_app = app_name;
    self._config = deep_merge(
        self.get_default_config(),
        self.effective_jac_config().get_plugin_config(plugin_name)
    );
    return self._config;
}

impl PluginConfigBase.get_config_schema -> dict[str, any] {
    return {};
}

impl PluginConfigBase.get_app_config_schema -> dict[str, any] {
    return self.get_config_schema();
}

impl PluginConfigBase.get_config_strict_env -> str {
    return "";
}

impl PluginConfigBase._validate_layer(
    raw: dict[str, any] | None, schema: dict[str, any], section: str
) -> None {
    import from jaclang.project.config_schema {
        report_schema_findings,
        validate_against_schema
    }
    options = schema.get("options");
    if not isinstance(options, dict) or not options {
        return;
    }
    report_schema_findings(
        validate_against_schema(raw, options, section),
        section,
        self.get_config_strict_env()
    );
}

impl PluginConfigBase.get_jac_config -> JacConfig {
    config = get_config_for_path(
        self.config_file, force_discover=self._jac_config is None
    )
        if self.config_file.exists()
        else None;
    if config is not self._jac_config {
        self._config = None;
        self._jac_config = config;
    }
    return config
        if config is not None
        else JacConfig(toml_path=self.config_file, project_root=self.project_dir);
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
