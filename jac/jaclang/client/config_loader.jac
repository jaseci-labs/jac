import from pathlib { Path }


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
    def get_assets_config(self: JacClientConfig) -> dict[str, any];
    def get_asset_extensions(self: JacClientConfig) -> set[str];
    def get_assets_dir(self: JacClientConfig, entry_path: str = "") -> Path;
    def get_app_root(self: JacClientConfig, entry_path: str = "") -> Path;
    def get_public_dirs(self: JacClientConfig, entry_path: str = "") -> list[Path];
    def get_seo_config(self: JacClientConfig, entry_path: str = "") -> dict[str, any];
    def is_pwa_enabled(self: JacClientConfig) -> bool;
    def get_react_native_config(self: JacClientConfig) -> dict[str, any];
}

def eco_vite_settings(jac_config: any, entry_path: str) -> dict[str, any];

def _parse_vite_config(text: str) -> dict[str, any];
def _imported_names(clause: str) -> list[str];
def _bracketed(text: str, open_at: int) -> str;
def _split_top_level(text: str) -> list[str];
