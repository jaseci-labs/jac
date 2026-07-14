import from pathlib { Path }
import from jaclang.cli.console { console }

impl JacDesktopConfig.get_plugin_name(self: JacDesktopConfig) -> str {
    return "desktop";
}

impl JacDesktopConfig.get_default_config(self: JacDesktopConfig) -> dict[str, any] {
    project_name = "my-jac-app";
    project_version = "1.0.0";
    try {
        jac_config = self.get_jac_config();
        if jac_config and jac_config.project {
            project_name = jac_config.project.name or project_name;
            project_version = jac_config.project.version or project_version;
        }
    } except Exception {
        console.warning("Failed to load JacConfig, using fallback defaults");
    }
    identifier = _generate_identifier(project_name);
    return DesktopDefaultConfig(
        name=project_name,
        identifier=identifier,
        version=project_version,
        window=WindowConfig(title=project_name)
    ).to_dict();
}

impl JacDesktopConfig.get_identity(self: JacDesktopConfig) -> DesktopIdentity {
    config = self.load();
    return DesktopIdentity(
        name=str(config.get('name', '')),
        identifier=str(config.get('identifier', '')),
        version=str(config.get('version', '1.0.0'))
    );
}

impl JacDesktopConfig.get_window_config(self: JacDesktopConfig) -> WindowConfig {
    config = self.load();
    identity = self.get_identity();
    window_data: dict[str, any] = {};
    raw_window = config.get('window', {});
    if isinstance(raw_window, dict) {
        window_data = raw_window;
    }
    return WindowConfig.from_dict(window_data, title_fallback=identity.name);
}

impl JacDesktopConfig.get_dispatch_config(self: JacDesktopConfig) -> DispatchConfig {
    config = self.load();
    raw = config.get('dispatch', {});
    data: dict[str, any] = {};
    if isinstance(raw, dict) {
        data = raw;
    }
    return DispatchConfig.from_dict(data);
}

impl JacDesktopConfig.get_engine(self: JacDesktopConfig) -> str {
    config = self.load();
    engine = str(config.get('engine', 'native'));
    if engine not in ('native', 'cef') {
        raise ValueError(
            f"Desktop configuration error: engine must be 'native' or 'cef', got '{engine}'"
        );
    }
    return engine;
}

impl JacDesktopConfig.get_plugin_configs(self: JacDesktopConfig) -> dict[str, any] {
    config = self.load();
    plugins = config.get('plugins', {});
    if not isinstance(plugins, dict) {
        return {};
    }
    return plugins;
}

impl JacDesktopConfig.validate(self: JacDesktopConfig) -> None {
    config = self.load();
    name = str(config.get('name', ''));
    if not name {
        raise ValueError(
            "Desktop configuration error: 'name' is required in [desktop]"
        );
    }
    window = config.get('window', {});
    width = window.get('width', 1200);
    height = window.get('height', 800);
    min_width = window.get('min_width', 800);
    min_height = window.get('min_height', 600);
    if min_width > width {
        raise ValueError(
            f"Desktop configuration error: window.min_width ({min_width}) "
            f"cannot be greater than window.width ({width})"
        );
    }
    if min_height > height {
        raise ValueError(
            f"Desktop configuration error: window.min_height ({min_height}) "
            f"cannot be greater than window.height ({height})"
        );
    }
    dispatch = config.get('dispatch', {});
    if isinstance(dispatch, dict) {
        timeout_s = float(dispatch.get('timeout_s', 30.0));
        max_queue = int(dispatch.get('max_queue', 128));
        if timeout_s <= 0 {
            raise ValueError(
                f"Desktop configuration error: dispatch.timeout_s ({timeout_s}) "
                f"must be greater than 0"
            );
        }
        if max_queue < 1 {
            raise ValueError(
                f"Desktop configuration error: dispatch.max_queue ({max_queue}) "
                f"must be at least 1"
            );
        }
    }
    plugins = config.get('plugins', {});
    if isinstance(plugins, dict) {
        _validate_plugin_keys(plugins);
    }
}

def _validate_plugin_keys(plugins: dict[str, any]) -> None {
    import from jaclang.runtimelib.client.desktop_plugin_config {
        _desktop_config_schema
    }
    plugins_spec = _desktop_config_schema().options.get('plugins', None);
    if plugins_spec is None {
        return;
    }
    known = plugins_spec.nested;
    for (plugin_name, value) in plugins.items() {
        if plugin_name not in known {
            valid = ", ".join(sorted(known.keys()));
            raise ValueError(
                f"Desktop configuration error: unknown plugin "
                f"'[desktop.plugins.{plugin_name}]'. Valid plugins: {valid}."
            );
        }
        sub_schema = known[plugin_name].nested;
        if isinstance(value, dict) and sub_schema {
            for sub_key in value.keys() {
                if sub_key not in sub_schema {
                    valid = ", ".join(sorted(sub_schema.keys()));
                    raise ValueError(
                        f"Desktop configuration error: unknown option '{sub_key}' "
                        f"under [desktop.plugins.{plugin_name}]. "
                        f"Valid options: {valid}."
                    );
                }
            }
        }
    }
}

impl get_desktop_config(project_dir: Path | None = None) -> JacDesktopConfig {
    global _desktop_config_instance;
    if (
        _desktop_config_instance is not None
        and project_dir != _desktop_config_instance.project_dir
    ) {
        _desktop_config_instance = None;
    }
    if _desktop_config_instance is None {
        _desktop_config_instance = JacDesktopConfig(project_dir=project_dir);
    }
    return _desktop_config_instance;
}

impl reset_desktop_config -> None {
    global _desktop_config_instance;
    _desktop_config_instance = None;
}

def _generate_identifier(name: str) -> str {
    import re;
    cleaned = re.sub(r'[^a-zA-Z0-9.\-]', '', name.lower());
    cleaned = re.sub(r'[.\-]+', '.', cleaned);
    cleaned = cleaned.strip('.');
    if not cleaned or not '.' in cleaned {
        cleaned = f"com.{cleaned}" if cleaned else "com.myapp";
    }
    return cleaned;
}
