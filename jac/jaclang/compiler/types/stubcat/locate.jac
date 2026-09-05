import hashlib;
import os;
import sys;
import from jaclang.compiler.types.stubcat.format { FORMAT_VERSION }

glob ENV_FILE: str = "JAC_STUBCAT_FILE",
     ENV_OFF: str = "JAC_STUBCAT_OFF",
     ENV_LEN: str = "JAC_STUBCAT_LEN",
     ENV_BUILDING: str = "JAC_STUBCAT_BUILDING",
     TYPE_SYSTEM_ROOTS: tuple[str, ...] = (
         "compiler/types",
         "compiler/passes/pyast_load_pass.jac",
         "compiler/passes/impl/pyast_load_pass.impl.jac",
         "compiler/passes/sym_tab_build_pass.jac",
         "compiler/passes/impl/sym_tab_build_pass.impl.jac",
         "compiler/frontend/unitree.jac",
         "compiler/frontend/helpers.jac",
         "compiler/symbol_utils.jac",
         "vendor/typeshed/PIN"
     ),
     DIGEST_SUFFIXES: tuple[str, ...] = (".jac", ".pyi", ".py", "PIN"),
     _DIGEST_CACHE: list = [],
     _CATALOG_CACHE: list = [];

def jaclang_pkg_dir -> str {
    import jaclang;
    return os.path.dirname(os.path.realpath(str(jaclang.__file__)));
}

def typeshed_stdlib_dir(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "vendor", "typeshed", "stdlib");
}

def jac_internal_stub_dir(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "compiler", "types");
}

def _digest_files(pkg_dir: str) -> list[str] {
    rels: list[str] = [];
    for root_entry in TYPE_SYSTEM_ROOTS {
        target = os.path.join(pkg_dir, *root_entry.split("/"));
        if os.path.isfile(target) {
            rels.append(root_entry);
            continue;
        }
        if not os.path.isdir(target) {
            continue;
        }
        for (walk_dir, dirs, files) in os.walk(target) {
            dirs[:] = sorted(
                d
                for d in dirs
                if not d.startswith(".")
                    and d not in ("__pycache__", "tests", "fixtures")
            );
            for name in sorted(files) {
                if not name.endswith(DIGEST_SUFFIXES) or ".test." in name {
                    continue;
                }
                rel = os.path.relpath(os.path.join(walk_dir, name), pkg_dir);
                rels.append(rel.replace(os.sep, "/"));
            }
        }
    }
    return sorted(rels);
}

def type_system_digest(pkg_dir: (str | None) = None) -> str {
    if _DIGEST_CACHE {
        return _DIGEST_CACHE[0];
    }
    pkg = pkg_dir or jaclang_pkg_dir();
    h = hashlib.sha256();
    for rel in _digest_files(pkg) {
        h.update(rel.encode());
        try {
            with open(os.path.join(pkg, *rel.split("/")), "rb") as f {
                h.update(hashlib.sha256(f.read()).digest());
            }
        } except OSError {
            h.update(b"?");
        }
    }
    digest = h.hexdigest();
    _DIGEST_CACHE.append(digest);
    return digest;
}

def catalog_key(pkg_dir: (str | None) = None) -> str {
    h = hashlib.sha256();
    h.update(f"stubcat-format={FORMAT_VERSION}".encode());
    h.update(f"|python={sys.version_info.major}.{sys.version_info.minor}".encode());
    h.update(f"|platform={sys.platform}".encode());
    h.update(("|types=" + type_system_digest(pkg_dir)).encode());
    return h.hexdigest()[:32];
}

def bundled_catalog_path(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "_precompiled", "stubcat.bin");
}

def dev_catalog_path(pkg_dir: str) -> str {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir }
    return os.path.join(
        str(get_jir_cache_dir()), "stubcat", catalog_key(pkg_dir) + ".bin"
    );
}

