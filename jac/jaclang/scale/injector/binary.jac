import io;
import os;
import json;
import hashlib;
import logging;
import shutil;
import tarfile;
import from pathlib { Path }

import from urllib.request { urlopen }
import from urllib.error { HTTPError }

glob logger = logging.getLogger(__name__);

glob BINARY_ARCNAME: str = "bin/jac",
     _HTTP_TIMEOUT: int = 60;


def _node_architecture(k8s_node: object) -> str;


def cluster_node_archs -> list[str];


def node_arch -> str;


def _http_get_bytes(url: str) -> bytes;


glob GH_REPO: str = "jaseci-labs/jac";


def _list_release_versions(repo: str) -> list[str];


def _resolve_target_version(repo: str, spec: str) -> str;


def _pick_stable_assets(meta: any, suffix: str) -> tuple[str, str];


glob _deploy_version_memo: dict[str, any] = {};


def resolve_deploy_version(project_dir: str, channel: str) -> str;


def deploy_generation_refusal(
    project_dir: str, channel: str = "", offline: bool = False
) -> str;


def resolve_console_version(
    project_dir: str, channel: str, deploy_version: str
) -> str;


def resolve_pinned_version(project_dir: str) -> str;


def reset_deploy_version_cache;


def host_seal_platform -> str;


def stable_release_meta(version: str = "") -> dict[str, any];


def _no_asset_message(meta: dict[str, any], suffix: str, version: str) -> str;


def preflight_pod_runtime(project_dir: str, channel: str, arch: str) -> str;


def read_local_binary(project_dir: str) -> bytes;


def download_release_binary(
    channel: str, arch: str, version: str = "", plat: str = "linux"
) -> bytes;


def _fetch_verified_asset(
    url: str, checksum_url: str, cache_file: Path, what: str
) -> bytes;


def host_toolchain_path(project_dir: str, channel: str = "") -> str;


glob OFFICIAL_IMAGE: str = "jaseci/jaclang";


def resolve_pod_base_image(
    project_dir: str, configured: str, probe: bool = True
) -> str;


def _scale_cache_root -> Path;


def _binary_cache_path(
    channel: str, arch: str, plat: str = "linux", version: str = ""
) -> Path;


def _admin_dist_cache_path(channel: str, version: str = "") -> Path;


def pack_binary_bytes(binary_bytes: bytes) -> bytes;


def admin_dist_source(channel: str, version: str) -> str;


def _admin_dist_urls(channel: str, version: str = "") -> tuple[str, str];


def download_admin_dist(channel: str, version: str = "") -> bytes | None;


def stage_admin_dist(project_dir: str, channel: str, version: str = "") -> bool;


def toolchain_object_key(app_name: str, digest: str) -> str;
