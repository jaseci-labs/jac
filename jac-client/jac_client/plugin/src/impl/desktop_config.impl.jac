"""Implementation of Desktop target configuration loader.

Shared init / _get_jac_config / load are inherited from TargetConfig.
Only desktop-specific methods live here.
"""
import from pathlib { Path }
import from jaclang.project.config { JacConfig, get_config }
import from jaclang.project.plugin_config { deep_merge }
import from jaclang.cli.console { console }

"""Return the TOML section key for desktop config."""
impl DesktopConfig._section_key(self: DesktopConfig) -> str {
    return 'desktop';
}

"""Return default desktop configuration structure."""
impl DesktopConfig.get_default_config(self: DesktopConfig) -> dict[str, Any] {
    project_name = "my-jac-app";
    project_version = "1.0.0";
    try {
        jac_config = self._get_jac_config();
        if jac_config and jac_config.project {
            project_name = jac_config.project.name or project_name;
            project_version = jac_config.project.version or project_version;
        }
    } except Exception {
        console.warning("Failed to load JacConfig, using fallback defaults");
    }
    identifier = _generate_identifier(project_name);
    return {
        'name': project_name,
        'identifier': identifier,
        'version': project_version,
        'window': {
            'title': project_name,
            'width': 1200,
            'height': 800,
            'min_width': 800,
            'min_height': 600,
            'resizable': True,
            'fullscreen': False
        },
        'client_only': False,
        'platforms': {'windows': True, 'macos': True, 'linux': True},
        'features': {
            'system_tray': False,
            'auto_update': False,
            'notifications': False
        },
        'plugins': {
            'jac_scale': True,
            'byllm': True,
            'jac_coder': True,
            'jac_mcp': True
        }
    };
}

"""Get core desktop fields (name, identifier, version)."""
impl DesktopConfig.get_desktop_config(self: DesktopConfig) -> dict[str, Any] {
    config = self.load();
    return {
        'name': config.get('name', ''),
        'identifier': config.get('identifier', ''),
        'version': config.get('version', '1.0.0')
    };
}

"""Get window configuration."""
impl DesktopConfig.get_window_config(self: DesktopConfig) -> dict[str, Any] {
    return self.load().get('window', {});
}

"""Get platforms configuration."""
impl DesktopConfig.get_platforms_config(self: DesktopConfig) -> dict[str, Any] {
    return self.load().get('platforms', {});
}

"""Get features configuration."""
impl DesktopConfig.get_features_config(self: DesktopConfig) -> dict[str, Any] {
    return self.load().get('features', {});
}

"""Get plugins configuration (which Jac plugins to bundle)."""
impl DesktopConfig.get_plugins_config(self: DesktopConfig) -> dict[str, Any] {
    return self.load().get('plugins', {});
}

"""Check if desktop is configured for client-only mode (no sidecar)."""
impl DesktopConfig.is_client_only(self: DesktopConfig) -> bool {
    return bool(self.load().get('client_only', False));
}

"""Validate required desktop configuration fields."""
impl DesktopConfig.validate(self: DesktopConfig) -> None {
    config = self.load();
    name = config.get('name', '');
    if not name {
        raise ValueError(
            "Desktop configuration error: 'name' is required in [desktop] section"
        );
    }
    identifier = config.get('identifier', '');
    if not identifier {
        raise ValueError(
            "Desktop configuration error: 'identifier' is required in [desktop] section"
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

"""Generate identifier from project name."""
def _generate_identifier(name: str) -> str {
    import re;
    cleaned = re.sub(r'[^a-zA-Z0-9.\-]', '', name.lower());
    cleaned = re.sub(r'[.\-]+', '.', cleaned);
    cleaned = cleaned.strip('.');
    if not cleaned or '.' not in cleaned {
        cleaned = f"com.{cleaned}" if cleaned else "com.myapp";
    }
    return cleaned;
}

"""Check if identifier is valid (reverse domain notation)."""
def _is_valid_identifier(identifier: str) -> bool {
    import re;
    return bool(re.match(r'^[a-z0-9]+(\.[a-z0-9]+)+$', identifier.lower()));
}
