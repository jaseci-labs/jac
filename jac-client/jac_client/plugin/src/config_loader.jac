"""Configuration loader for Jac Client build system."""
import json;
import from pathlib { Path }
import from typing { Any }
import from jaclang.runtimelib.client_bundle { ClientBundleError }

"""Manages Jac Client configuration from config.json."""
class JacClientConfig {
    def init(self: JacClientConfig, project_dir: Path);
    def _get_default_config(self: JacClientConfig) -> dict[str, Any];
    def load(self: JacClientConfig) -> dict[str, Any];
    def _deep_merge(
        self: JacClientConfig, base: dict[(str, Any)], override_dict: dict[(str, Any)]
    ) -> dict[str, Any];

    def get_vite_config(self: JacClientConfig) -> dict[str, Any];
    def get_ts_config(self: JacClientConfig) -> dict[str, Any];
    def get_package_config(self: JacClientConfig) -> dict[str, Any];
}
