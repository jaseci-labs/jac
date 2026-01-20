"""Configuration loader for jac-byllm.

This module provides configuration access for the byllm plugin.
Configuration is loaded from jac.toml under [plugins.byllm] section.

Inherits from PluginConfigBase to eliminate boilerplate code.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.plugin_config { PluginConfigBase }

"""Byllm-specific configuration loader.

Provides access to model, call_params, and litellm configuration
from the [plugins.byllm] section of jac.toml.
"""
class JacByllmConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacByllmConfig) -> str;
    override def get_default_config(self: JacByllmConfig) -> dict[str, Any];
    def get_model_config(self: JacByllmConfig) -> dict[str, Any];
    def get_call_params_config(self: JacByllmConfig) -> dict[str, Any];
    def get_litellm_config(self: JacByllmConfig) -> dict[str, Any];
    def get_system_prompt(self: JacByllmConfig) -> str;
}

glob _byllm_config_instance: JacByllmConfig | None = None;

def get_byllm_config(project_dir: Path | None = None) -> JacByllmConfig;
def reset_byllm_config -> None;
