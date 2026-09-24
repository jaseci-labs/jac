import os;
import shutil;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.dist.archive { tar_gz_dir }
import from jaclang.dist.sanitize { sanitize_shipped_tree }

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

def package_copy_ignore(directory: str, items: list[str]) -> list[str] {
    return [
        it
        for it in items
        if it in PACKAGE_EXCLUDES or it.endswith("-seal-stage")
    ];
}

def stage_source_tree(src: Path, dest: Path) {
    shutil.copytree(src, dest, ignore=package_copy_ignore, symlinks=False);
    sanitize_shipped_tree(dest);
}

def pack_source_tree(src: Path) -> bytes {
    stage = Path(tempfile.mkdtemp(prefix="jac-pack-"));
    try {
        tree = stage / "pkg";
        stage_source_tree(src, tree);
        return tar_gz_dir(tree);
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
}

def read_identity(tree: Path) -> PackageIdentity {
    manifest = read_package_manifest(tree);
    if manifest is not None and manifest.get("role") in (ROLE_LIB, ROLE_TEMPLATE) {
        return PackageIdentity(
            name=str(manifest.get("name", "")), version=str(manifest.get("version", ""))
        );
    }
    toml_path = tree / "jac.toml";
    if not toml_path.is_file() {
        raise ArtifactError(f"{tree}: a package needs a jac.toml at its root");
    }
    try {
        data = tomllib.loads(toml_path.read_text(encoding="utf-8"));
    } except tomllib.TOMLDecodeError as e {
        raise ArtifactError(f"{toml_path}: not valid TOML ({e})");
    }
    jacpack = data.get("jacpack");
    if isinstance(jacpack, dict) {
        return PackageIdentity(
            name=str(jacpack.get("name", "")), version=str(jacpack.get("version", ""))
        );
    }
    project = data.get("project", {});
    if not isinstance(project, dict) {
        raise ArtifactError(f"{toml_path}: [project] must be a table");
    }
    return PackageIdentity(
        name=str(project.get("name", "")), version=str(project.get("version", ""))
    );
}

def expect_identity(tree: Path, name: str, version: str = "") {
    found = read_identity(tree);
    if found.name != name {
        raise ArtifactError(
            f"{tree}: expected package '{name}' but its jac.toml names '{found.name}'"
        );
    }
    if version and found.version != version {
        raise ArtifactError(
            f"{tree}: expected {name} {version} but its jac.toml says {found.version}"
        );
    }
}

def rel_posix(path: Path, base: Path) -> str {
    return os.path.relpath(str(path), str(base)).replace(os.sep, "/");
}

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

def project_role(config: any) -> str {
    import from jaclang.project.package_scope { is_package_name }
    raw = config.get_section("jacpack");
    if raw is not None {
        return ROLE_TEMPLATE;
    }
    if is_package_name(config.project.name) {
        return ROLE_LIB;
    }
    return ROLE_APP;
}

def template_identity(config: any) -> PackageIdentity {
    raw = config.get_section("jacpack") or {};
    return PackageIdentity(
        name=str(raw.get("name", "")), version=str(raw.get("version", ""))
    );
}

def package_identity(config: any) -> PackageIdentity {
    if project_role(config) == ROLE_TEMPLATE {
        return template_identity(config);
    }
    return PackageIdentity(name=config.project.name, version=config.project.version);
}

def package_manifest(
    config: any, role: str, surface: dict[str, any]
) -> dict[str, any] {
    import from jaclang.compiler.driver.jir { jaclang_version }
    import from jaclang.packages.api { surface_digest }
    import from jaclang.packages.resolve { manifest_npm, manifest_pypi }
    ident = package_identity(config);
    manifest: dict[str, any] = {
        "format": PACKAGE_MANIFEST_FORMAT,
        "role": role,
        "name": ident.name,
        "version": ident.version,
        "description": config.project.description,
        "license": config.project.license,
        "jac_version": config.project.jac_version,
        "jaclang_version": jaclang_version()
    };
    if role == ROLE_LIB {
        manifest["exports"] = sorted(config.project.exports);
        manifest["deps"] = {
            name: dep.version for (name, dep) in sorted(config.dependencies.items())
        };
        manifest["pypi"] = manifest_pypi(config);
        manifest["npm"] = manifest_npm(config);
        manifest["api_digest"] = surface_digest(surface);
    }
    return manifest;
}

def read_package_manifest(tree: Path) -> dict[str, any] | None {
    import json;
    path = tree / MANIFEST_DIR / MANIFEST_FILE;
    if not path.is_file() {
        return None;
    }
    try {
        data = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return None;
    }
    return data if isinstance(data, dict) else None;
}

def build_package(config: any) -> BuiltPackage {
    import hashlib;
    import json;
    import from jaclang.packages.api { package_surface }
    if config.project_root is None {
        raise ArtifactError("building a package needs a project (jac.toml)");
    }
    base_root = Path(config.project_root);
    role = project_role(config);
    if role == ROLE_APP {
        raise ArtifactError(
            f"'{config.project.name}' is an app; a package needs a scoped "
            "[project] name (org/name) or a [jacpack] table"
        );
    }
    surface: dict[str, any] = {};
    if role == ROLE_LIB {
        if not config.project.exports {
            raise ArtifactError(
                "a library package lists the modules consumers may import under "
                "[project] exports"
            );
        }
        surface = package_surface(base_root, config.project.exports);
    }
    manifest = package_manifest(config, role, surface);
    stage = Path(tempfile.mkdtemp(prefix="jac-package-"));
    try {
        tree = stage / "pkg";
        stage_source_tree(base_root, tree);
        meta_dir = tree / MANIFEST_DIR;
        meta_dir.mkdir(parents=True, exist_ok=True);
        (meta_dir / MANIFEST_FILE).write_text(
            json.dumps(manifest, sort_keys=True, indent=1) + "\n", encoding="utf-8"
        );
        if surface {
            (meta_dir / API_FILE).write_text(
                json.dumps(surface, sort_keys=True, indent=1) + "\n", encoding="utf-8"
            );
        }
        data = tar_gz_dir(tree);
    } finally {
        shutil.rmtree(stage, ignore_errors=True);
    }
    return BuiltPackage(
        data=data,
        sha256=hashlib.sha256(data).hexdigest(),
        manifest=manifest,
        surface=surface
    );
}
