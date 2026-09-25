import os;
import from pathlib { Path }
import from jaclang.project.modresolver {
    MOUNTS_DIR_NAME,
    is_scoped_package_name,
    module_name_in
}

glob STORE_BUCKET: str = "pkgs";

def is_package_name(name: str) -> bool {
    return is_scoped_package_name(name);
}

def import_prefix(name: str) -> str {
    return name.replace("/", ".");
}

def store_root -> Path {
    import from jaclang.cache.registry { bucket }
    return bucket(STORE_BUCKET).path();
}

def in_store(path: str) -> bool {
    real = os.path.realpath(path);
    store_dir = os.path.realpath(str(store_root()));
    return real.startswith(store_dir + os.sep);
}

def declared_package_name(project_root: str) -> str {
    import from jaclang.project.config { get_config_for_dir }
    cfg = get_config_for_dir(project_root);
    return cfg.project.name if cfg is not None else "";
}

def package_root_of(path: str) -> (str | None) {
    import from jaclang.project.modresolver { find_jac_project_root }
    pkg_dir = find_jac_project_root(path);
    if pkg_dir is None or not is_package_name(declared_package_name(pkg_dir)) {
        return None;
    }
    return pkg_dir;
}

def is_dependency_module(path: str, owner_root: (str | None)) -> bool {
    if in_store(path) {
        return True;
    }
    pkg_dir = package_root_of(path);
    if pkg_dir is None {
        return False;
    }
    if not owner_root {
        return True;
    }
    return os.path.realpath(pkg_dir) != os.path.realpath(owner_root);
}

def mounts_dir(build_dir: Path) -> Path {
    return build_dir / MOUNTS_DIR_NAME;
}


def package_exports(project_root: str) -> list[str] {
    import from jaclang.project.config { get_config_for_dir }
    cfg = get_config_for_dir(project_root);
    return list(cfg.project.exports) if cfg is not None else [];
}

def is_exported(module: str, exports: list[str]) -> bool {
    import fnmatch;
    for pattern in exports {
        if module == pattern or fnmatch.fnmatchcase(module, pattern) {
            return True;
        }
    }
    return False;
}
