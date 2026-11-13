import os;
import shutil;
import tempfile;
import tomllib;
import from pathlib { Path }

glob PACKAGE_EXCLUDES: set[str] = {
         ".git",
         ".jac",
         "node_modules",
         "__pycache__",
         "_precompiled",
         "dist",
         "build",
         ".venv",
         "venv",
         ".mypy_cache",
         ".pytest_cache",
         "jac.lock"
     };

obj ArtifactError(Exception) {}

obj PackageIdentity {
    has name: str,
        version: str;
}

def package_copy_ignore(directory: str, items: list[str]) -> list[str];

def stage_source_tree(src: Path, dest: Path);

def pack_source_tree(src: Path) -> bytes;

def read_identity(tree: Path) -> PackageIdentity;

def expect_identity(tree: Path, name: str, version: str = "");

def rel_posix(path: Path, base: Path) -> str;

glob PACKAGE_MANIFEST_FORMAT: int = 1,
     MANIFEST_DIR: str = "_precompiled",
     MANIFEST_FILE: str = "MANIFEST.json",
     API_FILE: str = "API.json",
     ROLE_APP: str = "app",
     ROLE_LIB: str = "lib",
     ROLE_TEMPLATE: str = "template";

obj BuiltPackage {
    has data: bytes,
        sha256: str,
        manifest: dict[str, any],
        surface: dict[str, any] = {};
}

def project_role(config: any) -> str;

def template_identity(config: any) -> PackageIdentity;

def package_identity(config: any) -> PackageIdentity;

def package_manifest(
    config: any, role: str, surface: dict[str, any]
) -> dict[str, any];

def read_package_manifest(tree: Path) -> dict[str, any] | None;

def build_package(config: any) -> BuiltPackage;
