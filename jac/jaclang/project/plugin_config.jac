"""Base configuration infrastructure for Jac plugins.

This module provides base classes and utilities that eliminate duplication
across plugin configuration loaders. Plugins should inherit from PluginConfigBase
to get common functionality like config loading, caching, and deep merging.

Example usage in a plugin:

    import from jaclang.project.plugin_config { PluginConfigBase }

    class MyPluginConfig(PluginConfigBase) {
        override def get_plugin_name(self: MyPluginConfig) -> str;
        override def get_default_config(self: MyPluginConfig) -> dict[str, Any];
    }

    # In impl file:
    impl MyPluginConfig.get_plugin_name(self: MyPluginConfig) -> str {
        return "myplugin";
    }
    impl MyPluginConfig.get_default_config(self: MyPluginConfig) -> dict[str, Any] {
        return {"setting": "default"};
    }
"""
import from pathlib { Path }
import from typing { Any }
import from jaclang.project.config { JacConfig }

def deep_merge(base: dict[str, Any], override_dict: dict[str, Any]) -> dict[str, Any];

"""Base class for plugin configuration loaders.

Provides common functionality for loading plugin-specific configuration
from jac.toml files. Subclasses must implement get_plugin_name() and
get_default_config() to specify their configuration structure.

Features:
- Lazy loading and caching of configuration
- Automatic deep merging of user config with defaults
- Integration with core JacConfig system
- Generic section getter with type conversion
"""
class PluginConfigBase {
    has project_dir: Path,
        config_file: Path,
        _config: dict[str, Any] | None = None,
        _jac_config: JacConfig | None = None;

    def init(self: PluginConfigBase, project_dir: Path | None = None);
    def get_plugin_name(self: PluginConfigBase) -> str abs;
    def get_default_config(self: PluginConfigBase) -> dict[str, Any] abs;
    def load(self: PluginConfigBase) -> dict[str, Any];
    def get_jac_config(self: PluginConfigBase) -> JacConfig;
    def get_section(
        self: PluginConfigBase, section: str, defaults: dict[(str, Any)] | None = None
    ) -> dict[str, Any];

    def invalidate(self: PluginConfigBase) -> None;
}
# Singleton Pattern Usage:
# -----------------------
# Each plugin can implement singleton access like this:
#
#     glob _my_config_instance: MyPluginConfig | None = None;
#
#     def get_my_config(project_dir: Path | None = None) -> MyPluginConfig {
#         global _my_config_instance;
#         if _my_config_instance is None {
#             _my_config_instance = MyPluginConfig(project_dir);
#         }
#         return _my_config_instance;
#     }
#
#     def reset_my_config() -> None {
#         global _my_config_instance;
#         _my_config_instance = None;
#     }
