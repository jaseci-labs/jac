"""Implementation of Desktop target configuration loader."""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, get_config }
import from jaclang.project.plugin_config { deep_merge }
import from jaclang.cli.console { console }

"""Initialize DesktopConfig with project directory."""
impl DesktopConfig.init(self: DesktopConfig, project_dir: Path | None = None) -> None {
    if project_dir is None {
        self.project_dir = Path.cwd();
    } else {
        self.project_dir = project_dir;
    }
    self._config = None;
    self._jac_config = None;
}

"""Get default configuration structure for desktop target."""
impl DesktopConfig.get_default_config(self: DesktopConfig) -> dict[str, Any] {
    # Try to get project name/version from JacConfig for defaults
    # If config is not available, use fallback defaults
    project_name = "my-jac-app";
    project_version = "1.0.0";
    try {
        jac_config = self._get_jac_config();
        if jac_config and jac_config.project {
            project_name = jac_config.project.name or project_name;
            project_version = jac_config.project.version or project_version;
        }
    } except Exception {
        # If config loading fails, use defaults
        console.warning("Failed to load JacConfig, using fallback defaults");
    }
    # Generate identifier from project name
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
        'platforms': {'windows': True, 'macos': True, 'linux': True},
        'features': {
            'system_tray': False,
            'auto_update': False,
            'notifications': False
        }
    };
}

"""Get or load the core JacConfig instance."""
impl DesktopConfig._get_jac_config(self: DesktopConfig) -> JacConfig {
    if self._jac_config is None {
        self._jac_config = get_config();
        if self._jac_config is None {
            raise RuntimeError(
                "No jac.toml found. Run 'jac create' to create a project."
            ) ;
        }
    }
    return self._jac_config;
}

"""Load configuration from jac.toml, merging with defaults."""
impl DesktopConfig.load(self: DesktopConfig) -> dict[str, Any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    # Try to get [desktop] section from jac.toml
    desktop_config = {};
    try {
        jac_config = self._get_jac_config();
        # Get [desktop] section from raw TOML data
        # The [desktop] section is not under [plugins], so we access it directly
        if jac_config and jac_config._raw_data {
            raw_data = jac_config._raw_data;
            desktop_config = raw_data.get('desktop', {});
        }
    } except Exception {
        # If config loading fails, use defaults only
        console.warning("Failed to load JacConfig, using fallback defaults");
    }
    # Deep merge defaults with user configuration
    if desktop_config {
        self._config = deep_merge(default_config, desktop_config);
    } else {
        self._config = default_config;
    }
    return self._config;
}

"""Get desktop configuration (name, identifier, version)."""
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
    config = self.load();
    return config.get('window', {});
}

"""Get platforms configuration."""
impl DesktopConfig.get_platforms_config(self: DesktopConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('platforms', {});
}

"""Get features configuration."""
impl DesktopConfig.get_features_config(self: DesktopConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('features', {});
}

"""Validate desktop configuration."""
impl DesktopConfig.validate(self: DesktopConfig) -> None {
    config = self.load();
    # Required fields
    name = config.get('name', '');
    if not name {
        raise ValueError(
            "Desktop configuration error: 'name' is required in [desktop] section"
        ) ;
    }
    identifier = config.get('identifier', '');
    if not identifier {
        raise ValueError(
            "Desktop configuration error: 'identifier' is required in [desktop] section"
        ) ;
    }
    # Validate identifier format (should be reverse domain notation)
    if not _is_valid_identifier(identifier) {
        console.warning(
            f"Desktop identifier '{identifier}' may not be valid. Use reverse domain notation (e.g., 'com.example.myapp')"
        );
    }
    # Validate window dimensions
    window = config.get('window', {});
    width = window.get('width', 1200);
    height = window.get('height', 800);
    min_width = window.get('min_width', 800);
    min_height = window.get('min_height', 600);
    if min_width > width {
        raise ValueError(
            f"Desktop configuration error: window.min_width ({min_width}) cannot be greater than window.width ({width})"
        ) ;
    }
    if min_height > height {
        raise ValueError(
            f"Desktop configuration error: window.min_height ({min_height}) cannot be greater than window.height ({height})"
        ) ;
    }
}

"""Generate identifier from project name."""
def _generate_identifier(name: str) -> str {
    # Convert to lowercase, replace spaces/special chars with dots
    import re;
    # Remove special characters, keep alphanumeric, dots, hyphens
    cleaned = re.sub(r'[^a-zA-Z0-9.\-]', '', name.lower());
    # Replace multiple dots/hyphens with single dot
    cleaned = re.sub(r'[.\-]+', '.', cleaned);
    # Remove leading/trailing dots
    cleaned = cleaned.strip('.');
    # If empty or doesn't look like reverse domain, prefix with 'com.'
    if not cleaned or not '.' in cleaned {
        cleaned = f"com.{cleaned}" if cleaned else "com.myapp";
    }
    return cleaned;
}

"""Check if identifier is valid (reverse domain notation)."""
def _is_valid_identifier(identifier: str) -> bool {
    import re;
    # Should be like: com.example.myapp (at least one dot, alphanumeric + dots)
    return bool(re.match(r'^[a-z0-9]+(\.[a-z0-9]+)+$', identifier.lower()));
}
