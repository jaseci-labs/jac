import from collections.abc { Iterator }
import from contextlib { contextmanager }

obj CheckSettings {
    has suppress: list[str] = [],
        suppress_categories: list[str] = [],
        lint_active: bool = False,
        lint_select: list[str] = [],
        lint_ignore: list[str] = [],
        enforce_access: bool = False,
        untyped_external_error: bool = False,
        warn_native_seams: bool = True;
}

obj ProjectDefaults {
    has default_codespace: str,
        native_require: list[str],
        native_target: str,
        native_debug: bool,
        native_opt: int,
        native_threads: int,
        native_link_mode: str,
        memory_profile: str,
        memory_enforce: list[str],
        memory_exempt: list[str],
        check: CheckSettings,
        client_framework: str = "react";
}

obj PathFacts {
    has is_jac: bool = False,
        is_annex: bool = False,
        retired_marker: str = "",
        module_stem: str = "",
        scope_stem: str = "";
}

obj HostPlatform {
    has machine: str = "",
        python_major: int = 0,
        python_minor: int = 0;
}

obj LintSettings {
    has check: CheckSettings,
        exclude: list[str] = [],
        project_root: str = "";
}

obj ProjectFacts {
    has project_root: str,
        check: CheckSettings,
        client_framework: str = "react",
        package_name: str = "",
        package_exports: list[str] = [],
        package_mounts: str = "";
}

