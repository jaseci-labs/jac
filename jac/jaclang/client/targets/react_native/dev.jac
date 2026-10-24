import json;
import os;
import subprocess;
import from pathlib { Path }
import from typing { Optional }

glob JAC_RN_METRO_PORT_ENV: str = "JAC_RN_METRO_PORT",
     JAC_RN_DEV_HOST_ENV: str = "JAC_RN_DEV_HOST",
     JAC_RN_TUNNEL_ENV: str = "JAC_RN_TUNNEL",
     JAC_RN_API_PROXY_ENV: str = "JAC_RN_API_PROXY",
     METRO_API_PREFIX: str = "/__jac_api",
     DEFAULT_METRO_PORT: int = 8081;

def resolve_metro_port(cli_port: int = DEFAULT_METRO_PORT) -> int;

def setup_android_port_reverse(metro_port: int, api_port: int);

def inject_dev_api_base_url(rn_dir: Path, api_url: str) -> Optional[str];

def inject_metro_api_base(rn_dir: Path) -> Optional[str];

def restore_app_json(rn_dir: Path, original: Optional[str]) -> None;

def rn_hmr_on_jac_changed(
    event: FileChangeEvent,
    compiler: any,
    entry_file: Path,
    project_dir: Path,
    rn_dir: Path,
    entry_module: str
) -> None;

def build_expo_start_argv(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False
) -> list[str];

def run_expo_start(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False,
    packager_host: str = "",
    api_proxy: str = ""
) -> int;
