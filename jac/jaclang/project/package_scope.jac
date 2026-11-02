import os;
import from pathlib { Path }

glob STORE_BUCKET: str = "pkgs";

def is_package_name(name: str) -> bool;

def import_prefix(name: str) -> str;

def store_root -> Path;

def in_store(path: str) -> bool;

def declared_package_name(project_root: str) -> str;

def package_root_of(path: str) -> (str | None);

def is_dependency_module(path: str, owner_root: (str | None)) -> bool;

def mounts_dir(build_dir: Path) -> Path;


def package_exports(project_root: str) -> list[str];

def is_exported(module: str, exports: list[str]) -> bool;
