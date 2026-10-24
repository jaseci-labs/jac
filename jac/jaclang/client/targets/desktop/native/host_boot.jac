import os;
import sys;
import json;
import hashlib;
import importlib;
import platform;
import from pathlib { Path }


glob PLUGIN_BOOTSTRAP_MODULES: list[str] = [
         "manifest",
         "desktop_plugin",
         "webview_lib",
         "plugin_host",
         "registry"
     ],
     EMBEDDED: str = "embedded",
     PORT_RETRIES: int = 64;

glob _EMBEDDED_LOCKS: dict[str, any] = {},
     _EMBEDDED_STOPPED: set[str] = set(),
     _EMBEDDED_ENV_PRIOR: dict[str, any] = {};


obj HostContext {
    has port: int = 0,
        dev_port: int = 0,
        host: any = None,
        runtime: any = None,
        library_dir: str = "",
        pg_home: str = "",
        _stop: any = None;

    def setup_webview(wv_handle: int);
    def shutdown;
}


def preferred_port(app_name: str) -> int;


def host_executable -> str;


def default_data_dir(system: str, identifier: str, app_name: str) -> str;


def _migrate_legacy_data_dir(data_dir: str, app_dir: str) -> None;


def embedded_store_env(app_dir: str, data_dir: str, pg_dist: str) -> dict[str, str];


def _embedded_cluster_dir(home: str) -> str;


def _embedded_user_lock_path(home: str) -> str;


def _join_embedded_store(home: str) -> None;


def _holds_last_embedded_user(handle: any) -> bool;


def _enter_embedded_env(env: dict[str, str]);


def _leave_embedded_env;


def _stop_embedded_store(home: str) -> None;


def _apply_extra_deps;


def _bootstrap_plugin_host(plugin_configs: dict[str, any]) -> any;


def _ensure_jac_meta_importer;


def resolve_program(program: dict[str, any], app_dir: str) -> str;


def _pinned_port -> int;


def serve_program(
    entry_file: str,
    data_dir: str,
    dist_dir: str,
    app_name: str,
    backend: str,
    host: any,
    store: any
) -> tuple[any, int, any];


def boot(config_json: str) -> HostContext;
