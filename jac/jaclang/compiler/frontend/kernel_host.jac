import json;
import os;
import sys;
import from contextlib { contextmanager }

glob _CATALOGS: dict[str, StubCatalog] = {};

glob HOST_ONLY_ANSWER: str = "host_only",
     EMIT_QUESTION: str = "emit_unit",
     EVENT_NOTE: str = "note",
     EVENT_COVERAGE: str = "coverage";

class HostOnlyError(RuntimeError) {}

obj HostAsker {
    def ask(method: str, key: str) -> str abst;
    def record_interface(program: JacProgram, module: Module, products: UnitProducts);
}

enum HostEventKind { NOTE, COVERAGE, COLLECT }

obj HostEvent {
    has kind: HostEventKind,
        path: str = "",
        text: str = "",
        code: str = "",
        detail: str = "";
}

obj HostCensus {
    has trace: bool = False,
        entry_path: str = "",
        sessions: int = 0,
        snapshot_seconds: float = 0.0,
        scanned_modules: int = 0,
        calls: dict[str, int] = {},
        misses: dict[str, int] = {},
        miss_keys: list[str] = [],
        delegated: dict[str, int] = {},
        buffered: dict[str, int] = {};

    def count(method: str);
    def miss(method: str, key: str);
    def delegate(method: str);
    def buffer(method: str);
    def total_misses -> int;
    def merge(other: HostCensus);
    def summary -> str;
}

obj HostTurn {
    has host: HostServices,
        previous: (HostServices | None) = None;

    def __enter__ -> HostServices;
    def __exit__(exc_type: any, exc: any, trace: any) -> bool;
}

obj KernelSession(SessionHooks) {
    has host: KernelHost,
        closure: (CompileOptions | None) = None;

    def closure_options -> (CompileOptions | None);
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module;
}

obj ProgramResolver(CatalogResolver) {
    has program: JacProgram;

    def resolve_module(path: str) -> (Module | None);
    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> (ClassDetailsShared | None);
}

obj ServedInterface {
    has catalog: StubCatalog,
        module: Module;
}

