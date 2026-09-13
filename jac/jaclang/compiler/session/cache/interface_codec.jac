import from collections.abc { Callable }
import hashlib;
import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.session.cache.catalog_reader {
    StubCatalog,
    CatalogResolver
}
import from jaclang.compiler.session.cache.catalog_codec {
    PreparedCatalog,
    encode_catalog
}

glob IFACE_HASH_LEN: int = 64;

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
    resolver: CatalogResolver | None = None,
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

def encode_interface(prepared: PreparedCatalog) -> bytes {
    body = encode_catalog(prepared);
    return hashlib.sha256(body).hexdigest().encode('ascii') + body;
}