obj HostServices {
    @contextmanager
    def session -> Iterator[None] {
        yield ;
    }

    def in_kernel -> bool {
        return False;
    }

    def project_defaults -> (ProjectDefaults | None) {
        return None;
    }

    def check_settings(target_app: str) -> CheckSettings {
        return CheckSettings();
    }

    def project_facts(path: str) -> (ProjectFacts | None) {
        return None;
    }

    def lint_settings(path: str) -> LintSettings {
        return LintSettings(check=CheckSettings());
    }

    def workspace(path: str) -> (WorkspaceSpec | None) {
        return None;
    }

    def app_for_path(path: str) -> (AppSpec | None) {
        return None;
    }

    def project_root(path: str) -> (str | None) {
        return None;
    }

    def resolve_module(
        target: str, base_path: str, string_spec: bool = False
    ) -> tuple[str, str] {
        return ("", "");
    }

    def resolve_local_module(base: str, parts: list[str]) -> (tuple[str, str] | None) {
        return None;
    }

    def jac_virtual_module_path(target: str) -> (str | None) {
        return None;
    }

    def is_path_alias(target: str, base_path: str) -> bool {
        return False;
    }

    def is_untyped_third_party(path: str) -> bool {
        return False;
    }

    def in_typeshed_tree(path: str) -> bool {
        return False;
    }

    def sibling_declaration(js_path: str) -> (str | None) {
        return None;
    }

    def client_pulls(path: str) -> str {
        return "";
    }

    def client_pull_grew(path: str) {}
    def has_npm_package(spec: str, base_path: str) -> bool {
        return False;
    }

    def resolve_npm_package(spec: str, base_path: str) -> (str | None) {
        return None;
    }

    def npm_declarations(spec: str, base_path: str) -> (str | None) {
        return None;
    }

    def declared_dependencies(
        module_path: str, fallback_app: str
    ) -> (list[str] | None) {
        return None;
    }

    def note(message: str, style: str = "dim") {}
    def stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
        return None;
    }

    def parse_python(
        source_str: str, file_path: str, program: JacProgram
    ) -> tuple[Module, bool] {
        raise RuntimeError("no compiler host is installed");
    }

    def ct_environment -> CtEnvironment {
        return CtEnvironment();
    }

    def path_facts(path: str) -> PathFacts {
        return PathFacts();
    }

    def host_platform -> HostPlatform {
        return HostPlatform();
    }

    def read_source(path: str) -> str {
        with open(path) as handle {
            return handle.read();
        }
    }

    def annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
        return [];
    }

    def base_file(annex_path: str) -> (str | None) {
        return None;
    }

    def is_annex_path_of(candidate: str, base: str) -> bool {
        return False;
    }

    def package_init(directory: str) -> (str | None) {
        return None;
    }

    def wiring_file(path: str) -> (str | None) {
        return None;
    }

    def is_seed_source(rel_path: str) -> bool {
        return False;
    }

    def wiring_records(digest: str) -> str {
        return "";
    }

    def keep_wiring_records(digest: str, text: str) {}
    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = "",
        load_kernel: bool = True
    ) -> (tuple[Module, bool] | None) {
        return None;
    }

    def woven_module(path: str, program: (JacProgram | None)) -> (Module | None) {
        return None;
    }

    def place_wired_imports(module: Module) {}
    def drop_python_lane_products(path: str, program: JacProgram) {}
    def compiler_for(program: JacProgram) -> JacCompiler {
        raise RuntimeError("no compiler host is installed");
    }

    def iface_registry_for(program: JacProgram) -> IfaceRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def native_dep_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (NativeIface | None) {
        return None;
    }

    def native_dep_discovery_open(program: JacProgram) -> bool {
        return False;
    }

    def native_deps_deferred(program: JacProgram) -> bool {
        return False;
    }

    def held_native_iface(
        program: JacProgram, path: str, options: CompileOptions
    ) -> str {
        return "";
    }

    def native_lowering_failed(program: JacProgram, path: str, detail: str) {}
    def native_fact(kind: str, key: str) -> str {
        return "";
    }

    def save_native_debug_ir(path: str, text: str) {}
    def native_units_for(program: JacProgram) -> NativeUnitRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def client_boundary_facts(program: JacProgram, path: str) -> (list[str] | None) {
        return None;
    }

    def kernel_compile(
        program: JacProgram, path: str, options: CompileOptions
    ) -> (CompileReport | None) {
        return None;
    }

    def in_compiler_tree(path: str) -> bool {
        return False;
    }

    def schedule_import_failed(err: ImportError) {}
    def client_osp_core_js -> str {
        return "";
    }

    def client_stub_globals -> list[str] {
        return [];
    }

    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None) {
        return None;
    }

    def native_session_active(program: JacProgram) -> bool {
        return False;
    }

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    ) {}

    def native_analyze(
        program: JacProgram, path: str, options: CompileOptions, source: (str | None)
    ) -> (ModuleAnalysis | None) {
        return None;
    }

    def format_file(file_path: str, auto_lint: bool = False) -> JacProgram {
        raise RuntimeError("no compiler host is installed");
    }

    def format_source(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram {
        raise RuntimeError("no compiler host is installed");
    }

    def lint_file(file_path: str) -> JacProgram {
        raise RuntimeError("no compiler host is installed");
    }

    def native_pipeline_available -> tuple[bool, str] {
        return (False, "native pipeline unavailable: no compiler host is installed");
    }

    def compile_module(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module {
        raise RuntimeError("no compiler host is installed");
    }

    def build_module(
        program: JacProgram, file_path: str, use_str: (str | None)
    ) -> Module {
        raise RuntimeError("no compiler host is installed");
    }

    def run_module_pipeline(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> Module {
        raise RuntimeError("no compiler host is installed");
    }

    def internal_program(program: JacProgram) -> (JacProgram | None) {
        return None;
    }

    def bind_context_program(context_root: JacProgram, program: JacProgram) {}
    def note_program_dependency(program: JacProgram, resolved_path: str) {}
    def forget_program_products(program: JacProgram, resolved_path: str) {}
    def release_program_products(program: JacProgram, retain_stubs: bool) {}
    def prepare_interface(program: JacProgram, path: str, module: Module) -> bool {
        return False;
    }

    def collect_released_memory {}
    def load_modules(names: list[str]) {}
    def module_in_flight(names: list[str]) -> str {
        return "";
    }

    def import_in_flight(path: str) -> bool {
        return False;
    }

    def has_active_stub_catalog -> bool {
        return False;
    }

    def typeshed_unavailable_reason -> str {
        import os;
        stdlib = os.path.join(jaclang_pkg_root(), "vendor", "typeshed", "stdlib");
        if os.path.isfile(os.path.join(stdlib, "builtins.pyi")) {
            return "";
        }
        return f"no typeshed stdlib at {stdlib}";
    }

    def is_native_only_source(rel: str) -> bool {
        return False;
    }

    def is_native_lowered_source(rel: str) -> bool {
        return False;
    }

    def default_target_triple -> str {
        return "";
    }

    def host_side -> HostServices {
        return self;
    }
}

obj NeutralHost(HostServices) {}

glob HOST_FACT_SEP: str = "\x1e",
     HOST_FACT_STDLIB_MODULES: str = "stdlib_modules",
     HOST_FACT_GIT_IGNORED: str = "git_ignored";

glob _HOSTS: list[HostServices] = [],
     _KERNEL_HOST_MODE: list[str] = [],
     _NEUTRAL_HOST: HostServices = NeutralHost(),
     _PACKAGE_ROOT: list[str] = [];

def active_host -> HostServices {
    return _HOSTS[-1] if _HOSTS else _NEUTRAL_HOST;
}

def package_root -> str {
    return _PACKAGE_ROOT[0] if _PACKAGE_ROOT else "";
}

def set_package_root(path: str) {
    _PACKAGE_ROOT.clear();
    _PACKAGE_ROOT.append(path);
}

def install_host(host: HostServices) {
    _HOSTS.clear();
    _HOSTS.append(host);
}

def set_kernel_host_mode(mode: str) -> str {
    previous = kernel_host_mode();
    _KERNEL_HOST_MODE.clear();
    if mode {
        _KERNEL_HOST_MODE.append(mode);
    }
    return previous;
}

def kernel_host_mode -> str {
    return _KERNEL_HOST_MODE[0] if _KERNEL_HOST_MODE else "";
}

def kernel_host_enabled -> bool {
    return kernel_host_mode() != "";
}
