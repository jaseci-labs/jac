import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from jaclang.compiler.frontend.host {
    CheckSettings,
    HostPlatform,
    HostServices,
    LintSettings,
    NativeVerdict,
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
    def is_path_alias(target: str, base_path: str) -> bool;
    def is_untyped_third_party(path: str) -> bool;
    def in_typeshed_tree(path: str) -> bool;
    def sibling_declaration(js_path: str) -> (str | None);
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
    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None);

    def native_verdict(
        path: str, program: (JacProgram | None) = None
    ) -> (NativeVerdict | None);

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    );

    def record_native_verdict(program: JacProgram, path: str, code: str, detail: str);
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
        untyped_external_error=check.untyped_external == "error"
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
        check=check_settings_of(cfg.check)
    );
}
