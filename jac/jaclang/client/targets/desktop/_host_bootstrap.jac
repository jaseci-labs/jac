import json;


def _fused_runtime_import_block -> str;


def _host_boot_py(
    app_name: str,
    mode: str,
    program: (dict[str, any] | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: (dict[str, any] | None) = None,
    identifier: str = "",
    pg_dist: str = ""
) -> str;


def _generate_host_source(
    title: str,
    width: int,
    height: int,
    app_name: str,
    program: (dict[str, any] | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: (dict[str, any] | None) = None,
    identifier: str = "",
    pg_dist: str = ""
) -> str;
