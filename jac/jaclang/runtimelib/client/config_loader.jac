import from pathlib { Path }
import from jaclang.project.plugin_config { PluginConfigBase }

class JacClientConfig(PluginConfigBase) {
    override def get_plugin_name(self: JacClientConfig) -> str;
    override def get_default_config(self: JacClientConfig) -> dict[str, any];
    override def load(self: JacClientConfig) -> dict[str, any];
    def save(self: JacClientConfig) -> None;
    def get_api_config(self: JacClientConfig) -> dict[str, any];
    def get_base_path(self: JacClientConfig) -> str;
    def get_vite_config(self: JacClientConfig) -> dict[str, any];
    def get_ts_config(self: JacClientConfig) -> dict[str, any];
    def get_configs(self: JacClientConfig) -> dict[str, any];
    def get_package_config(self: JacClientConfig) -> dict[str, any];
    def get_npm_config(self: JacClientConfig) -> dict[str, any];
    def add_dependency(
        self: JacClientConfig, name: str, version: str, is_dev: bool = False
    ) -> None;

    def remove_dependency(
        self: JacClientConfig, name: str, is_dev: bool = False
    ) -> bool;

    def get_paths_config(self: JacClientConfig) -> dict[str, str];
    def get_pwa_config(self: JacClientConfig) -> dict[str, any];
    def is_pwa_enabled(self: JacClientConfig) -> bool;
    def check_runtime_version(self: JacClientConfig) -> tuple[bool, str, str];
    def sync_runtime_version(self: JacClientConfig) -> None;
}
