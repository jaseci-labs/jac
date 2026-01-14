"""Vite bundling module."""
import hashlib;
import json;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Any, Optional }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }
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
    def create_vite_config(self: ViteBundler, entry_file: Path) -> Path;
    def _get_plugin_var_name(self: ViteBundler, plugin_name: str) -> str;
    def _format_plugin_options(self: ViteBundler, options: dict) -> str;
    def _format_config_object(self: ViteBundler, config: dict, indent: int = 0) -> str;
    def _ensure_root_package_json(self: ViteBundler) -> None;
    def _cleanup_root_package_files(self: ViteBundler) -> None;
    def create_package_json(
        self: ViteBundler, project_name: Optional[str] = None
    ) -> Path;

    def create_tsconfig(self: ViteBundler) -> Path;
    """Create a dev-mode vite config with API proxy for HMR."""
    def create_dev_vite_config(
        self: ViteBundler, entry_file: Path, api_port: int = 8000
    ) -> Path;

    """Start Vite dev server as a subprocess."""
    def start_dev_server(self: ViteBundler, port: int = 3000) -> Any;
}
