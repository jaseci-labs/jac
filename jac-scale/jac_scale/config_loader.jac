"""Configuration loader for Jac Scale.

This module provides a thin wrapper around the core JacConfig,
providing scale-specific configuration access. Configuration is loaded
from jac.toml under [plugins.scale] section.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }

"""Wrapper around core JacConfig for scale-specific configuration."""
class JacScaleConfig {
    def init(self: JacScaleConfig, project_dir: (Path | None) = None);
    def _get_default_config(self: JacScaleConfig) -> dict[str, Any];
    def load(self: JacScaleConfig) -> dict[str, Any];
    def _deep_merge(
        self: JacScaleConfig, base: dict[(str, Any)], override_dict: dict[(str, Any)]
    ) -> dict[str, Any];

    def get_jwt_config(self: JacScaleConfig) -> dict[str, Any];
    def get_sso_config(self: JacScaleConfig) -> dict[str, Any];
    def get_database_config(self: JacScaleConfig) -> dict[str, Any];
    def get_kubernetes_config(self: JacScaleConfig) -> dict[str, Any];
    def get_server_config(self: JacScaleConfig) -> dict[str, Any];
}

"""Singleton instance for global config access."""
glob _scale_config_instance: (JacScaleConfig | None) = None;

"""Get or create the global JacScaleConfig instance."""
def get_scale_config(project_dir: (Path | None) = None) -> JacScaleConfig;

"""Reset the global config instance (useful for testing)."""
def reset_scale_config -> None;
