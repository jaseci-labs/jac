import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }


def seal_copy_ignore(_dir: str, items: list[str]) -> list[str];

def run_precompiler(src_dir: str, flags: list[str]) -> int;

def resolve_entry_file(config: any, app: str = "") -> (Path | None);

def _without_keys(record: dict[str, any], dropped: str) -> dict[str, any];

def _portable_manifest(manifest: dict[str, any]) -> dict[str, any];

def build_serve_manifest(entry_file: Path, proj_root: Path) -> (dict[str, any] | None);


def ensure_client_dist(config: any, entry_file: Path) -> (Path | None);

def bake_native_payloads(config: any, pkg_copy: Path, app: str = "") -> bool;

def bake_serve_payloads(
    config: any, pkg_copy: Path, app: str = "", bake_client: bool = True
) -> bool;

def vendor_packages(config: any, pkg_copy: Path);

def make_sealed_image(
    config: any,
    parent: Path,
    name: str,
    out_dir: (Path | None) = None,
    app: str = "",
    bake_client: bool = True
) -> (Path | None);

def sealed_image_key(
    config: any, name: str, app: str, bake_client: bool, ignore: any
) -> str;

def seed_from_image(previous: Path, pkg_copy: Path) -> int;

def vendor_jab_deps(config: any, img: Path) -> bool;


def build_jab(
    config: any,
    out_path: Path,
    app: str = "",
    fat: bool = False,
    bake_client: bool = True,
    require_entry: bool = False
) -> Path;
