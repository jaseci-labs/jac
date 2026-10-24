import base64;
import json;

glob KERNEL_INPUTS_VERSION: int = 2,
     KEY_SEP: str = "\x1f";

obj RequestOptions {
    has symtab_ir_only: bool = False,
        no_cgen: bool = False,
        native_parity: bool = False,
        native_required: bool = False,
        native_require: list[str] = [],
        iface_ok: bool = False,
        need_full_ast: bool = False,
        native_tree_demand: bool = False,
        no_ir_cache: bool = False,
        resolve_annex_parent: bool = False,
        aot_mode: bool = False,
        native_unit: bool = False,
        kernel_build: bool = False,
        force_codespace: str = "",
        memory_profile: str = "managed",
        nogc_enforce_all: bool = False,
        memory_enforce: list[str] = [],
        memory_exempt: list[str] = [],
        native_target: str = "",
        suppress_codes: list[str] = [],
        default_codespace: str = "",
        app_kind: str = "",
        target_app: str = "",
        entry_point: str = "",
        ui: str = "",
        project_root: (str | None) = None,
        strict_dependencies: bool = False,
        package_canonical: bool = False,
        na_gc_mode: str = "",
        native_debug: bool = False,
        rc_debug_codegen: bool = False,
        rc_stats: bool = False,
        nogc_debug: bool = False,
        na_debug: bool = False,
        native_threads: int = -1,
        opt_level: int = -1;

    def to_options -> CompileOptions;
}

obj PythonInterface {
    has path: str,
        pkg_dir: str,
        data: bytes = b"",
        placement: str = "",
        effects: str = "";
}

obj ImportResolution {
    has target: str,
        base_path: str,
        string_spec: bool = False,
        path: str = "",
        language: str = "";

    def key -> str;
}

obj LocalResolution {
    has base: str,
        parts: list[str] = [],
        found: bool = False,
        path: str = "",
        language: str = "";

    def key -> str;
}

obj NpmAnswer {
    has spec: str,
        base_path: str,
        installed: bool = False,
        package_entry: (str | None) = None,
        declarations: (str | None) = None,
        entry_known: bool = False,
        declarations_known: bool = False;

    def key -> str;
}

obj DeclaredDependencies {
    has module_path: str,
        fallback_app: str = "",
        names: (list[str] | None) = None;

    def key -> str;
}

obj ManifestSets {
    has seed_paths: list[str] = [],
        native_only_files: list[str] = [],
        native_only_dirs: list[str] = [],
        native_lowered: list[str] = [];

    def is_seed(rel: str) -> bool;
    def is_native_only(rel: str) -> bool;
    def is_native_lowered(rel: str) -> bool;
}

obj KernelInputs {
    has version: int = KERNEL_INPUTS_VERSION,
        entry_path: str = "",
        package_root: str = "",
        module_projection: str = "",
        target_app: str = "",
        request: RequestOptions = RequestOptions(),
        project_defaults: (ProjectDefaults | None) = None,
        check_settings: dict[str, CheckSettings] = {},
        host_platform: HostPlatform = HostPlatform(),
        ct_environment: CtEnvironment = CtEnvironment(),
        target_triple: str = "",
        target_triple_known: bool = False,
        native_pipeline: bool = False,
        native_pipeline_reason: str = "",
        native_pipeline_known: bool = False,
        osp_core_js: str = "",
        client_stub_globals: list[str] = [],
        client_stub_globals_known: bool = False,
        stub_catalog_active: bool = False,
        stub_catalog_dir: str = "",
        stub_catalog_file: str = "",
        stub_catalog_offset: int = 0,
        stub_catalog_length: int = 0,
        typeshed_roots: list[str] = [],
        search_paths: list[str] = [],
        native_session_active: bool = False,
        scanned_modules: int = 0,
        emit_paths: list[str] = [],
        emit_closure: bool = False,
        emit_of: dict[str, bool] = {},
        manifest: ManifestSets = ManifestSets(),
        layout: LayoutTables = LayoutTables(),
        project_facts: dict[str, ProjectFacts] = {},
        workspaces: dict[str, WorkspaceSpec] = {},
        facts_of: dict[str, str] = {},
        workspace_of: dict[str, str] = {},
        app_of: dict[str, str] = {},
        project_root_of: dict[str, str] = {},
        lint_of: dict[str, LintSettings] = {},
        untyped: dict[str, bool] = {},
        siblings: dict[str, str] = {},
        client_pulls: dict[str, str] = {},
        native_ifaces: dict[str, str] = {},
        native_facts: dict[str, str] = {},
        path_aliases: dict[str, bool] = {},
        virtual_modules: dict[str, str] = {},
        imports: list[ImportResolution] = [],
        local_imports: list[LocalResolution] = [],
        npm: list[NpmAnswer] = [],
        declared: list[DeclaredDependencies] = [],
        python_ifaces: list[PythonInterface] = [];

    def to_json -> str;
    static def from_json(text: str) -> KernelInputs;
}

def resolution_key(target: str, base_path: str, string_spec: bool) -> str;

def local_key(base: str, parts: list[str]) -> str;

def pair_key(first: str, second: str) -> str;

def request_of(options: CompileOptions) -> RequestOptions;

def request_to_dict(request: RequestOptions) -> dict[str, any];

def request_from_dict(raw: dict[str, any]) -> RequestOptions;

def check_to_dict(check: CheckSettings) -> dict[str, any];

def check_from_dict(raw: dict[str, any]) -> CheckSettings;

def defaults_to_dict(defaults: ProjectDefaults) -> dict[str, any];

def defaults_from_dict(raw: dict[str, any]) -> ProjectDefaults;

def facts_to_dict(facts: ProjectFacts) -> dict[str, any];

def facts_from_dict(raw: dict[str, any]) -> ProjectFacts;

def lint_to_dict(lint: LintSettings) -> dict[str, any];

def lint_from_dict(raw: dict[str, any]) -> LintSettings;

def app_to_dict(app: AppSpec) -> dict[str, any];

def app_from_dict(raw: dict[str, any]) -> AppSpec;

def workspace_to_dict(ws: WorkspaceSpec) -> dict[str, any];

def workspace_from_dict(raw: dict[str, any]) -> WorkspaceSpec;

def layout_to_dict(layout: LayoutTables) -> dict[str, any];

def layout_from_dict(raw: dict[str, any]) -> LayoutTables;

def manifest_to_dict(manifest: ManifestSets) -> dict[str, any];

def manifest_from_dict(raw: dict[str, any]) -> ManifestSets;

def optional_list(raw: object) -> (list[str] | None);

def json_str_list(value: object) -> list[str];

def json_str_pairs(value: object) -> list[list[str]];

def json_str_map(value: object) -> dict[str, str];

def json_bool_map(value: object) -> dict[str, bool];

def json_map(value: object) -> dict[str, any];

def json_maps(value: object) -> list[dict[str, any]];

def json_int(value: object, fallback: int = 0) -> int;

def inputs_to_dict(inputs: KernelInputs) -> dict[str, any];

def answers_to_dict(inputs: KernelInputs) -> dict[str, any];

def json_opt_str(value: object) -> (str | None);

def merge_str_map(into: dict[str, str], value: object);

def merge_bool_map(into: dict[str, bool], value: object);

def merge_answers(inputs: KernelInputs, raw: dict[str, any]);

def inputs_from_dict(raw: dict[str, any]) -> KernelInputs;
