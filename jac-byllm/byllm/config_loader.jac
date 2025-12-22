"""Configuration loader for jac-byllm.

This module provides a thin wrapper around the core JacConfig,
providing byllm-specific configuration access. Configuration is loaded
from jac.toml under [plugins.byllm] section.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }

"""Wrapper around core JacConfig for byllm-specific configuration."""
class JacByllmConfig {
    def init(self: JacByllmConfig, project_dir: (Path | None) = None);
    def _get_default_config(self: JacByllmConfig) -> dict[str, Any];
    def load(self: JacByllmConfig) -> dict[str, Any];
    def _deep_merge(
        self: JacByllmConfig, base: dict[(str, Any)], override_dict: dict[(str, Any)]
    ) -> dict[str, Any];

    def get_model_config(self: JacByllmConfig) -> dict[str, Any];
    def get_call_params_config(self: JacByllmConfig) -> dict[str, Any];
    def get_litellm_config(self: JacByllmConfig) -> dict[str, Any];
}

"""Singleton instance for global config access."""
glob _byllm_config_instance: (JacByllmConfig | None) = None;

"""Get or create the global JacByllmConfig instance."""
def get_byllm_config(project_dir: (Path | None) = None) -> JacByllmConfig;

"""Reset the global config instance (useful for testing)."""
def reset_byllm_config -> None;
