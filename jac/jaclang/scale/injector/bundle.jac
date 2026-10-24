import io;
import os;
import hashlib;
import logging;
import shutil;
import subprocess;
import tarfile;
import tempfile;
import time;
import tomllib;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

glob APP_VOLUME_NAME: str = "jac-app",
     APP_MOUNT_PATH: str = "/app",
     JAC_HOME: str = "/app/.jachome",
     TOOLCHAIN_SUBDIR: str = ".jactoolchain",
     DEFAULT_SEAL_TIMEOUT_S: int = 1800,
     PLACEHOLDER_JAC_TOML: str = "[project]\nname = \"app\"\n",
     STAGE_PREFIX: str = "jac-app-precompile-",
     STAGE_REAP_AGE_S: int = 86400;

glob _stage_roots: list[str] = [],
     SEAL_CACHE_KEEP: int = 2;

glob _reported_prunes: set[str] = set();

glob _EXCLUDE_DIRS: set[str] = {
         ".jac",
         "__pycache__",
         "node_modules",
         ".git",
         "dist",
         "build",
         ".venv",
         "venv",
         ".mypy_cache",
         ".pytest_cache"
     };

glob _EXCLUDE_FILES: set[str] = {
         ".env",
         "jac.toml",
         "id_rsa",
         "id_dsa",
         "id_ecdsa",
         "id_ed25519"
     };
glob _EXCLUDE_SUFFIXES: tuple[str, ...] = (
         ".pem",
         ".key",
         ".crt",
         ".cer",
         ".p12",
         ".pfx",
         ".jks",
         ".keystore"
     );
glob _EXCLUDE_ENV: set[str] = {"PYTHONPATH", "PYTHONHOME", "JAC_HANDOFF"};


def _is_bundle_required(rel: Path) -> bool;


def _is_client_dist(rel: Path) -> bool;


obj BundleSourceFilter {
    has ignore_patterns: list[str];

    def parks(rel: Path) -> bool;
    def is_build_tree(rel: Path) -> bool;
    def excludes_tree(rel: Path) -> bool;
    def excludes(rel: Path) -> bool;
    def matching_ignore_pattern(rel: Path) -> str;
    def exclusion_reason(rel: Path) -> str;
}


def source_filter_for(base: Path) -> BundleSourceFilter;


def _project_config(project_dir: str) -> any;


def _entry_module_spec(project_dir: str) -> (tuple[Path, Path] | None);


def entry_module_rel(project_dir: str) -> (Path | None);


def assert_entry_module_ships(base: Path, excluded: BundleSourceFilter);


def _exclude_dir_root(rel: Path) -> (str | None);


def partition_bundle_sources(base: Path) -> tuple[list[Path], list[str]];


def bundle_source_files(base: Path) -> list[Path];


def client_build_sources(base: Path) -> list[Path];


def _with_client_dist(raw: bytes, base: Path) -> bytes;


def resolve_fleet_entries(project_dir: str, fleet: any) -> dict[str, str];


def _fleet_entry_rel(base: Path, app: str, file: str) -> str;


def check_fleet_entries(
    base: Path,
    members: list[str],
    excluded: BundleSourceFilter,
    fleet: (FleetSpec | None)
) -> dict[str, str];


def unresolved_toml_references(text: str, environ: dict[str, str]) -> list[str];


def _is_shell_script_ref(ref: any) -> bool;


def add_source_members(
    tar: tarfile.TarFile, base: Path, sources: (list[Path] | None) = None
);


def nested_sanitized_tomls(base: Path) -> dict[str, str];


def stage_roots_in_use -> list[str];


def _stage_root_prefix -> str;


def _stage_root_pid(name: str) -> int;


def _pid_alive(pid: int) -> bool;


def _stage_root_expired(stage_root: Path) -> bool;


def reap_stale_stage_roots -> int;


def remove_stage_root(stage_root: Path);


def _remove_stage_roots;


def seal_step_env -> dict[str, str];


def _stage_app(
    base: Path,
    sanitized_toml: (str | None),
    sources: (list[Path] | None) = None,
    tomls: (dict[str, str] | None) = None
) -> Path;


def release_binary_env -> dict[str, str];


def _child_tree_script(
    jac_path: Path,
    work_dir: Path,
    timeout_s: int,
    rel_candidates: tuple[str, ...],
    fallback: Path
) -> Path;


def _legacy_sealer_script_for(
    jac_path: Path, stage_root: Path, timeout_s: int
) -> Path;


def sealed_app_name(project_dir: str, fleet: (FleetSpec | None)) -> str;


def _precompile_app(
    base: Path,
    seal_binary: bytes,
    sanitized_toml: (str | None),
    timeout_s: int,
    app: str = "",
    sources: (list[Path] | None) = None,
    tomls: (dict[str, str] | None) = None,
    seed: (Path | None) = None
) -> Path;


def fat_bundle_setting(project_dir: str) -> tuple[bool, bool];


def fat_bundle_enabled(project_dir: str) -> bool;


def seal_timeout_setting(project_dir: str) -> int;


def _vendor_stage(stage: Path, seal_binary: bytes, pod_arch: str = "");


def _resolved_python_specs(stage: Path) -> list[str];


def _strip_external_record_lines(site: Path);


def staged_venv_files(stage: Path) -> list[Path];


def _prune_seed_pip(site: Path, specs: list[str]);


def _venv_stage(stage: Path, seal_binary: bytes, timeout_s: int);


def seal_input_digest(
    base: Path,
    sources: list[Path],
    seal_binary: bytes,
    pod_arch: str,
    app_name: str,
    sanitized: (str | None),
    fat: bool,
    tomls: dict[str, str]
) -> str;


def _seal_cache_dir(base: Path) -> Path;


def _mtime(path: Path) -> float;


def _latest_seal(base: Path) -> (Path | None);


def _seed_precompiled(stage: Path, seed: (Path | None)) -> int;


def _cached_seal(base: Path, key: str) -> (bytes | None);


def _remember_seal(base: Path, key: str, raw: bytes);


def pack_jab(
    project_dir: str,
    seal_binary: bytes,
    pod_arch: str = "",
    fleet: any = None,
    client_ready: any = None
) -> bytes;


def content_address(raw: bytes) -> str;


def bundle_object_key(app_name: str, digest: str) -> str;


def ensure_jac_toml_cmd -> str;
