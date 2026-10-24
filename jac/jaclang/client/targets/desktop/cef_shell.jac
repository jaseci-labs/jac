import os;
import shutil;
import json;
import subprocess;
import stat;

import from pathlib { Path }

def _is_stale(output: Path, inputs: list[Path]) -> bool;

def _ensure_libcef_dispatch(cef_dir: Path) -> Path;

def _ensure_cef_subprocess(cef_dir: Path) -> Path;

def _generate_host_source(
    title: str,
    width: int,
    height: int,
    app_name: str,
    cache_path: str,
    plugin_configs: (dict[str, any] | None) = None,
    program: (dict[str, any] | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    identifier: str = "",
    pg_dist: str = ""
) -> str;

def _stage_cef_runtime(cef_dist: Path, out_dir: Path);

def cef_build(
    entry_file: Path, project_dir: Path, out_dir: Path, web_bundle: Path
) -> Path;

def cef_start(binary: Path);

def cef_dev_unsupported;