obj KernelHost(HostServices) {
    has inputs: KernelInputs,
        fallback: (HostServices | None) = None,
        loader: (HostServices | None) = None,
        closure: (CompileOptions | None) = None,
        census: HostCensus = HostCensus(),
        events: list[HostEvent] = [],
        _imports: dict[str, ImportResolution] = {},
        _locals: dict[str, LocalResolution] = {},
        _npm: dict[str, NpmAnswer] = {},
        _declared: dict[str, DeclaredDependencies] = {},
        _python: dict[str, PythonInterface] = {},
        _served: dict[str, ServedInterface] = {},
        _catalog: (StubCatalog | None) = None,
        analyses: dict[str, ModuleAnalysis] = {},
        units: dict[str, UnitProducts] = {},
        asker: (HostAsker | None) = None,
        kernel_asker: bool = False,
        _asked: set[str] = set(),
        grown: set[str] = set(),
        native_failures: dict[str, str] = {},
        _native_ifaces: dict[str, NativeIface] = {},
        _lowering: set[str] = set(),
        _lowered: dict[str, Module] = {},
        _indexed: list[int] = [0, 0, 0, 0, 0],
        _session: (KernelSession | None) = None;

    def postinit;
    def index_answers;
    def ask(method: str, key: str) -> bool;
    def wants_unit(path: str) -> bool;
    def host(method: str = "") -> HostServices;
    def in_kernel -> bool;
    def kernel_only(method: str) -> bool;
    def open_stub_catalog -> (StubCatalog | None);
    def python_module(program: JacProgram, file_path: str) -> (Module | None);
    def close_over(options: CompileOptions);
    def record_unit(task: ModuleAnalysis);
    def host_turn(method: str = "") -> HostTurn;
    def missing(method: str, key: str) -> HostTurn;
    def delegating(method: str) -> HostTurn;
    def buffer(event: HostEvent, method: str);
    def event_rows -> list[list[str]];
    def replay(target: HostServices);
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
    def learn_local_module(base: str, parts: list[str], key: str) -> LocalResolution;
    def jac_virtual_module_path(target: str) -> (str | None);
    def is_path_alias(target: str, base_path: str) -> bool;
    def is_untyped_third_party(path: str) -> bool;
    def in_typeshed_tree(path: str) -> bool;
    def sibling_declaration(js_path: str) -> (str | None);
    def client_pulls(path: str) -> str;
    def client_pull_grew(path: str);
    def npm_answer(spec: str, base_path: str, method: str) -> NpmAnswer;
    def has_npm_package(spec: str, base_path: str) -> bool;
    def resolve_npm_package(spec: str, base_path: str) -> (str | None);
    def npm_declarations(spec: str, base_path: str) -> (str | None);
    def declared_dependencies(
        module_path: str, fallback_app: str
    ) -> (list[str] | None);

    def note(message: str, style: str = "dim");
    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None);
    def parse_python(
        source_str: str, file_path: str, program: JacProgram
    ) -> tuple[Module, bool];

    def stub_interface(program: JacProgram, file_path: str) -> (Module | None);
    def ct_environment -> CtEnvironment;
    def path_facts(path: str) -> PathFacts;
    def host_platform -> HostPlatform;
    def read_source(path: str) -> str;
    def annex_files(path: str, suffix: str = ".impl.jac") -> list[str];
    def base_file(annex_path: str) -> (str | None);
    def is_annex_path_of(candidate: str, base: str) -> bool;
    def package_init(directory: str) -> (str | None);
    def wiring_file(path: str) -> (str | None);
    def is_seed_source(rel_path: str) -> bool;
    def wiring_records(digest: str) -> str;
    def keep_wiring_records(digest: str, text: str);
    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = "",
        load_kernel: bool = True
    ) -> (tuple[Module, bool] | None);

    def woven_module(path: str, program: (JacProgram | None)) -> (Module | None);
    def place_wired_imports(module: Module);
    def drop_python_lane_products(path: str, program: JacProgram);
    def compiler_for(program: JacProgram) -> JacCompiler;
    def iface_registry_for(program: JacProgram) -> IfaceRegistry;
    def held_native_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> str;

    def native_dep_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (NativeIface | None);

    def native_dep_discovery_open(program: JacProgram) -> bool;
    def native_deps_deferred(program: JacProgram) -> bool;
    def lower_dependency(
        program: JacProgram, real: str, options: CompileOptions
    ) -> (NativeIface | None);

    def native_fact(kind: str, key: str) -> str;
    def save_native_debug_ir(path: str, text: str);
    def native_lowering_failed(program: JacProgram, path: str, detail: str);
    def native_units_for(program: JacProgram) -> NativeUnitRegistry;
    def client_boundary_facts(program: JacProgram, path: str) -> (list[str] | None);
    def in_compiler_tree(path: str) -> bool;
    def schedule_import_failed(err: ImportError);
    def client_osp_core_js -> str;
    def client_stub_globals -> list[str];
    def kernel_compile(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (CompileReport | None);

    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None);

    def native_session_active(program: JacProgram) -> bool;
    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    );

    def format_file(file_path: str, auto_lint: bool = False) -> JacProgram;
    def format_source(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram;

    def lint_file(file_path: str) -> JacProgram;
    def native_pipeline_available -> tuple[bool, str];
    def compile_module(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module;

    def build_module(
        program: JacProgram, file_path: str, use_str: (str | None)
    ) -> Module;

    def internal_program(program: JacProgram) -> (JacProgram | None);
    def bind_context_program(context_root: JacProgram, program: JacProgram);
    def note_program_dependency(program: JacProgram, resolved_path: str);
    def forget_program_products(program: JacProgram, resolved_path: str);
    def release_program_products(program: JacProgram, retain_stubs: bool);
    def prepare_interface(program: JacProgram, path: str, module: Module) -> bool;
    def collect_released_memory;
    def load_modules(names: list[str]);
    def module_in_flight(names: list[str]) -> str;
    def import_in_flight(path: str) -> bool;
    def has_active_stub_catalog -> bool;
    def is_native_only_source(rel: str) -> bool;
    def is_native_lowered_source(rel: str) -> bool;
    def host_side -> HostServices;
    def default_target_triple -> str;
}

def read_utf8_source(path: str) -> (str | None);

def replay_event_rows(target: HostServices, rows: list[list[str]]);

def replay_event(target: HostServices, event: HostEvent);
