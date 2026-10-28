def read_iface_hash(section: (bytes | None)) -> (str | None);

def open_module_iface(
    section: bytes,
    pkg_dir: str,
    resolver: (CatalogResolver | None) = None,
    path_mapper: Callable[[str], str] | None = None
) -> (StubCatalog | None);

def iface_module(catalog: StubCatalog) -> (Module | None);
