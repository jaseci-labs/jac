"""Shared implementation for TargetConfig base class."""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig, get_config }
import from jaclang.project.plugin_config { deep_merge }
import from jaclang.cli.console { console }

"""Initialize with an optional project directory (defaults to cwd)."""
impl TargetConfig.init(self: TargetConfig, project_dir: Path | None = None) -> None {
    if project_dir is None {
        self.project_dir = Path.cwd();
    } else {
        self.project_dir = project_dir;
    }
    self._config = None;
    self._jac_config = None;
}

"""Return (or lazily load) the root JacConfig instance."""
impl TargetConfig._get_jac_config(self: TargetConfig) -> JacConfig {
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

"""Load and cache configuration from jac.toml, merged with defaults."""
impl TargetConfig.load(self: TargetConfig) -> dict[str, Any] {
    if self._config is not None {
        return self._config;
    }
    default_config = self.get_default_config();
    section_config = {};
    try {
        jac_config = self._get_jac_config();
        if jac_config and jac_config._raw_data {
            section_config = jac_config._raw_data.get(self._section_key(), {});
        }
    } except Exception {
        console.warning(
            f"Failed to load JacConfig for [{self._section_key()}], using defaults"
        );
    }
    if section_config {
        self._config = deep_merge(default_config, section_config);
    } else {
        self._config = default_config;
    }
    return self._config;
}
