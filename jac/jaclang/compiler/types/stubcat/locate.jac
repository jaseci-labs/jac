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

def type_system_digest(pkg_dir: (str | None) = None) -> str {
    import from jaclang.image { load_image }
    package = pkg_dir if pkg_dir is not None else jaclang_pkg_dir();
    image = load_image(os.path.join(package, "_precompiled"));
    if image is None {
        raise StubCatalogUnavailable(
            "The stub catalog requires a compiled compiler image"
        );
    }
    digest = image.manifest.get("compiler_digest");
    if not isinstance(digest, str) or not digest {
        raise StubCatalogUnavailable("The compiler image has no identity");
    }
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
        if cat is not None {
            return cat;
        }
    }
    bundled = bundled_catalog_path(pkg);
    if os.path.isfile(bundled) {
        cat = _open_file(bundled, pkg);
        if cat is not None {
            return cat;
        }
    }
    return None;
}

def _publish(cat: StubCatalog | None) -> StubCatalog | None {
    import from jaclang.compiler.types.stubcat.state { set_active }
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
    raise StubCatalogUnavailable(
        "The compiler image has no readable typeshed catalog. "
        "Rebuild it with 'zig build compiler-image' or reinstall the Jac binary."
    );
}

def reset_catalog_cache {
    import from jaclang.compiler.types.stubcat.state { set_active }
    _CATALOG_CACHE.clear();
    set_active(None);
}
