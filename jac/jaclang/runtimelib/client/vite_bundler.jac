import hashlib;
import json;
import logging;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .config_loader { JacClientConfig }

glob logger = logging.getLogger(__name__),
     API_BASE_URL_ENV_VAR = "JAC_CLIENT_API_BASE_URL",
     JAC_API_BASE_URL_KEY = "globalThis.__JAC_API_BASE_URL__",
     VITE_READY_TIMEOUT_SECONDS = 60,
     VITE_READY_PATTERNS = ['ready in', 'local:'],
     VITE_URL_PATTERNS = ['localhost', 'Local:', 'Network:'],
     CONFIG_META_KEYS = frozenset({'extension'});

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
    def _resolve_api_base_url(
        self: ViteBundler, api_base_url_override: str = ""
    ) -> str;

    def create_vite_config(
        self: ViteBundler,
        entry_file: Path,
        api_base_url_override: str = "",
        is_dev: bool = False,
        api_port: int = 8000,
        for_mobile_dev: bool = False,
        mobile_hmr_host: str = "",
        mobile_hmr_port: int = 0,
        for_desktop_dev: bool = False,
        desktop_broker_port: int = 0
    ) -> Path;

    def _format_config_object(self: ViteBundler, config: dict, indent: int = 0) -> str;
    def _format_define_entries(
        self: ViteBundler, api_base_url: str, custom_defines: dict
    ) -> str;

    def install_packages(
        self: ViteBundler,
        install_dir: Optional[Path] = None,
        force: bool = False,
        capture_output: bool = False,
        clean_stale: bool = False
    ) -> None;

    def add_packages(
        self: ViteBundler,
        packages: list[str],
        install_dir: Optional[Path] = None,
        dev: bool = False
    ) -> None;

    def _generate_vite_config_content(
        self: ViteBundler,
        is_dev: bool,
        entry_file: Path,
        api_base_url: str,
        base_path: str,
        api_port: int = 8000,
        for_mobile_dev: bool = False,
        mobile_hmr_host: str = "",
        mobile_hmr_port: int = 0,
        for_desktop_dev: bool = False,
        desktop_broker_port: int = 0
    ) -> str;

    def create_package_json(
        self: ViteBundler, project_name: Optional[str] = None
    ) -> Path;

    def create_tsconfig(self: ViteBundler) -> Path;
    def create_config_files(self: ViteBundler) -> list[Path];
    def create_npmrc(self: ViteBundler) -> Optional[Path];
    def start_dev_server(
        self: ViteBundler,
        port: int = 3000,
        suppress_initial_output: bool = False,
        host: str = ""
    ) -> any;

    def _ensure_dev_index_html(self: ViteBundler, build_dir: Path) -> None;
    def _ensure_dev_dependencies(self: ViteBundler, build_dir: Path) -> None;
    def _start_vite_with_output_capture(
        self: ViteBundler, command: list[str], build_dir: Path, sys_module: any
    ) -> any;
}
