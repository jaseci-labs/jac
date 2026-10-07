import from contextlib { contextmanager }
import from jaclang.compiler.frontend.host {
    CheckSettings,
    HostPlatform,
    HostServices,
    LintSettings,
    PathFacts,
    ProjectDefaults,
    ProjectFacts
}
import type from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import type from jaclang.compiler.types.ct_value { CtEnvironment }
import type from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.passes.annex_weave { WovenAnnex }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.ifacecache { IfaceRegistry }
import type from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.module_analysis { ModuleAnalysis }
import type from jaclang.compiler.frontend.kernel_inputs { KernelInputs }
import type from jaclang.compiler.frontend.kernel_analyze { CompileReport }

glob UNIT_COLLECT_EVERY: int = 16,
     UNIT_COLLECT_GROWTH_MB: int = 512;

obj UnitCollectBudget {
    has releases: int = 0,
        last_peak_mb: int = 0;

    def due -> bool;
}

obj ProjectHost(HostServices) {
    has _defaults_active: bool = False,
        _last_defaults: (ProjectDefaults | None) = None,
        _facts: dict[str, tuple[any, ProjectFacts]] = {},
        _stub_globals: list[str] = [],
        _collect_budget: UnitCollectBudget = UnitCollectBudget(),
        _platform: (HostPlatform | None) = None;

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
    def has_npm_package(spec: str, base_path: str) -> bool;
    def resolve_npm_package(spec: str, base_path: str) -> (str | None);
    def npm_declarations(spec: str, base_path: str) -> (str | None);
    def declared_dependencies(
        module_path: str, fallback_app: str
    ) -> (list[str] | None);

    def native_pipeline_available -> tuple[bool, str];
    def note(message: str, style: str = "dim");
    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None);
    def parse_python(
        source_str: str, file_path: str, program: JacProgram
    ) -> tuple[Module, bool];

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
    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = ""
    ) -> (tuple[Module, bool] | None);

    def drop_python_lane_products(path: str, program: JacProgram);
    def compiler_for(program: JacProgram) -> JacCompiler;
    def iface_registry_for(program: JacProgram) -> IfaceRegistry;
    def native_units_for(program: JacProgram) -> NativeUnitRegistry;
    def client_boundary_facts(program: JacProgram, path: str) -> (list[str] | None);
    def kernel_compile(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (CompileReport | None);

    def in_compiler_tree(path: str) -> bool;
    def schedule_import_failed(err: ImportError);
    def client_osp_core_js -> str;
    def client_stub_globals -> list[str];
    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None);

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    );

    def native_analyze(
        program: JacProgram, path: str, options: CompileOptions, source: (str | None)
    ) -> (ModuleAnalysis | None);

    def kernel_inputs(
        program: JacProgram,
        path: str,
        options: CompileOptions,
        source: (str | None) = None
    ) -> KernelInputs;

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
    def default_target_triple -> str;
}

def check_settings_of(check: any) -> CheckSettings {
    if check is None {
        return CheckSettings();
    }
    lint = check.lint;
    return CheckSettings(
        suppress=list(check.suppress or []),
        suppress_categories=list(check.suppress_categories or []),
        lint_active=bool(lint),
        lint_select=list(lint.select) if lint else [],
        lint_ignore=list(lint.ignore) if lint else [],
        enforce_access=bool(check.enforce_access),
        untyped_external_error=check.untyped_external == "error",
        warn_native_seams=bool(check.warn_native_seams)
    );
}

def project_defaults_of(cfg: any) -> ProjectDefaults {
    native = cfg.native;
    memory = cfg.memory;
    return ProjectDefaults(
        default_codespace=cfg.placement.default_codespace,
        native_closure_cap=cfg.build.native_closure_cap,
        native_require=list(native.require),
        native_target=native.target,
        native_debug=native.debug,
        native_opt=native.opt,
        native_threads=native.threads,
        native_link_mode=native.link_mode,
        memory_profile=memory.profile,
        memory_enforce=list(memory.enforce),
        memory_exempt=list(memory.exempt),
        check=check_settings_of(cfg.check),
        client_framework=cfg.client.framework if cfg.client else "react"
    );
}

def client_stub_names(path: str) -> set[str] {
    import ast;
    out: set[str] = set();
    try {
        with open(path, encoding="utf-8") as handle {
            tree = ast.parse(handle.read());
        }
    } except Exception {
        return out;
    }
    for node in tree.body {
        if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) {
            out.add(node.name);
        } elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) {
            out.add(node.target.id);
        } elif isinstance(node, ast.Assign) {
            for tgt in node.targets {
                if not isinstance(tgt, ast.Name) {
                    continue;
                }
                out.add(tgt.id);
                if tgt.id != "__all__"
                    or not isinstance(node.value, (ast.List, ast.Tuple)) {
                    continue;
                }
                for elt in node.value.elts {
                    if isinstance(elt, ast.Constant) and isinstance(elt.value, str) {
                        out.add(elt.value);
                    }
                }
            }
        }
    }
    return out;
}
