import hashlib;
import os;
import sys;

obj CatalogOrigin {
    has path: str,
        offset: int = 0,
        length: int = 0;
}

glob TYPE_SYSTEM_ROOTS: tuple[str, ...] = (
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
     _DIGEST_CACHE: list[str] = [],
     _CATALOG_CACHE: list[StubCatalog] = [],
     _OPENED_FROM: list[CatalogOrigin] = [],
     _ORIGIN: list[CatalogOrigin] = [];

def catalog_origin -> (CatalogOrigin | None);

def _opened(path: str, offset: int, length: int);

def jaclang_pkg_dir -> str;

def typeshed_stdlib_dir(pkg_dir: str) -> str;

def jac_internal_stub_dir(pkg_dir: str) -> str;

def _digest_files(pkg_dir: str) -> list[str];

def type_system_digest(pkg_dir: (str | None) = None) -> str;

def catalog_key(pkg_dir: (str | None) = None) -> str;

def bundled_catalog_path(pkg_dir: str) -> str;

def dev_catalog_path(pkg_dir: str) -> str;

def _open_file(path: str, pkg_dir: str) -> StubCatalog | None;

def _open_region(
    exe: str, offset: int, length: int, pkg_dir: str
) -> StubCatalog | None;

def _region_probe(exe: str, source: Source, pkg: str, check_key: bool) -> Probe;

def _file_probe(path: str, source: Source, pkg: str, check_key: bool) -> Probe;

obj StubcatArtifact(Artifact) {
    has name: str = "stubcat",
        kind: ArtifactKind = ArtifactKind.ACCELERATOR,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the stub catalog (pre-resolved typeshed types)",
        floor: str = "parsing the typeshed stubs",
        requires: list[str] = ["typeshed"];

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def probe_kit -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

obj TypeshedArtifact(Artifact) {
    has name: str = "typeshed",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.REQUIRED,
        summary: str = "the vendored typeshed stdlib stubs";

    override def probe_sealed -> (Probe | None);
    override def probe_checkout -> Probe;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def _typeshed_probe(source: Source, check_pin: bool) -> Probe;

def _read_trimmed(path: str) -> str;

def _publish(cat: StubCatalog | None) -> StubCatalog | None;

def open_catalog -> StubCatalog | None;

def reset_catalog_cache;