def _open_file(path: str, pkg_dir: str) -> any {
    import from jaclang.compiler.types.stubcat.reader { open_catalog_file }
    try {
        return open_catalog_file(path, pkg_dir);
    } except Exception as e {
        sys.stderr.write(f"jac: ignoring unreadable stub catalog {path}: {e}\n");
        return None;
    }
}

def _open_region(exe: str, offset: int, length: int, pkg_dir: str) -> any {
    import from jaclang.compiler.types.stubcat.reader { open_catalog_region }
    try {
        return open_catalog_region(exe, offset, length, pkg_dir);
    } except Exception as e {
        sys.stderr.write(f"jac: ignoring unreadable embedded stub catalog: {e}\n");
        return None;
    }
}

class StubCatalogUnavailable(RuntimeError) {}

def _build_dev_catalog(path: str, pkg_dir: str) {
    sys.stderr.write(
        "jac: building the stub catalog (one-time per type-system change)...\n"
    );
    sys.stderr.flush();
    os.environ[ENV_BUILDING] = "1";
    try {
        import from jaclang.compiler.types.stubcat.build { build_catalog }
        build_catalog(path, pkg_dir=pkg_dir, quiet=True);
    } finally {
        os.environ.pop(ENV_BUILDING, None);
    }
}

def _current_for_source(cat: any, pkg: str) -> bool {
    if not os.environ.get("JAC_DEV_SOURCE") {
        return True;
    }
    try {
        return cat.key() == catalog_key(pkg);
    } except Exception {
        return True;
    }
}

def _find_catalog -> any {
    pkg = jaclang_pkg_dir();
    explicit = os.environ.get(ENV_FILE, "");
    if explicit {
        return _open_file(explicit, pkg);
    }
    off = os.environ.get(ENV_OFF, "");
    length = os.environ.get(ENV_LEN, "");
    if off and length {
        exe = os.environ.get("JAC_EXECUTABLE", "") or sys.executable;
        cat = _open_region(exe, int(off), int(length), pkg);
        if cat is not None and _current_for_source(cat, pkg) {
            return cat;
        }
    }
    bundled = bundled_catalog_path(pkg);
    if os.path.isfile(bundled) {
        cat = _open_file(bundled, pkg);
        if cat is not None and _current_for_source(cat, pkg) {
            return cat;
        }
    }
    dev = dev_catalog_path(pkg);
    if os.path.isfile(dev) {
        return _open_file(dev, pkg);
    }
    return None;
}

def _publish(cat: any) -> any {
    import from jaclang.jac0core.stubcat_hook { set_active }
    if cat is not None and not _CATALOG_CACHE {
        _CATALOG_CACHE.append(cat);
        set_active(cat);
    }
    return cat;
}

def open_catalog -> any {
    if os.environ.get(ENV_BUILDING) {
        return None;
    }
    if _CATALOG_CACHE {
        return _CATALOG_CACHE[0];
    }
    return _publish(_find_catalog());
}

def ensure_catalog -> any {
    cat = open_catalog();
    if cat is not None or os.environ.get(ENV_BUILDING) {
        return cat;
    }
    pkg = jaclang_pkg_dir();
    if not os.path.isfile(os.path.join(typeshed_stdlib_dir(pkg), "builtins.pyi")) {
        raise StubCatalogUnavailable(
            "no stub catalog is available and this checkout has no vendored "
            "typeshed sources to build one from. In a source checkout run "
            "'zig build fetch-typeshed'; in an installed environment reinstall "
            "the jac distribution, whose payload carries the catalog."
        );
    }
    dev = dev_catalog_path(pkg);
    _build_dev_catalog(dev, pkg);
    cat = _publish(_open_file(dev, pkg));
    if cat is None {
        raise StubCatalogUnavailable(
            f"the stub catalog build produced no readable catalog at {dev}"
        );
    }
    return cat;
}

def reset_catalog_cache {
    import from jaclang.jac0core.stubcat_hook { set_active }
    _CATALOG_CACHE.clear();
    _DIGEST_CACHE.clear();
    set_active(None);
}
