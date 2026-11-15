import shutil;
import subprocess;
import os;
import re;
import json;
import from pathlib { Path }

glob _RUNTIME_JS_FILES = {"client_runtime.js", "pwa_runtime.js"},
     _WEB_ONLY_GLOBALS = ["window", "document", "localStorage"],
     _RN_ASSET_TOKEN_PREFIX = "__jac_rn_asset__:",
     _IMG_SRC_ALLOWED_PREFIXES = [
         "http://",
         "https://",
         "data:",
         "file://",
         "content://",
         "asset:/",
         "/"
     ];

glob _IMG_SRC_PATTERN = re.compile(
         r"""__jacJsx\(\s*['"]img['"]\s*,\s*\{[\s\S]*?\bsrc\s*:\s*['"]([^'"]+)['"]"""
     );

def _iter_user_js_files(compiled_dir: Path) -> list[Path];

def read_user_js_sources(compiled_dir: Path) -> list[tuple[Path, str]];

def _is_relative_img_src(src: str) -> bool;

def _resolve_relative_img_src(js_file: Path, src: str) -> Path | None;

def build_native_index_entry_body -> str;


def write_api_base_shim(rn_dir: Path, api_url: str = "");

def build_native_index_entry_source -> str;

def write_native_entry(rn_dir: Path);

def _strip_module_ext(name: str) -> str;

def entry_module_for(entry_file: Path, project_dir: Path) -> str;


def stage_compiled_entry(compiled_dir: Path, rn_dir: Path, entry_module: str) -> Path;

def stage_native_image_assets(
    js_tree_dir: Path, rn_dir: Path
) -> dict[str, (list[str] | int)];

def lint_unmapped_tags(
    compiled_dir: Path, sources: (list[tuple[Path, str]] | None) = None
) -> list[str];

def lint_native_incompatible_usage(
    compiled_dir: Path, sources: (list[tuple[Path, str]] | None) = None
) -> dict[(str, list[str])];

def strip_css_imports(compiled_dir: Path) -> int;

def run_expo_prebuild(rn_dir: Path, platform: str = "android");

def run_gradle_assemble(rn_dir: Path, release: bool = False) -> Path;

def run_xcodebuild_ios(
    rn_dir: Path, release: bool = False, simulator: bool = True
) -> Path;

def run_eas_local_build(
    rn_dir: Path, platform: str, profile: str = "production", release: bool = True
) -> Path;

def run_eas_update_opt_in(rn_dir: Path, platform: str, branch: str, message: str = "");

def _find_first_workspace_or_project(ios_dir: Path) -> Path | None;
