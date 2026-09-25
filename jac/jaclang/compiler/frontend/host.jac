import from collections.abc { Iterator }
import from contextlib { contextmanager }
import from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }
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

obj NativeVerdict {
    has demoted: bool = False,
        code: str = "",
        detail: str = "";
}

obj CheckSettings {
    has suppress: list[str] = [],
        suppress_categories: list[str] = [],
        lint_active: bool = False,
        lint_select: list[str] = [],
        lint_ignore: list[str] = [],
        enforce_access: bool = False,
        untyped_external_error: bool = False;
}

obj ProjectDefaults {
    has default_codespace: str,
        native_closure_cap: int,
        native_require: list[str],
        native_target: str,
        native_debug: bool,
        native_opt: int,
        native_threads: int,
        native_link_mode: str,
        memory_profile: str,
        memory_enforce: list[str],
        memory_exempt: list[str],
        check: CheckSettings;
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
        arch_closed: list[str] = [],
        client_framework: str = "react";
}

obj HostServices {
    @contextmanager
    def session -> Iterator[None] {
        yield ;
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
        import from jaclang.compiler.types.ct_value { CtEnvironment }
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

    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = ""
    ) -> (tuple[Module, bool] | None) {
        return None;
    }

    def drop_python_lane_products(path: str, program: JacProgram) {}
    def compiler_for(program: JacProgram) -> JacCompiler {
        raise RuntimeError("no compiler host is installed");
    }

    def iface_registry_for(program: JacProgram) -> IfaceRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def native_units_for(program: JacProgram) -> NativeUnitRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def native_session_declares(
        program: JacProgram, source: str, element: str
    ) -> (bool | None) {
        return None;
    }

    def native_verdict(
        path: str, program: (JacProgram | None) = None
    ) -> (NativeVerdict | None) {
        return None;
    }

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    ) {}

    def record_native_verdict(
        program: JacProgram, path: str, code: str, detail: str
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

glob KERNEL_HOST_ENV: str = "JAC_KERNEL_HOST",
     _HOSTS: list[HostServices] = [],
     _NEUTRAL_HOST: HostServices = HostServices(),
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

def kernel_host_mode -> str {
    import os;
    return os.environ.get(KERNEL_HOST_ENV, "").strip().lower();
}

def kernel_host_enabled -> bool {
    return kernel_host_mode() not in ("", "0", "off", "false");
}
