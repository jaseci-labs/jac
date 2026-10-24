import from pathlib { Path }

import json;
import shutil;
import sys;

glob PWA_DEFAULT_THEME_COLOR = "#000000",
     PWA_DEFAULT_BACKGROUND_COLOR = "#ffffff",
     PWA_DEFAULT_CACHE_NAME = "jac-pwa-cache-v1",
     PWA_ICON_SMALL = "pwa-192x192.png",
     PWA_ICON_LARGE = "pwa-512x512.png",
     PWA_API_PATH_PREFIX = "/api/",
     PWA_CACHEABLE_EXTENSIONS = ['.html', '.js', '.css', '.png', '.json'];

glob PWA_BANNER_STORAGE_KEY = "__jac_pwa_prefs__",
     PWA_BANNER_DEFAULT_DELAY_MS = 3000,
     PWA_BANNER_DISMISS_DELAYS_DAYS = [7, 14, 28],
     PWA_BANNER_MAX_DISMISSALS = 3,
     PWA_BANNER_ANIMATION_MS = 300,
     PWA_BANNER_Z_INDEX = 9999,
     PWA_IOS_MODAL_Z_INDEX = 10000,
     PWA_MS_PER_DAY = 86400000;

def _load_pwa_context -> tuple[dict[str, any], str];

def _get_default_manifest(
    project_name: str, pwa_config: dict[str, any]
) -> dict[str, any];

def _generate_pwa_icon(dest_path: Path, size: int) -> bool;

def _generate_default_pwa_icons(dest_dir: Path) -> int;

def _copy_icons(src_dir: Path, dest_dir: Path) -> int;

def _copy_pwa_icons_to_dist(dist_dir: Path, project_dir: Path) -> None;

def _generate_manifest(dist_dir: Path, project_name: str, pwa_config: dict[str, any]);

def _get_precache_files(dist_dir: Path) -> list[str];

def _build_service_worker_content(cache_name: str, precache_files: list[str]) -> str;

def _generate_service_worker(dist_dir: Path, pwa_config: dict[str, any]);

def _build_install_prompt_capture_script -> str;

def _build_pwa_head_tags(theme_color: str) -> str;

def _build_sw_registration_script -> str;

def _build_banner_css(position: str) -> str;

def _build_pwa_install_banner_script(pwa_config: dict[str, any]) -> str;

def _update_html_for_pwa(dist_dir: Path, pwa_config: dict[str, any]) -> None;

def ensure_pwa_icons(project_dir: Path) -> None;

def _copy_pwa_icons_to_project(dest_dir: Path);

def apply_pwa(dist_dir: Path, project_dir: Path);
