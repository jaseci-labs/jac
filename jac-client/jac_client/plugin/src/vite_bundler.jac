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
     API_BASE_URL_ENV_VAR = "JAC_CLIENT_API_BASE_URL",
     JAC_API_BASE_URL_KEY = "globalThis.__JAC_API_BASE_URL__",
     VITE_READY_TIMEOUT_SECONDS = 60,  # Max time to wait for Vite to be ready
     VITE_READY_PATTERNS = ['ready in', 'local:'],
     VITE_URL_PATTERNS = ['localhost', 'Local:', 'Network:'];

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
        self: ViteBundler,
        entry_file: Path,
        api_base_url_override: str = "",
        is_dev: bool = False,
        api_port: int = 8000
    ) -> Path;

    def _get_plugin_var_name(self: ViteBundler, plugin_name: str) -> str;
    def _format_plugin_options(self: ViteBundler, options: dict) -> str;
    def _format_config_object(self: ViteBundler, config: dict, indent: int = 0) -> str;
    """Format define entries for Vite config (build-time constants)."""
    def _format_define_entries(
        self: ViteBundler, api_base_url: str, custom_defines: dict
    ) -> str;

    def _ensure_root_package_json(self: ViteBundler) -> None;
    def _cleanup_root_package_files(self: ViteBundler) -> None;
    def _generate_vite_config_content(
        self: ViteBundler,
        is_dev: bool,
        entry_file: Path,
        api_base_url: str,
        api_port: int = 8000
    ) -> str;

    def create_package_json(
        self: ViteBundler, project_name: Optional[str] = None
    ) -> Path;

    def create_tsconfig(self: ViteBundler) -> Path;
    """Create config files from jac.toml [plugins.client.configs]."""
    def create_config_files(self: ViteBundler) -> list[Path];

    """Create .npmrc from jac.toml [plugins.client.npm]."""
    def create_npmrc(self: ViteBundler) -> Optional[Path];

    """Start Vite dev server as a subprocess.

    Args:
        port: Port for the dev server
        suppress_initial_output: If True, capture Vite's stdout until ready
    """
    def start_dev_server(
        self: ViteBundler, port: int = 3000, suppress_initial_output: bool = False
    ) -> Any;

    # Internal helpers for dev server
    def _ensure_dev_index_html(self: ViteBundler, build_dir: Path) -> None;
    def _ensure_dev_dependencies(self: ViteBundler, build_dir: Path) -> None;
    def _start_vite_with_output_capture(
        self: ViteBundler, command: list[str], build_dir: Path, sys_module: Any
    ) -> Any;
}
# Env var used to pass API base URL through deep call chains
# (e.g., DesktopTarget.start -> WebTarget.build -> ViteBundler.create_vite_config)

# Vite dev server configuration

# Patterns to detect Vite server ready state

# Patterns to filter from Vite output (we print our own URLs)
