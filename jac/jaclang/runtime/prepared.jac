import hashlib;
import os;
import types;

obj ModuleIndex {
    has size: tuple[int, int],
        names: dict[str, str] = {},
        packages: set[str] = set(),
        sources: dict[str, str] = {};
}

obj PreparedApplication {
    has `root: str,
        `entry: str,
        code: dict[str, types.CodeType] = {},
        manifests: dict[str, dict[str, any]] = {},
        semantic: dict[str, dict[str, Info]] = {},
        origins: dict[str, str] = {},
        persistence_modules: dict[str, str] = {},
        persistence_namespaces: set[str] = set(),
        name: str = '',
        namespace: str = '',
        scope_imports: bool = True,
        client_compiler: ViteCompiler | None = None,
        client_enabled: bool = False,
        native: dict[str, tuple[object | None, dict[str, object] | None]] = {},
        services: tuple[str, ...] = (),
        dev: bool = True,
        client_dist: str = "",
        applications: list[PreparedApplication] = [],
        index: ModuleIndex | None = None,
        sources: list[str] = [];
}

glob _applications: dict[str, PreparedApplication] = {},
     _realpaths: dict[str, str] = {};

def _realpath(path: str) -> str;

def publish(application: PreparedApplication);

def application_for(path: str, module_name: str = "") -> (PreparedApplication | None);

def application_of(target: object) -> PreparedApplication | None;

def prepared_code(path: str) -> (types.CodeType | None);

def prepared_manifest(path: str) -> (dict[str, any] | None);

def forget(`entry: str);

glob NON_APPLICATION_DIRS: tuple[str, ...] = (
         'node_modules',
         'venv',
         '__pycache__',
         'site-packages'
     );

def holds_application_code(relative_path: str) -> bool;

def containing_application(
    path: str, module_name: str = ""
) -> (PreparedApplication | None);

def load_prepared_module(
    path: str, application: PreparedApplication | None = None, as_main: bool = False
) -> types.ModuleType;

def initialize_application(
    application: PreparedApplication, config: any = None, served: any = None
) -> types.ModuleType;

def clear;


def application_namespace(application: PreparedApplication) -> str;

def ensure_namespace(application: PreparedApplication, name: str = '') -> str;

def relative_module(path: str, application: PreparedApplication) -> str;

def qualified_module(path: str, application: PreparedApplication) -> str;

def module_index(application: PreparedApplication) -> ModuleIndex;

def import_prepared(path: str, application: PreparedApplication) -> types.ModuleType;

def entry_alias(fullname: str) -> tuple[str, str] | None;

def module_builtins(application: PreparedApplication, source: str) -> dict[str, any];

def execute_module(module: types.ModuleType, application: PreparedApplication);

def semantic_for_scope(scope: str) -> Info | None;


def origin_for_source(path: str) -> str;

def source_for_origin(application: PreparedApplication, origin: str) -> str;
