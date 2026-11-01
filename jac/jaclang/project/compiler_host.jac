"""The kernel's host services: the one implementation that answers the
compiler's questions about the world. It runs inside the kernel and reads the
project, the file system and the caches itself; nothing is asked of the
process that loaded the kernel."""
import gc;
import hashlib;
import os;
import platform;
import sys;
import from contextlib { contextmanager }
import from pathlib { Path }

glob UNIT_COLLECT_EVERY: int = 16,
     UNIT_COLLECT_GROWTH_MB: int = 512,
     COMPILER_PACKAGE_NAME: str = "jaclang",
     OTHER_COMPILER_MARKER: str = "compiler/kernel_api.jac",
     _OTHER_COMPILER_DIRS: dict[str, str] = {};

obj UnitCollectBudget {
    has releases: int = 0,
        last_peak_mb: int = 0;

    def due -> bool;
}

obj HostSession(SessionHooks) {
    has host: ProjectHost,
        closure: (CompileOptions | None) = None;

    def closure_options -> (CompileOptions | None);
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module;
}

obj ProjectHost(HostServices) {
    has root: str = "",
        overlay: dict[str, str] = {},
        closure: (CompileOptions | None) = None,
        analyses: dict[str, ModuleAnalysis] = {},
        units: dict[str, UnitProducts] = {},
        grown: set[str] = set(),
        source_reads: dict[str, str] = {},
        _defaults_active: bool = False,
        _last_defaults: (ProjectDefaults | None) = None,
        _facts: dict[str, ProjectFacts] = {},
        _stub_globals: list[str] = [],
        _collect_budget: UnitCollectBudget = UnitCollectBudget(),
        _platform: (HostPlatform | None) = None,
        _native_ifaces: dict[str, NativeIface] = {},
        _lowering: set[str] = set(),
        _lowered: dict[str, Module] = {},
        _session: (HostSession | None) = None;

    def postinit;
    def close_over(options: CompileOptions);
    def record_unit(task: ModuleAnalysis);
    def forget_unit(path: str);
    def project_config(path: str = "") -> JacConfig;
    @contextmanager
    def session -> Iterator[None];

    def project_defaults -> (ProjectDefaults | None);
    def check_settings(target_app: str) -> CheckSettings;
    def project_facts(path: str) -> (ProjectFacts | None);
    def lint_settings(path: str) -> LintSettings;
    def workspace(path: str) -> (WorkspaceSpec | None);
    def app_for_path(path: str) -> (AppSpec | None);
    def project_root(path: str) -> (str | None);
    def resolve_module(
        target: str, base_path: str, string_spec: bool = False
    ) -> tuple[str, str];

    def resolve_local_module(base: str, parts: list[str]) -> (tuple[str, str] | None);
    def jac_virtual_module_path(target: str) -> (str | None);
    def is_path_alias(target: str, base_path: str) -> bool;
    def is_untyped_third_party(path: str) -> bool;
    def in_typeshed_tree(path: str) -> bool;
    def sibling_declaration(js_path: str) -> (str | None);
    def client_pulls(path: str) -> str;
    def native_dep_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (NativeIface | None);

    def native_dep_discovery_open(program: JacProgram) -> bool;
    def native_deps_deferred(program: JacProgram) -> bool;
    def held_native_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> str;

    def lower_dependency(
        program: JacProgram, real: str, options: CompileOptions
    ) -> (NativeIface | None);

    def native_lowering_failed(program: JacProgram, path: str, detail: str);
    def native_fact(kind: str, key: str) -> str;
    def save_native_debug_ir(path: str, text: str);
    def has_npm_package(spec: str, base_path: str) -> bool;
    def resolve_npm_package(spec: str, base_path: str) -> (str | None);
    def npm_declarations(spec: str, base_path: str) -> (str | None);
    def declared_dependencies(
        module_path: str, fallback_app: str
    ) -> (list[str] | None);

    def native_pipeline_available -> tuple[bool, str];
    def note(message: str, style: str = "dim");
    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None);
    def ct_environment -> CtEnvironment;
    def host_platform -> HostPlatform;
    def path_facts(path: str) -> PathFacts;
    def read_source(path: str) -> str;
    def annex_files(path: str, suffix: str = ".impl.jac") -> list[str];
    def base_file(annex_path: str) -> (str | None);
    def is_annex_path_of(candidate: str, base: str) -> bool;
    def package_init(directory: str) -> (str | None);
    def wiring_file(path: str) -> (str | None);
    def is_seed_source(rel_path: str) -> bool;
    def wiring_records(digest: str) -> str;
    def keep_wiring_records(digest: str, text: str);
    def native_scan_record(path: str, digest: str) -> str;
    def keep_native_scan_record(path: str, digest: str, text: str);
    def woven_module(path: str, program: (JacProgram | None)) -> (Module | None);
    def place_wired_imports(module: Module);
    def drop_python_lane_products(path: str, program: JacProgram);
    def compiler_for(program: JacProgram) -> JacCompiler;
    def iface_registry_for(program: JacProgram) -> IfaceRegistry;
    def native_units_for(program: JacProgram) -> NativeUnitRegistry;
    def client_boundary_facts(program: JacProgram, path: str) -> (list[str] | None);
    def schedule_import_failed(err: ImportError);
    def client_osp_core_js -> str;
    def client_stub_globals -> list[str];
    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None);

    def format_file(file_path: str, auto_lint: bool = False) -> JacProgram;
    def format_source(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram;

    def lint_file(file_path: str) -> JacProgram;
    def compile_module(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module;

    def build_module(
        program: JacProgram, file_path: str, use_str: (str | None)
    ) -> Module;

    def run_module_pipeline(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module;

    def native_session_active(program: JacProgram) -> bool;
    def bind_context_program(context_root: JacProgram, program: JacProgram);
    def note_program_dependency(program: JacProgram, resolved_path: str);
    def forget_program_products(program: JacProgram, resolved_path: str);
    def release_program_products(program: JacProgram, retain_stubs: bool);
    def prepare_interface(program: JacProgram, path: str, module: Module) -> bool;
    def collect_released_memory;
    def load_modules(names: list[str]);
    def module_in_flight(names: list[str]) -> str;
    def has_active_stub_catalog -> bool;
    def typeshed_unavailable_reason -> str;
    def is_native_only_source(rel: str) -> bool;
    def is_native_lowered_source(rel: str) -> bool;
    def default_target_triple -> str;
}

def check_settings_of(check: CheckConfig) -> CheckSettings;

def project_defaults_of(cfg: JacConfig) -> ProjectDefaults;

def package_name_of(name: str) -> str;

def other_compiler_root(path: str) -> str;

def peak_rss_mb -> int;

def wiring_records_path(digest: str) -> str;

def native_scan_path(path: str, digest: str) -> str;

def write_record(path: str, text: str);
