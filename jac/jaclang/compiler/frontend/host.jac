import from collections.abc { Iterator }
import from contextlib { contextmanager }
import type from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.passes.annex_weave { WovenAnnex }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.ifacecache { IfaceRegistry }
import type from jaclang.compiler.driver.nativecache {
    NativeUnitRegistry,
    NativeVerdict
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

    def note(message: str) {}
    def path_facts(path: str) -> PathFacts {
        return PathFacts();
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

    def native_parse(
        source_str: str,
        file_path: str,
        program: (JacProgram | None),
        annexes: list[WovenAnnex],
        early_context: str = ""
    ) -> (tuple[Module, bool] | None) {
        return None;
    }

    def discard_module_artifact(path: str, program: JacProgram) {}
    def compiler_for(program: JacProgram) -> JacCompiler {
        raise RuntimeError("no compiler host is installed");
    }

    def iface_registry_for(program: JacProgram) -> IfaceRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def native_units_for(program: JacProgram) -> NativeUnitRegistry {
        raise RuntimeError("no compiler host is installed");
    }

    def native_verdict(
        path: str, program: (JacProgram | None) = None
    ) -> (NativeVerdict | None) {
        return None;
    }

    def record_native_coverage(
        path: str, outcome: str, code: str = "", detail: str = ""
    ) {}

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
}

glob _HOSTS: list[HostServices] = [];

def active_host -> HostServices {
    if not _HOSTS {
        _HOSTS.append(HostServices());
    }
    return _HOSTS[-1];
}

def install_host(host: HostServices) {
    _HOSTS.clear();
    _HOSTS.append(host);
}
