"""Implementation of jac-desktop configuration loader."""
import from pathlib { Path }
import from jaclang.cli.console { console }

"""Plugin section name for [plugins.desktop]."""
impl JacDesktopConfig.get_plugin_name(self: JacDesktopConfig) -> str {
    return "desktop";
}

"""Default [plugins.desktop] configuration."""
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
        window=WindowConfig(title=project_name),
        client_only=False,
        plugins=SidecarPluginsConfig.defaults()
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

"""Jac plugins to bundle in the desktop sidecar."""
impl JacDesktopConfig.get_sidecar_plugins_config(
    self: JacDesktopConfig
) -> SidecarPluginsConfig {
    config = self.load();
    raw = config.get('plugins', {});
    if isinstance(raw, dict) {
        return SidecarPluginsConfig.from_dict(raw);
    }
    return SidecarPluginsConfig.defaults();
}

"""Read configured Tauri plugin ids from [plugins.desktop].tauri_plugins."""
impl JacDesktopConfig.get_tauri_plugins_config(self: JacDesktopConfig) -> list[str] {
    config = self.load();
    raw = config.get('tauri_plugins', None);
    if raw is None {
        return [];
    }
    if isinstance(raw, list) {
        return [
            str(p).strip()
            for p in raw
            if str(p).strip()
        ];
    }
    if isinstance(raw, dict) {
        return [
            str(k).strip()
            for (k, v) in raw.items()
            if v and str(k).strip()
        ];
    }
    return [];
}

impl JacDesktopConfig.is_auto_tauri_plugin_npm_enabled(self: JacDesktopConfig) -> bool {
    config = self.load();
    raw = config.get('auto_tauri_plugin_npm', None);
    if raw is None {
        return True;
    }
    return bool(raw);
}

impl JacDesktopConfig.is_client_only(self: JacDesktopConfig) -> bool {
    config = self.load();
    return bool(config.get('client_only', False));
}

impl JacDesktopConfig.validate(self: JacDesktopConfig) -> None {
    config = self.load();
    name = str(config.get('name', ''));
    if not name {
        raise ValueError(
            "Desktop configuration error: 'name' is required in [plugins.desktop]"
        );
    }
    identifier = str(config.get('identifier', ''));
    if not identifier {
        raise ValueError(
            "Desktop configuration error: 'identifier' is required in [plugins.desktop]"
        );
    }
    if not _is_valid_identifier(identifier) {
        console.warning(
            f"Desktop identifier '{identifier}' may not be valid. "
            "Use reverse domain notation (e.g., 'com.example.myapp')"
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
}

impl get_desktop_config(project_dir: Path | None = None) -> JacDesktopConfig {
    # Module-level singleton mirrors jac-client/jac-scale; not thread-safe.
    # If those packages move to contextvars, follow suit here.
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

def _is_valid_identifier(identifier: str) -> bool {
    import re;
    return bool(re.match(r'^[a-z0-9]+(\.[a-z0-9]+)+$', identifier.lower()));
}
