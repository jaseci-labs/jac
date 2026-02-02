"""Vite bundling module."""
import hashlib;
import json;
import logging;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Any, Optional }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }

glob logger = logging.getLogger(__name__),
     API_BASE_URL_ENV_VAR = "JAC_CLIENT_API_BASE_URL";

"""Handles Vite bundling operations."""
class ViteBundler {
    def init(
        self: ViteBundler,
        project_dir: Path,
        output_dir: Optional[Path] = None,
        minify: bool = False,
        config_path: Optional[Path] = None
    );

    def _get_client_dir(self: ViteBundler) -> Path;
    def build(self: ViteBundler, entry_file: Optional[Path] = None) -> None;
    def find_bundle(self: ViteBundler) -> Optional[Path];
    def find_css(self: ViteBundler) -> Optional[Path];
    def read_bundle(self: ViteBundler) -> tuple[str, str];
    def _has_typescript_support(self: ViteBundler) -> bool;
    def _resolve_api_base_url(
        self: ViteBundler, api_base_url_override: str = ""
    ) -> str;

    def create_vite_config(
        self: ViteBundler, entry_file: Path, api_base_url_override: str = ""
    ) -> Path;

    def _get_plugin_var_name(self: ViteBundler, plugin_name: str) -> str;
    def _format_plugin_options(self: ViteBundler, options: dict) -> str;
    def _format_config_object(self: ViteBundler, config: dict, indent: int = 0) -> str;
    def _ensure_root_package_json(self: ViteBundler) -> None;
    def _cleanup_root_package_files(self: ViteBundler) -> None;
    def create_package_json(
        self: ViteBundler, project_name: Optional[str] = None
    ) -> Path;

    def create_tsconfig(self: ViteBundler) -> Path;
    """Create config files from jac.toml [plugins.client.configs]."""
    def create_config_files(self: ViteBundler) -> list[Path];

    """Create a dev-mode vite config with API proxy for HMR."""
    def create_dev_vite_config(
        self: ViteBundler,
        entry_file: Path,
        api_port: int = 8000,
        api_base_url_override: str = ""
    ) -> Path;

    """Start Vite dev server as a subprocess."""
    def start_dev_server(self: ViteBundler, port: int = 3000) -> Any;
}
# Env var used to pass API base URL through deep call chains
# (e.g., DesktopTarget.start -> WebTarget.build -> ViteBundler.create_vite_config)
