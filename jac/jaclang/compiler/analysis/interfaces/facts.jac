obj InterfaceProduct {
    has data: bytes,
        digest: str;
}

class IncoherentInterface(RuntimeError) {
    has mod_path: str,
        orphans: list[str];

    def init(self: IncoherentInterface, mod_path: str, orphans: list[str]) {
        RuntimeError.__init__(
            self,
            f"interface of {mod_path} references {len(orphans)} class scope(s) "
            "with no live module: "
                + ", ".join(orphans)
        );
        self.mod_path = mod_path;
        self.orphans = list(orphans);
    }
}


import type from jaclang.compiler.session.cache.catalog_codec { PreparedCatalog }

obj CatalogRequest {
    has package_directory: str,
        key: str,
        files: list[tuple[str, str]],
        quiet: bool = False;
}

obj CatalogStatistics {
    has modules: int,
        scopes: int,
        symbols: int,
        types: int,
        shared: int,
        strings: int,
        evaluated: int,
        failures: int,
        failure_log: list[str];

    def as_dict -> dict[str, int | list[str]] {
        return {
            "modules": self.modules,
            "scopes": self.scopes,
            "symbols": self.symbols,
            "types": self.types,
            "shared": self.shared,
            "strings": self.strings,
            "evaluated": self.evaluated,
            "failures": self.failures,
            "failure_log": list(self.failure_log)
        };
    }
}

obj CatalogProduct {
    has prepared: PreparedCatalog,
        statistics: CatalogStatistics,
        load_failures: list[str];
}
