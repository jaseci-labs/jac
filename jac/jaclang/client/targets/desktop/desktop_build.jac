import os;
import json;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }

def _jaclang_src_roots -> list[Path];

def _find_desktop_native_dir -> Path;

def _find_native_asset_dir(subdir: str, marker: str) -> Path;

def _find_webview_dir -> Path;

def _find_cef_dir -> Path;

def _jac_subprocess_env -> dict[str, str];

def _patchelf_rpath(binary: Path, rpath: str) -> bool;

def _patch_host_rpath(binary: Path);


def _fused_runtime_dir -> Path;


def _stage_fused_runtime(out_dir: Path);


def _bundle_runtime(host_binary: Path);

def _jac_bin -> str;

def _cef_bootstrap_js -> str;

def _jac_sdk_js -> str;

def _top_level_import_boundary(lines: list[str]) -> int;

def _unit_source(module: Path, keep_imports: bool = True) -> str;

def _inject_platform(host_src: str, platform_src: str) -> str;

def _native_build_cef(
    cef_dir: Path, source_name: str, build_name: str, output: Path, shared: bool,
) -> Path;


def build_cef_dispatch(cef_dir: Path) -> Path;

def build_cef_subprocess(cef_dir: Path) -> Path;

def serving_app_for(config: any, entry_file: Path, backend: str) -> str;


def stage_program(
    entry_file: Path,
    project_dir: Path,
    image_dir: Path,
    backend: str,
    dist_dir: (Path | None)
) -> dict[str, str];

def stage_postgres(resources: Path, backend: str, vendor: bool = True) -> str;


def desktop_storage_identifier(
    identifier: str, project_dir: Path, entry_file: Path, backend: str
) -> str;

def storage_app_for(config: any, entry_file: Path, backend: str) -> str;
