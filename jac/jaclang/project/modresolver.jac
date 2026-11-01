import os;
import from pathlib { Path }

glob _project_root_cache: dict[str, str | None] = {},
     _import_base_stack: list[str] = [],
     COMPILER_PACKAGE: str = 'jaclang';

obj SearchRoots {
    has interpreter: list[str] = [],
        editable: dict[str, str] = {},
        sites: list[str] = [];
}

obj PythonModuleSite {
    has origin: str = "",
        namespace_dirs: list[str] = [];
}

obj PythonProbe {
    has origin: str = "",
        package_dir: str = "",
        namespace_dir: str = "";
}

obj JacVirtualModule {
    has name: str,
        path: str = "",
        exports: list[str] = [];
}

glob _SEARCH_ROOTS: list[SearchRoots] = [],
     _STUB_CATALOG: list[StubCatalog] = [],
     _DECLARED_VIRTUAL: dict[str, JacVirtualModule] = {},
     _DECLARED_SCANNED: list[bool] = [],
     JAC_VIRTUAL_PREFIX: str = '@jac/',
     JAC_MODULES_GROUP: str = 'jac.modules',
     JAC_MODULE_EXPORTS_GROUP: str = 'jac.module_exports',
     EDITABLE_FINDER_PREFIX: str = '__editable___',
     EDITABLE_FINDER_SUFFIX: str = '_finder.py',
     PY_SOURCE_SUFFIXES: tuple[str, ...] = ('.py', '.pyi'),
     PY_EXTENSION_SUFFIXES: tuple[str, ...] = ('.so', '.pyd'),
     SITE_DIR_NAMES: tuple[str, ...] = ('site-packages', 'dist-packages'),
     WALK_SKIP_DIRS: tuple[str, ...] = ('__pycache__', 'node_modules'),
     JAC_VIRTUAL_MODULE_SOURCES: dict[str, str] = {
         "mobui": "client_mobui",
         "pwa": "pwa_runtime",
         "wasm_host": "wasm_host",
         "webgl": "webgl"
     };

def install_search_roots(interpreter_paths: list[str]);

def search_roots -> SearchRoots;

def editable_mappings(site_dir: str) -> dict[str, str];

def quoted_strings(text: str) -> list[str];

def editable_mapping_of(finder_path: str) -> dict[str, str];

def use_stub_catalog(catalog: (StubCatalog | None));

def active_stub_catalog -> (StubCatalog | None);

def push_import_base(base_dir: str);

def pop_import_base;

def probe_python_root(root: str, name: str) -> PythonProbe;

def find_python_module(parts: list[str]) -> (PythonModuleSite | None);

def find_project_root(start: (Path | None) = None) -> (tuple[Path, Path] | None);

def find_jac_project_root(start: (str | None) = None) -> (str | None);

glob _mounts_by_root: dict[str, tuple[str, str]] = {},
     _self_mounted: set[str] = set(),
     MOUNTS_DIR_NAME: str = 'packages';

def is_scoped_package_name(name: str) -> bool;

def _ensure_self_mount(mounts: str, name: str, project_root: str);

def _mounts_entry(project_root: str) -> tuple[str, str];

def project_mounts_dir(project_root: str) -> str;

def enclosing_mounts(project_root: str) -> (str | None);

def project_mounts(project_root: str) -> (str | None);

def module_name_in(root_dir: str, path: str) -> (str | None);

def get_jac_search_paths(base_path: (str | None) = None) -> list[str];

def required_package_root -> str;

def language_of(path: str) -> str;

def module_suffixes -> list[str];

def subtree_has_jac(directory: str) -> bool;

def is_jac_namespace_package(directory: str) -> bool;

glob _CASE_BLIND_FS: list[bool] = [];

def case_blind_filesystem -> bool;

def named_exactly_any(candidate: str) -> bool;

def resolve_local_module(base: str, parts: list[str]) -> (tuple[(str, str)] | None);

def _namespace_candidate(base: str, parts: list[str]) -> (tuple[(str, str)] | None);

def _self_tree_candidate(
    base_dir: str, actual_parts: list[str]
) -> (tuple[(str, str)] | None);

def virtual_module_basenames(module_name: str) -> list[str];

def parse_entry_points(text: str) -> dict[str, dict[str, str]];

def declared_virtual_modules -> dict[str, JacVirtualModule];

def _resolve_jac_virtual_module(target: str) -> (tuple[(str, str)] | None);

def resolve_jac_virtual_module_path(target: str) -> (str | None);

def resolve_jac_virtual_module_exports(target: str) -> list[str];

def _get_path_aliases -> dict[str, str];

def _resolve_path_alias(target: str, base_path: str) -> (str | None);

def is_path_alias_import(target: str, base_path: str) -> bool;

def _find_under(directory: str, file_names: list[str]) -> (str | None);

def resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[(str, str)];

def infer_language(target: str, base_path: str, string_spec: bool = False) -> str;

def resolve_relative_path(
    target: str, base_path: str, string_spec: bool = False
) -> str;

glob NPM_RUNTIME_CONDITIONS: tuple[str, ...] = (
         'browser',
         'module',
         'import',
         'default'
     ),
     NPM_TYPES_CONDITIONS: tuple[str, ...] = ('types', 'import', 'default'),
     NPM_DTS_SUFFIXES: tuple[str, ...] = ('.d.ts', '.d.mts', '.d.cts');

obj NpmExport {
    has path: str = "",
        targets: list[NpmExport] = [],
        conditions: list[tuple[str, NpmExport]] = [],
        subpaths: list[tuple[str, NpmExport]] = [];
}

obj NpmPackageJson {
    has module: str = "",
        main: str = "",
        types: str = "",
        typings: str = "",
        exports: (NpmExport | None) = None;
}

def _find_npm_package(
    spec: str, base_path: str
) -> (tuple[(str, list[str], str)] | None);

def npm_text(value: object) -> str;

def npm_export_of(value: object) -> NpmExport;

def _read_package_json(pkg_dir: str) -> NpmPackageJson;

def _resolve_export_target(
    target: NpmExport,
    conditions: tuple[str, ...],
    pkg_dir: str,
    star_sub: (str | None) = None
) -> (str | None);

def _resolve_pkg_exports(
    exports: NpmExport, subpath: str, conditions: tuple[str, ...], pkg_dir: str
) -> (str | None);

def has_client_npm_package(spec: str, base_path: str) -> bool;

def resolve_client_npm_package(spec: str, base_path: str) -> (str | None);

def resolve_client_npm_declarations(spec: str, base_path: str) -> (str | None);

def _resolve_at_types_declarations(
    spec: str, subpath: list[str], node_modules: str
) -> (str | None);

def sibling_declaration_file(js_path: str) -> (str | None);

def _npm_file_with_ext(candidate: str) -> (str | None);

def _npm_package_entry(pkg_dir: str, data: NpmPackageJson) -> (str | None);

def get_typeshed_paths -> list[str];

def in_typeshed_tree(path: str) -> bool;

def in_native_library(path: str) -> bool;

def _stub_catalog_active -> bool;

def _candidate_from_stub_catalog(parts: list[str]) -> (tuple[(str, str)] | None);

def _candidate_from_typeshed(
    base: str, parts: list[str]
) -> (tuple[(str, str)] | None);

def _candidate_from_stub_package(
    base: str, parts: list[str]
) -> (tuple[(str, str)] | None);

def is_untyped_third_party_module(path: str) -> bool;
