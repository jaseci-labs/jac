"""Configuration loader for Jac Client build system.

This module provides configuration access for the client plugin.
Configuration is loaded from jac.toml under [plugins.client] section.

Inherits from PluginConfigBase to eliminate boilerplate code.
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.plugin_config { PluginConfigBase }

"""Client-specific configuration loader.

Provides access to vite, ts, and package configuration
from the [plugins.client] section of jac.toml.
"""
class JacClientConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacClientConfig) -> str;
    override def get_default_config(self: JacClientConfig) -> dict[str, Any];
    override def load(self: JacClientConfig) -> dict[str, Any];
    def save(self: JacClientConfig) -> None;
    def get_vite_config(self: JacClientConfig) -> dict[str, Any];
    def get_ts_config(self: JacClientConfig) -> dict[str, Any];
    def get_configs(self: JacClientConfig) -> dict[str, Any];
    def get_package_config(self: JacClientConfig) -> dict[str, Any];
    def add_dependency(
        self: JacClientConfig, name: str, version: str, is_dev: bool = False
    ) -> None;

    def remove_dependency(
        self: JacClientConfig, name: str, is_dev: bool = False
    ) -> bool;
}
