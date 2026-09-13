import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import hashlib;
import os;
import sys;
import from jaclang.compiler.types.stubcat.format { FORMAT_VERSION }

glob ENV_FILE: str = "JAC_STUBCAT_FILE",
     ENV_OFF: str = "JAC_STUBCAT_OFF",
     ENV_LEN: str = "JAC_STUBCAT_LEN",
     ENV_BUILDING: str = "JAC_STUBCAT_BUILDING",
     _CATALOG_CACHE: list[StubCatalog] = [];

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

def type_system_digest(pkg_dir: str | None = None) -> str {
    import from pathlib { Path }
    import from jaclang.compiler.driver.jir {
        compiler_source_digest,
        compute_content_sha256
    }
    pkg = Path(pkg_dir or jaclang_pkg_dir());
    digest = hashlib.sha256(compiler_source_digest(str(pkg)).encode());
    # Compiler logic has one authority; add the actual data consumed by the catalog.
    for input_dir in [pkg / "compiler/types", pkg / "vendor/typeshed"] {
        for path in sorted(input_dir.rglob("*")) {
            if not path.is_file()
                or (path.suffix != ".pyi" and path.name not in ("PIN", "VERSIONS")) {
                continue;
            }
            digest.update(path.relative_to(pkg).as_posix().encode());
            digest.update(compute_content_sha256(str(path)).encode());
        }
    }
    return digest.hexdigest();
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

def _open_file(path: str, pkg_dir: str) -> StubCatalog | None {
    import from jaclang.compiler.types.stubcat.reader { open_catalog_file }
    try {
        return open_catalog_file(path, pkg_dir);
    } except Exception as e {
        sys.stderr.write(f"jac: ignoring unreadable stub catalog {path}: {e}\n");
        return None;
    }
}

def _open_region(
    exe: str, offset: int, length: int, pkg_dir: str
) -> StubCatalog | None {
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
    previous = os.environ.get(ENV_BUILDING);
    os.environ[ENV_BUILDING] = "1";
    try {
        import from jaclang.compiler.types.stubcat.build { build_catalog }
        build_catalog(path, pkg_dir=pkg_dir, quiet=True);
    } finally {
        if previous is None {
            os.environ.pop(ENV_BUILDING, None);
        } else {
            os.environ[ENV_BUILDING] = previous;
        }
    }
}

def _current_for_source(cat: StubCatalog, pkg: str) -> bool {
    if not os.environ.get("JAC_DEV_SOURCE") {
        return True;
    }
    try {
        return cat.key() == catalog_key(pkg);
    } except Exception {
        return False;
    }
}

def _find_catalog -> StubCatalog | None {
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

def _publish(cat: StubCatalog | None) -> StubCatalog | None {
    import from jaclang.jac0core.stubcat_hook { set_active }
    if cat is not None and not _CATALOG_CACHE {
        _CATALOG_CACHE.append(cat);
        set_active(cat);
    }
    return cat;
}

def open_catalog -> StubCatalog | None {
    if os.environ.get(ENV_BUILDING) {
        return None;
    }
    if _CATALOG_CACHE {
        return _CATALOG_CACHE[0];
    }
    return _publish(_find_catalog());
}

def ensure_catalog -> StubCatalog | None {
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
    set_active(None);
}
