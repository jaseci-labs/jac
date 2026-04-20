"""Implementation of Mobile target configuration loader."""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, get_config }
import from jaclang.project.plugin_config { deep_merge }
import from jaclang.cli.console { console }

"""Initialize MobileConfig with project directory."""
impl MobileConfig.init(self: MobileConfig, project_dir: Path | None = None) -> None {
    if project_dir is None {
        self.project_dir = Path.cwd();
    } else {
        self.project_dir = project_dir;
    }
    self._config = None;
    self._jac_config = None;
}

"""Get default configuration structure for mobile target."""
impl MobileConfig.get_default_config(self: MobileConfig) -> dict[str, Any] {
    # Try to get project name/version from JacConfig for defaults
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
    # Generate bundle identifier from project name
    bundle_id = _generate_bundle_id(project_name);
    slug = project_name.lower().replace(" ", "-");
    scheme = project_name.lower().replace(" ", "").replace("-", "").replace("_", "");

    return {
        'name': project_name,
        'bundle_id': bundle_id,
        'version': project_version,
        'display_name': project_name,
        'slug': slug,
        'scheme': scheme,
        'platforms': {'ios': True, 'android': True},
        'features': {'use_sidecar': False, 'api_url': None},
        'expo': {
            'orientation': 'portrait',
            'userInterfaceStyle': 'light',
            'icon': './assets/icon.png',
            'splash': {
                'image': './assets/splash.png',
                'resizeMode': 'contain',
                'backgroundColor': '#ffffff'
            },
            'ios': {'supportsTablet': True},
            'android': {
                'adaptiveIcon': {
                    'foregroundImage': './assets/adaptive-icon.png',
                    'backgroundColor': '#ffffff'
                }
            },
            'web': {'favicon': './assets/favicon.png'},
            'plugins': ['expo-router']
        }
    };
}

"""Get or load the core JacConfig instance."""
impl MobileConfig._get_jac_config(self: MobileConfig) -> JacConfig {
    if self._jac_config is None {
        self._jac_config = get_config();
        if self._jac_config is None {
            raise RuntimeError(
                "No jac.toml found. Run 'jac create' to create a project."
            );
        }
    }
    return self._jac_config;
}

"""Load configuration from jac.toml, merging with defaults."""
impl MobileConfig.load(self: MobileConfig) -> dict[str, Any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    # Try to get [mobile] section from jac.toml
    mobile_config = {};
    try {
        jac_config = self._get_jac_config();
        # Get [mobile] section from raw TOML data
        if jac_config and jac_config._raw_data {
            raw_data = jac_config._raw_data;
            mobile_config = raw_data.get('mobile', {});
        }
    } except Exception {
        console.warning("Failed to load JacConfig, using fallback defaults");
    }
    # Deep merge defaults with user configuration
    if mobile_config {
        self._config = deep_merge(default_config, mobile_config);
    } else {
        self._config = default_config;
    }
    return self._config;
}

"""Get mobile configuration (name, bundle_id, version, display_name)."""
impl MobileConfig.get_mobile_config(self: MobileConfig) -> dict[str, Any] {
    config = self.load();
    return {
        'name': config.get('name', ''),
        'bundle_id': config.get('bundle_id', ''),
        'version': config.get('version', '1.0.0'),
        'display_name': config.get('display_name', '')
    };
}

"""Get platforms configuration."""
impl MobileConfig.get_platforms_config(self: MobileConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('platforms', {});
}

"""Get features configuration."""
impl MobileConfig.get_features_config(self: MobileConfig) -> dict[str, Any] {
    config = self.load();
    return config.get('features', {});
}

"""Get app.json configuration for Expo from TOML."""
impl MobileConfig.get_app_json_config(self: MobileConfig) -> dict[str, Any] {
    config = self.load();
    expo_config = config.get('expo', {});

    # Get basic info
    name = config.get('display_name', config.get('name', 'my-jac-app'));
    slug = config.get('slug', name.lower().replace(' ', '-'));
    scheme = config.get(
        'scheme', name.lower().replace(' ', '').replace('-', '').replace('_', '')
    );
    version = config.get('version', '1.0.0');
    bundle_id = config.get('bundle_id', 'com.example.myapp');

