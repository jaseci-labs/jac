import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.types.stubcat.format { IFACE_HASH_LEN }
import from jaclang.compiler.types.stubcat.reader { StubCatalog }
import from jaclang.compiler.types.stubcat.resolver { CatalogResolver }

def read_iface_hash(section: (bytes | None)) -> (str | None) {
    if section is None or len(section) <= IFACE_HASH_LEN {
        return None;
    }
    try {
        return section[:IFACE_HASH_LEN].decode("ascii");
    } except Exception {
        return None;
    }
}

def open_module_iface(
    section: bytes,
    pkg_dir: str,
    resolver: (CatalogResolver | None) = None,
    path_mapper: Callable[[str], str] | None = None
) -> (StubCatalog | None) {
    if len(section) <= IFACE_HASH_LEN {
        return None;
    }
    try {
        return StubCatalog(
            buf=section[IFACE_HASH_LEN:],
            pkg_dir=pkg_dir,
            resolver=resolver,
            path_mapper=path_mapper
        );
    } except ValueError {
        return None;
    }
}

def iface_module(catalog: StubCatalog) -> (Module | None) {
    return catalog.module_by_id(0);
}
