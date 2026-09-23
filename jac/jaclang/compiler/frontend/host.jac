import from collections.abc { Iterator }
import from contextlib { contextmanager }
import type from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }

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