    # Build app.json structure
    app_json = {
        'expo': {
            'name': name,
            'slug': slug,
            'scheme': scheme,
            'version': version,
            'orientation': expo_config.get('orientation', 'portrait'),
            'icon': expo_config.get('icon', './assets/icon.png'),
            'userInterfaceStyle': expo_config.get('userInterfaceStyle', 'light'),
            'splash': expo_config.get(
                'splash',
                {
                    'image': './assets/splash.png',
                    'resizeMode': 'contain',
                    'backgroundColor': '#ffffff'
                }
            ),
            'ios': {** expo_config.get('ios', {}), 'bundleIdentifier': bundle_id},
            'android': {** expo_config.get('android', {}), 'package': bundle_id},
            'web': expo_config.get('web', {'favicon': './assets/favicon.png'}),
            'plugins': expo_config.get('plugins', ['expo-router', 'expo-dev-client'])
        }
    };

    # Ensure ios has supportsTablet
    if 'supportsTablet' not in app_json['expo']['ios'] {
        app_json['expo']['ios']['supportsTablet'] = True;
    }

    # Ensure android has adaptiveIcon
    if 'adaptiveIcon' not in app_json['expo']['android'] {
        app_json['expo']['android']['adaptiveIcon'] = {
            'foregroundImage': './assets/adaptive-icon.png',
            'backgroundColor': '#ffffff'
        };
    }

    return app_json;
}

"""Get EAS (Expo Application Services) configuration for building."""
impl MobileConfig.get_eas_config(self: MobileConfig) -> dict[str, Any] {
    config = self.load();
    eas_config = config.get('eas', {});

    # Default EAS build profiles if not specified
    default_profiles = {
        'development': {
            'distribution': 'internal',
            'developmentClient': True,
            'android': {'gradleCommand': ':app:assembleDebug', 'buildType': 'apk'},
            'ios': {'simulator': True, 'buildConfiguration': 'Debug'}
        },
        'preview': {
            'distribution': 'internal',
            'android': {'gradleCommand': ':app:assembleRelease', 'buildType': 'apk'},
            'ios': {'simulator': False, 'buildConfiguration': 'Release'}
        },
        'production': {
            'distribution': 'store',
            'android': {
                'gradleCommand': ':app:bundleRelease',
                'buildType': 'app-bundle'
            },
            'ios': {'simulator': False, 'buildConfiguration': 'Release'}
        }
    };

    # Merge user-defined profiles with defaults
    profiles = eas_config.get('profiles', {});
    merged_profiles = {** default_profiles};

    for profile_name in profiles {
        profile_config = profiles[profile_name];
        if profile_name in merged_profiles {
            # Merge with default
            merged_profiles[profile_name] = deep_merge(
                merged_profiles[profile_name], profile_config
            );
        } else {
            # New custom profile
            merged_profiles[profile_name] = profile_config;
        }
    }

    return {
        'cli': {'version': '>= 13.2.0'},
        'build': merged_profiles,
        'submit': eas_config.get('submit', {})
    };
}

"""Validate mobile configuration."""
impl MobileConfig.validate(self: MobileConfig) -> None {
    config = self.load();
    # Required fields
    name = config.get('name', '');
    if not name {
        raise ValueError(
            "Mobile configuration error: 'name' is required in [mobile] section"
        );
    }
    bundle_id = config.get('bundle_id', '');
    if not bundle_id {
        raise ValueError(
            "Mobile configuration error: 'bundle_id' is required in [mobile] section"
        );
    }
    # Validate bundle_id format (should be reverse domain notation)
    if not _is_valid_bundle_id(bundle_id) {
        console.warning(
            f"Mobile bundle_id '{bundle_id}' may not be valid. Use reverse domain notation (e.g., 'com.example.myapp')"
        );
    }
}

"""Generate a valid bundle identifier from project name."""
def _generate_bundle_id(project_name: str) -> str {
    # Convert project name to valid bundle ID format
    # Example: "My Jac App" -> "com.example.myjacapp"
    clean_name = project_name.lower().replace(' ', '').replace('-', '').replace(
        '_', ''
    );
    return f"com.example.{clean_name}";
}

"""Validate bundle identifier format."""
def _is_valid_bundle_id(bundle_id: str) -> bool {
    # Basic validation: should be reverse domain notation
    # Example: com.example.myapp
    parts: list[str] = bundle_id.split('.');
    if len(parts) < 2 {
        return False;
    }
    for p in parts {
        if not p.isidentifier() {
            return False;
        }
    }
    return True;
}
