import hashlib;
import json;
import marshal;
import os;
import shutil;
import sys;
import time;
import zlib;
import from contextlib { contextmanager }

import from pathlib { Path }

glob RESULT_NAME: str = "PRECOMPILE_RESULT.json",
     _PHASE_T: list[float] = [];

def _phase(label: str);

def compiler_identity -> str;

def find_package_dir(source_dir: str) -> str | None;

def _nested_project_dirs(package_dir: str) -> list[str];

def find_jac_files(package_dir: str) -> list[str];

def package_native_units(package_dir: str) -> list[str];

glob _sealable_cache: dict[tuple[str, str], list[str]] = {},
     _placement_cache: dict[tuple[str, str], dict[str, set[str]]] = {},
     _source_apps: dict[tuple[str, str], dict[str, str]] = {};

def _application_sources(package_dir: str, app: str) -> list[str] | None;

def sealable_sources(package_dir: str, app: str = "") -> list[str];

def placement_facts_map(package_dir: str, app: str = "") -> dict[str, list[str]];

def _emit_unit_diagnostics(jac_path: str, programs: list[JacProgram]);

glob _unit_program: list[JacProgram] = [];

def _native_extra(jac_path: str, pkg_root: str) -> dict[int, bytes];

def _unit_extra(jac_path: str, pkg_root: str, embed_src: bool) -> dict[int, bytes];

glob _unit_native_program: list[any] = [];

def precompile_native_unit(jac_path: str, collect: bool = True) -> str;

def precompile_context(
    jac_path: str, pkg_root: str, program: JacProgram, app: str = ""
) -> JacProgram;

@contextmanager
def precompile_unit_context(
    jac_path: str, pkg_root: str, collect: bool = True, app: str = ""
) -> Iterator[JacProgram];

def raised_at(err: BaseException) -> str;

def precompile_unit(
    jac_path: str,
    pkg_root: str,
    embed_src: bool = False,
    collect: bool = True,
    app: str = "",
    skip_analysis: bool = False
) -> bytes | None;

def _precompile_unit(
    jac_path: str,
    pkg_root: str,
    program: JacProgram,
    embed_src: bool = False,
    skip_analysis: bool = False
) -> bytes | None;

def _seal_boot_unit(
    jac_path: str, pkg_root: str, out_root: str, embed_src: bool
) -> str;

def seal_bootstrap(pkg_dir: Path, out_dir: Path, embed_src: bool) -> int;

glob PRECOMPILED_KEEP_DIRS: tuple[str, ...] = ();

def prune_stale_precompiled_dirs(precompiled_dir: Path, pyver: str) -> int;

def jir_to_module(
    pkg_name: str, rel_jir: str, mount_prefix: str = ""
) -> tuple[str, str, bool];

def image_mount_prefix(pkg_path: Path) -> str;

def locked_packages(pkg_path: Path) -> dict[str, str];

def bundle_app(config: any, app: str = "") -> any;

def app_metadata(pkg_path: Path, pkg_name: str, app: str = "") -> dict[str, any];

def collect_payloads(pkg_path: Path) -> dict[str, str];

def seal_runtime_closure(
    pkg_path: Path, out_dir: Path, embed_src: bool, app: str = ""
) -> bool;


def seal_finalize(
    pkg_path: Path,
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    embed_src: bool,
    app: str = ""
) -> int;

def native_roots(pkg_name: str, units: list[str]) -> list[str];

def kit_omissions(pkg_name: str) -> list[str];

def _compiler_kernel_units -> set[str];

def prebuild_native_closure(roots: list[str]) -> dict[(str, any)];

def prebuild_native_units(roots: list[str]);

glob SEAL_KERNEL_DIR_ENV: str = "JAC_SEAL_KERNEL_DIR";

def seal_native(
    pkg_path: Path, out_dir: Path, pkg_name: str, manifest_modules: dict[str, any]
) -> (dict[str, any] | None);

def adopt_kernel(
    pkg_path: Path, out_dir: Path, manifest_modules: dict[str, any], kernel_dir: str
) -> dict[str, any];

def _refresh_native_twin(twin: Path, jac_path: str, pkg_root: str) -> None;

def _drop_native_twin(twin: Path) -> bool;

def _shared_suffix -> str;

def write_manifest(
    precompiled_dir: Path,
    pkg_name: str,
    pyver: str,
    modules: dict[str, dict[str, any]],
    payloads: (dict[str, str] | None) = None,
    app_meta: (dict[str, any] | None) = None,
    native_record: (dict[str, any] | None) = None,
    omits: (list[str] | None) = None
);

def _precompile_retire(served: int, rss_mb: int) -> bool;

def precompile_exit(code: int);

def main;

def is_toolchain_package(package_dir: str) -> bool;

def run_precompile(
    source_dir: str,
    seal: bool = False,
    seal_compile: bool = False,
    finalize_only: bool = False,
    embed_src: bool = False,
    jobs_arg: str = "",
    app: str = ""
);

with entry:__main__ {
    main();
}
