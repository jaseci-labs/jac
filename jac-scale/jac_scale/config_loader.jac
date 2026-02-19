"""Configuration loader for Jac Scale.

This module provides configuration access for the scale plugin.
Configuration is loaded from jac.toml under [plugins.scale] section.

Inherits from PluginConfigBase to eliminate boilerplate code.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.plugin_config { PluginConfigBase }
import os;

"""Scale-specific configuration loader.

Provides access to jwt, sso, database, kubernetes, server and webhook configuration
from the [plugins.scale] section of jac.toml.
"""
class JacScaleConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacScaleConfig) -> str;
    override def get_default_config(self: JacScaleConfig) -> dict[str, Any];
    def get_jwt_config(self: JacScaleConfig) -> dict[str, Any];
    def get_sso_config(self: JacScaleConfig) -> dict[str, Any];
    def get_database_config(self: JacScaleConfig) -> dict[str, Any];
    def get_kubernetes_config(self: JacScaleConfig) -> dict[str, Any];
    def get_server_config(self: JacScaleConfig) -> dict[str, Any];
    def get_webhook_config(self: JacScaleConfig) -> dict[str, Any];
    def get_secrets_config(self: JacScaleConfig) -> dict[str, str];
    def get_monitoring_config(self: JacScaleConfig) -> dict[str, Any];
}

glob _scale_config_instance: JacScaleConfig | None = None;

def get_scale_config(project_dir: Path | None = None) -> JacScaleConfig;
def reset_scale_config -> None;
