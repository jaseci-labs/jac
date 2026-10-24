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
    def is_pwa_enabled(self: JacClientConfig) -> bool;
    def get_react_native_config(self: JacClientConfig) -> dict[str, any];
}

impl _migrate_legacy_meta_packages(
    jac_config: any, npm_deps: dict[str, any], npm_dev_deps: dict[str, any]
) -> tuple[dict[str, any], dict[str, any], bool] {
    migrated = False;

    if 'jac-client-node' in npm_deps {
        console.warning(
            "Migrating from jac-client-node meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('jac-client-node', dev=False, dep_type='npm');
        del npm_deps['jac-client-node'];

        all_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
        for (name, version) in all_runtime.items() {
            if name not in npm_deps {
                jac_config.add_dependency(name, version, dev=False, dep_type='npm');
                npm_deps[name] = version;
            }
        }
        console.success("Replaced jac-client-node with individual packages");
        migrated = True;
    }

    if '@jac-client/dev-deps' in npm_dev_deps {
        console.warning(
            "Migrating from @jac-client/dev-deps meta-package to individual dependencies..."
        );
        jac_config.remove_dependency('@jac-client/dev-deps', dev=True, dep_type='npm');
        del npm_dev_deps['@jac-client/dev-deps'];
        for (name, version) in CORE_DEV_DEPS.items() {
            if name not in npm_dev_deps {
                jac_config.add_dependency(name, version, dev=True, dep_type='npm');
                npm_dev_deps[name] = version;
            }
        }
        console.success("Replaced @jac-client/dev-deps with individual packages");
        migrated = True;
    }

    if migrated {
        jac_config.save();
    }
    return (npm_deps, npm_dev_deps, migrated);
}
