import os;
import sys;
import type from jaclang.compiler.session.cache.catalog_reader { StubCatalog }
import from jaclang.compiler.session.cache.catalog_paths {
    ENV_BUILDING,
    StubCatalogUnavailable,
    open_catalog,
    jaclang_pkg_dir,
    typeshed_stdlib_dir,
    dev_catalog_path,
    _publish,
    _open_file
}

def _build_dev_catalog(path: str, pkg_dir: str) {
    sys.stderr.write(
        "jac: building the stub catalog (one-time per type-system change)...\n"
    );
    sys.stderr.flush();
    os.environ[ENV_BUILDING] = "1";
    try {
        import from jaclang.compiler.bootstrap.catalog { build_catalog }
        build_catalog(path, pkg_dir=pkg_dir, quiet=True);
    } finally {
        os.environ.pop(ENV_BUILDING, None);
    }
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
