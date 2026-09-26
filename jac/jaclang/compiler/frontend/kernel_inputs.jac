import base64;
import json;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.host {
    CheckSettings,
    HostPlatform,
    LintSettings,
    NativeVerdict,
    ProjectDefaults,
    ProjectFacts
}
import from jaclang.compiler.frontend.source_layout { LayoutTables }
import from jaclang.compiler.types.ct_value { CtEnvironment }
import from jaclang.project.workspace_model { AppSpec, WorkspaceSpec }

glob KERNEL_INPUTS_VERSION: int = 2;

obj RequestOptions {
    has symtab_ir_only: bool = False,
        no_cgen: bool = False,
        native_parity: bool = False,
        native_required: bool = False,
        native_require: list[str] = [],
        iface_ok: bool = False,
        need_full_ast: bool = False,
        no_ir_cache: bool = False,
        resolve_annex_parent: bool = False,
        aot_mode: bool = False,
        native_unit: bool = False,
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
        package_canonical: bool = False;

    def to_options -> CompileOptions {
        return CompileOptions(
            symtab_ir_only=self.symtab_ir_only,
            no_cgen=self.no_cgen,
            native_parity=self.native_parity,
            native_required=self.native_required,
            native_require=list(self.native_require),
            iface_ok=self.iface_ok,
            need_full_ast=self.need_full_ast,
            no_ir_cache=self.no_ir_cache,
            resolve_annex_parent=self.resolve_annex_parent,
            aot_mode=self.aot_mode,
            native_unit=self.native_unit,
            force_codespace=self.force_codespace,
            memory_profile=self.memory_profile,
            nogc_enforce_all=self.nogc_enforce_all,
            memory_enforce=list(self.memory_enforce),
            memory_exempt=list(self.memory_exempt),
            native_target=self.native_target,
            suppress_codes=list(self.suppress_codes),
            default_codespace=self.default_codespace,
            app_kind=self.app_kind,
            target_app=self.target_app,
            entry_point=self.entry_point,
            ui=self.ui,
            project_root=self.project_root,
            strict_dependencies=self.strict_dependencies,
            package_canonical=self.package_canonical
        );
    }
}

obj PythonInterface {
    has path: str,
        pkg_dir: str,
        data: bytes = b"";
}

obj ImportResolution {
    has target: str,
        base_path: str,
        string_spec: bool = False,
        path: str = "",
        language: str = "";

    def key -> str {
        return resolution_key(self.target, self.base_path, self.string_spec);
    }
}

obj LocalResolution {
    has base: str,
        parts: list[str] = [],
        found: bool = False,
        path: str = "",
        language: str = "";

    def key -> str {
        return local_key(self.base, self.parts);
    }
}

obj NpmAnswer {
    has spec: str,
        base_path: str,
        installed: bool = False,
        package_entry: (str | None) = None,
        declarations: (str | None) = None,
        entry_known: bool = False,
        declarations_known: bool = False;

    def key -> str {
        return pair_key(self.spec, self.base_path);
    }
}

obj DeclaredDependencies {
    has module_path: str,
        fallback_app: str = "",
        names: (list[str] | None) = None;

    def key -> str {
        return pair_key(self.module_path, self.fallback_app);
    }
}

obj ManifestSets {
    has seed_paths: list[str] = [],
        native_only_files: list[str] = [],
        native_only_dirs: list[str] = [],
        native_lowered: list[str] = [];

    def is_seed(rel: str) -> bool {
        for entry_path in self.seed_paths {
            if entry_path.endswith("/") {
                if rel.startswith(entry_path) {
                    return True;
                }
            } elif rel == entry_path {
                return True;
            }
        }
        return False;
    }

    def is_native_only(rel: str) -> bool {
        if rel in self.native_only_files {
            return True;
        }
        for directory in self.native_only_dirs {
            if rel.startswith(directory + "/") {
                return True;
            }
        }
        return False;
    }

    def is_native_lowered(rel: str) -> bool {
        for prefix in self.native_lowered {
            if rel == prefix or rel.startswith(prefix + "/") {
                return True;
            }
        }
        return False;
    }
}

obj KernelInputs {
    has version: int = KERNEL_INPUTS_VERSION,
        entry_path: str = "",
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
        stub_catalog_active: bool = False,
        stub_catalog_dir: str = "",
        stub_catalog_file: str = "",
        stub_catalog_offset: int = 0,
        stub_catalog_length: int = 0,
        typeshed_roots: list[str] = [],
        search_paths: list[str] = [],
        native_session_active: bool = False,
        scanned_modules: int = 0,
        manifest: ManifestSets = ManifestSets(),
        layout: LayoutTables = LayoutTables(),
        project_facts: dict[str, ProjectFacts] = {},
        workspaces: dict[str, WorkspaceSpec] = {},
        facts_of: dict[str, str] = {},
        workspace_of: dict[str, str] = {},
        app_of: dict[str, str] = {},
        project_root_of: dict[str, str] = {},
        lint_of: dict[str, LintSettings] = {},
        verdicts: dict[str, (NativeVerdict | None)] = {},
        untyped: dict[str, bool] = {},
        siblings: dict[str, str] = {},
        path_aliases: dict[str, bool] = {},
        virtual_modules: dict[str, str] = {},
        imports: list[ImportResolution] = [],
        local_imports: list[LocalResolution] = [],
        npm: list[NpmAnswer] = [],
        declared: list[DeclaredDependencies] = [],
        python_ifaces: list[PythonInterface] = [];

    def to_json -> str {
        return json.dumps(inputs_to_dict(self), sort_keys=True);
    }

    static def from_json(text: str) -> KernelInputs {
        return inputs_from_dict(json_map(json.loads(text)));
    }
}

def resolution_key(target: str, base_path: str, string_spec: bool) -> str {
    return f"{int(string_spec)}\x00{target}\x00{base_path}";
}

def local_key(base: str, parts: list[str]) -> str {
    return base + "\x00" + "/".join(parts);
}

def pair_key(first: str, second: str) -> str {
    return f"{first}\x00{second}";
}

def request_of(options: CompileOptions) -> RequestOptions {
    return RequestOptions(
        symtab_ir_only=options.symtab_ir_only,
        no_cgen=options.no_cgen,
        native_parity=options.native_parity,
        native_required=options.native_required,
        native_require=list(options.native_require or []),
        iface_ok=options.iface_ok,
        need_full_ast=options.need_full_ast,
        no_ir_cache=options.no_ir_cache,
        resolve_annex_parent=options.resolve_annex_parent,
        aot_mode=options.aot_mode,
        native_unit=options.native_unit,
        force_codespace=options.force_codespace,
        memory_profile=options.memory_profile or "managed",
        nogc_enforce_all=bool(options.nogc_enforce_all),
        memory_enforce=list(options.memory_enforce or []),
        memory_exempt=list(options.memory_exempt or []),
        native_target=options.native_target or "",
        suppress_codes=list(options.suppress_codes),
        default_codespace=options.default_codespace,
        app_kind=options.app_kind,
        target_app=options.target_app,
        entry_point=options.entry_point,
        ui=options.ui,
        project_root=options.project_root,
        strict_dependencies=options.strict_dependencies,
        package_canonical=options.package_canonical
    );
}

def request_to_dict(request: RequestOptions) -> dict[str, any] {
    return {
        "symtab_ir_only": request.symtab_ir_only,
        "no_cgen": request.no_cgen,
        "native_parity": request.native_parity,
        "native_required": request.native_required,
        "native_require": list(request.native_require),
        "iface_ok": request.iface_ok,
        "need_full_ast": request.need_full_ast,
        "no_ir_cache": request.no_ir_cache,
        "resolve_annex_parent": request.resolve_annex_parent,
        "aot_mode": request.aot_mode,
        "native_unit": request.native_unit,
        "force_codespace": request.force_codespace,
        "memory_profile": request.memory_profile,
        "nogc_enforce_all": request.nogc_enforce_all,
        "memory_enforce": list(request.memory_enforce),
        "memory_exempt": list(request.memory_exempt),
        "native_target": request.native_target,
        "suppress_codes": list(request.suppress_codes),
        "default_codespace": request.default_codespace,
        "app_kind": request.app_kind,
        "target_app": request.target_app,
        "entry_point": request.entry_point,
        "ui": request.ui,
        "project_root": request.project_root,
        "strict_dependencies": request.strict_dependencies,
        "package_canonical": request.package_canonical
    };
}

def request_from_dict(raw: dict[str, any]) -> RequestOptions {
    project_root = raw.get("project_root");
    return RequestOptions(
        symtab_ir_only=bool(raw.get("symtab_ir_only", False)),
        no_cgen=bool(raw.get("no_cgen", False)),
        native_parity=bool(raw.get("native_parity", False)),
        native_required=bool(raw.get("native_required", False)),
        native_require=json_str_list(raw.get("native_require")),
        iface_ok=bool(raw.get("iface_ok", False)),
        need_full_ast=bool(raw.get("need_full_ast", False)),
        no_ir_cache=bool(raw.get("no_ir_cache", False)),
        resolve_annex_parent=bool(raw.get("resolve_annex_parent", False)),
        aot_mode=bool(raw.get("aot_mode", False)),
        native_unit=bool(raw.get("native_unit", False)),
        force_codespace=str(raw.get("force_codespace", "")),
        memory_profile=str(raw.get("memory_profile", "managed")),
        nogc_enforce_all=bool(raw.get("nogc_enforce_all", False)),
        memory_enforce=json_str_list(raw.get("memory_enforce")),
        memory_exempt=json_str_list(raw.get("memory_exempt")),
        native_target=str(raw.get("native_target", "")),
        suppress_codes=json_str_list(raw.get("suppress_codes")),
        default_codespace=str(raw.get("default_codespace", "")),
        app_kind=str(raw.get("app_kind", "")),
        target_app=str(raw.get("target_app", "")),
        entry_point=str(raw.get("entry_point", "")),
        ui=str(raw.get("ui", "")),
        project_root=str(project_root) if project_root is not None else None,
        strict_dependencies=bool(raw.get("strict_dependencies", False)),
        package_canonical=bool(raw.get("package_canonical", False))
    );
}

def check_to_dict(check: CheckSettings) -> dict[str, any] {
    return {
        "suppress": list(check.suppress),
        "suppress_categories": list(check.suppress_categories),
        "lint_active": check.lint_active,
        "lint_select": list(check.lint_select),
        "lint_ignore": list(check.lint_ignore),
        "enforce_access": check.enforce_access,
        "untyped_external_error": check.untyped_external_error,
        "warn_native_seams": check.warn_native_seams
    };
}

def check_from_dict(raw: dict[str, any]) -> CheckSettings {
    return CheckSettings(
        suppress=json_str_list(raw.get("suppress")),
        suppress_categories=json_str_list(raw.get("suppress_categories")),
        lint_active=bool(raw.get("lint_active", False)),
        lint_select=json_str_list(raw.get("lint_select")),
        lint_ignore=json_str_list(raw.get("lint_ignore")),
        enforce_access=bool(raw.get("enforce_access", False)),
        untyped_external_error=bool(raw.get("untyped_external_error", False)),
        warn_native_seams=bool(raw.get("warn_native_seams", True))
    );
}

def defaults_to_dict(defaults: ProjectDefaults) -> dict[str, any] {
    return {
        "default_codespace": defaults.default_codespace,
        "native_closure_cap": defaults.native_closure_cap,
        "native_require": list(defaults.native_require),
        "native_target": defaults.native_target,
        "native_debug": defaults.native_debug,
        "native_opt": defaults.native_opt,
        "native_threads": defaults.native_threads,
        "native_link_mode": defaults.native_link_mode,
        "memory_profile": defaults.memory_profile,
        "memory_enforce": list(defaults.memory_enforce),
        "memory_exempt": list(defaults.memory_exempt),
        "check": check_to_dict(defaults.check),
        "client_framework": defaults.client_framework
    };
}

def defaults_from_dict(raw: dict[str, any]) -> ProjectDefaults {
    return ProjectDefaults(
        default_codespace=str(raw.get("default_codespace", "")),
        native_closure_cap=json_int(raw.get("native_closure_cap")),
        native_require=json_str_list(raw.get("native_require")),
        native_target=str(raw.get("native_target", "")),
        native_debug=bool(raw.get("native_debug", False)),
        native_opt=json_int(raw.get("native_opt")),
        native_threads=json_int(raw.get("native_threads")),
        native_link_mode=str(raw.get("native_link_mode", "")),
        memory_profile=str(raw.get("memory_profile", "")),
        memory_enforce=json_str_list(raw.get("memory_enforce")),
        memory_exempt=json_str_list(raw.get("memory_exempt")),
        check=check_from_dict(json_map(raw.get("check"))),
        client_framework=str(raw.get("client_framework", "react"))
    );
}

def facts_to_dict(facts: ProjectFacts) -> dict[str, any] {
    return {
        "project_root": facts.project_root,
        "check": check_to_dict(facts.check),
        "arch_closed": list(facts.arch_closed),
        "client_framework": facts.client_framework
    };
}

def facts_from_dict(raw: dict[str, any]) -> ProjectFacts {
    return ProjectFacts(
        project_root=str(raw.get("project_root", "")),
        check=check_from_dict(json_map(raw.get("check"))),
        arch_closed=json_str_list(raw.get("arch_closed")),
        client_framework=str(raw.get("client_framework", "react"))
    );
}

def lint_to_dict(lint: LintSettings) -> dict[str, any] {
    return {
        "check": check_to_dict(lint.check),
        "exclude": list(lint.exclude),
        "project_root": lint.project_root
    };
}

def lint_from_dict(raw: dict[str, any]) -> LintSettings {
    return LintSettings(
        check=check_from_dict(json_map(raw.get("check"))),
        exclude=json_str_list(raw.get("exclude")),
        project_root=str(raw.get("project_root", ""))
    );
}

def app_to_dict(app: AppSpec) -> dict[str, any] {
    return {
        "name": app.name,
        "kind": app.kind,
        "entry": app.`entry,
        "ui": app.ui,
        "platform": app.platform,
        "route": app.route,
        "pins": dict(app.pins),
        "npm_names": sorted(app.npm_names),
        "has_server": app.has_server,
        "codespace": app.codespace,
        "implicit": app.implicit,
        "real_entry": app.real_entry,
        "fact_digest": app.fact_digest
    };
}

def app_from_dict(raw: dict[str, any]) -> AppSpec {
    return AppSpec(
        name=str(raw.get("name", "")),
        kind=str(raw.get("kind", "")),
        `entry=str(raw.get("entry", "")),
        ui=str(raw.get("ui", "")),
        platform=str(raw.get("platform", "")),
        route=str(raw.get("route", "")),
        pins=json_str_map(raw.get("pins")),
        npm_names=set(json_str_list(raw.get("npm_names"))),
        has_server=bool(raw.get("has_server", False)),
        codespace=str(raw.get("codespace", "")),
        implicit=bool(raw.get("implicit", False)),
        real_entry=str(raw.get("real_entry", "")),
        fact_digest=str(raw.get("fact_digest", ""))
    );
}

def workspace_to_dict(ws: WorkspaceSpec) -> dict[str, any] {
    return {
        "project_root": ws.project_root,
        "toml_path": ws.toml_path,
        "apps": [app_to_dict(app) for app in ws.apps.values()],
        "default_app": ws.default_app,
        "explicit": ws.explicit,
        "digest": ws.digest,
        "base_pins": dict(ws.base_pins),
        "base_npm_names": sorted(ws.base_npm_names)
    };
}

def workspace_from_dict(raw: dict[str, any]) -> WorkspaceSpec {
    apps: dict[str, AppSpec] = {};
    for entry_raw in json_maps(raw.get("apps")) {
        app = app_from_dict(entry_raw);
        apps[app.name] = app;
    }
    return WorkspaceSpec(
        project_root=str(raw.get("project_root", "")),
        toml_path=str(raw.get("toml_path", "")),
        apps=apps,
        default_app=str(raw.get("default_app", "")),
        explicit=bool(raw.get("explicit", False)),
        digest=str(raw.get("digest", "")),
        base_pins=json_str_map(raw.get("base_pins")),
        base_npm_names=set(json_str_list(raw.get("base_npm_names")))
    );
}

def verdict_to_dict(verdict: (NativeVerdict | None)) -> (dict[str, any] | None) {
    if verdict is None {
        return None;
    }
    return {"demoted": verdict.demoted, "code": verdict.code, "detail": verdict.detail};
}

def verdict_from_dict(raw: dict[str, any]) -> NativeVerdict {
    return NativeVerdict(
        demoted=bool(raw.get("demoted", False)),
        code=str(raw.get("code", "")),
        detail=str(raw.get("detail", ""))
    );
}

def layout_to_dict(layout: LayoutTables) -> dict[str, any] {
    return {
        "jac_suffix": layout.jac_suffix,
        "annex_folders": dict(layout.annex_folders),
        "annex_order": list(layout.annex_folders.keys()),
        "module_suffixes": list(layout.module_suffixes),
        "init_files": list(layout.init_files),
        "stem_rekey_suffixes": list(layout.stem_rekey_suffixes),
        "foreign_suffixes": list(layout.foreign_suffixes),
        "retired_native": list(layout.retired_native),
        "retired_client": list(layout.retired_client)
    };
}

def layout_from_dict(raw: dict[str, any]) -> LayoutTables {
    folders = json_str_map(raw.get("annex_folders"));
    order = json_str_list(raw.get("annex_order"))
        if "annex_order" in raw
        else list(folders.keys());
    ordered: dict[str, str] = {};
    for suffix in order {
        ordered[suffix] = folders.get(suffix, "");
    }
    return LayoutTables(
        jac_suffix=str(raw.get("jac_suffix", ".jac")),
        annex_folders=ordered,
        module_suffixes=json_str_list(raw.get("module_suffixes")),
        init_files=json_str_list(raw.get("init_files")),
        stem_rekey_suffixes=json_str_list(raw.get("stem_rekey_suffixes")),
        foreign_suffixes=json_str_list(raw.get("foreign_suffixes")),
        retired_native=json_str_list(raw.get("retired_native")),
        retired_client=json_str_list(raw.get("retired_client"))
    );
}

def manifest_to_dict(manifest: ManifestSets) -> dict[str, any] {
    return {
        "seed_paths": list(manifest.seed_paths),
        "native_only_files": list(manifest.native_only_files),
        "native_only_dirs": list(manifest.native_only_dirs),
        "native_lowered": list(manifest.native_lowered)
    };
}

def manifest_from_dict(raw: dict[str, any]) -> ManifestSets {
    return ManifestSets(
        seed_paths=json_str_list(raw.get("seed_paths")),
        native_only_files=json_str_list(raw.get("native_only_files")),
        native_only_dirs=json_str_list(raw.get("native_only_dirs")),
        native_lowered=json_str_list(raw.get("native_lowered"))
    );
}

def optional_list(raw: object) -> (list[str] | None) {
    if raw is None {
        return None;
    }
    return json_str_list(raw);
}

def json_str_list(value: object) -> list[str] {
    out: list[str] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(str(item));
        }
    }
    return out;
}

def json_str_map(value: object) -> dict[str, str] {
    out: dict[str, str] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = str(item);
        }
    }
    return out;
}

def json_bool_map(value: object) -> dict[str, bool] {
    out: dict[str, bool] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = bool(item);
        }
    }
    return out;
}

def json_map(value: object) -> dict[str, any] {
    out: dict[str, any] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = item;
        }
    }
    return out;
}

def json_maps(value: object) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    if isinstance(value, list) {
        for item in value {
            out.append(json_map(item));
        }
    }
    return out;
}

def json_int(value: object, fallback: int = 0) -> int {
    if isinstance(value, bool) {
        return 1 if value else 0;
    }
    if isinstance(value, int) {
        return value;
    }
    return fallback;
}

def inputs_to_dict(inputs: KernelInputs) -> dict[str, any] {
    defaults = inputs.project_defaults;
    return {
        "version": inputs.version,
        "entry_path": inputs.entry_path,
        "module_projection": inputs.module_projection,
        "target_app": inputs.target_app,
        "request": request_to_dict(inputs.request),
        "project_defaults": defaults_to_dict(defaults)
            if defaults is not None
            else None,
        "check_settings": {
            app: check_to_dict(check) for (app, check) in inputs.check_settings.items()
        },
        "host_platform": {
            "machine": inputs.host_platform.machine,
            "python_major": inputs.host_platform.python_major,
            "python_minor": inputs.host_platform.python_minor
        },
        "ct_environment": {
            "os": inputs.ct_environment.os,
            "arch": inputs.ct_environment.arch
        },
        "target_triple": inputs.target_triple,
        "target_triple_known": inputs.target_triple_known,
        "native_pipeline": inputs.native_pipeline,
        "native_pipeline_reason": inputs.native_pipeline_reason,
        "native_pipeline_known": inputs.native_pipeline_known,
        "stub_catalog_active": inputs.stub_catalog_active,
        "stub_catalog_dir": inputs.stub_catalog_dir,
        "stub_catalog_file": inputs.stub_catalog_file,
        "stub_catalog_offset": inputs.stub_catalog_offset,
        "stub_catalog_length": inputs.stub_catalog_length,
        "typeshed_roots": list(inputs.typeshed_roots),
        "search_paths": list(inputs.search_paths),
        "native_session_active": inputs.native_session_active,
        "scanned_modules": inputs.scanned_modules,
        "manifest": manifest_to_dict(inputs.manifest),
        "layout": layout_to_dict(inputs.layout),
        "project_facts": {
            owner_root: facts_to_dict(facts)
            for (owner_root, facts) in inputs.project_facts.items()
        },
        "workspaces": {
            owner_root: workspace_to_dict(ws)
            for (owner_root, ws) in inputs.workspaces.items()
        },
        "facts_of": dict(inputs.facts_of),
        "workspace_of": dict(inputs.workspace_of),
        "app_of": dict(inputs.app_of),
        "project_root_of": dict(inputs.project_root_of),
        "lint_of": {
            path: lint_to_dict(lint) for (path, lint) in inputs.lint_of.items()
        },
        "verdicts": {
            path: verdict_to_dict(verdict)
            for (path, verdict) in inputs.verdicts.items()
        },
        "untyped": dict(inputs.untyped),
        "siblings": dict(inputs.siblings),
        "path_aliases": dict(inputs.path_aliases),
        "virtual_modules": dict(inputs.virtual_modules),
        "imports": [
            {
                "target": r.target,
                "base_path": r.base_path,
                "string_spec": r.string_spec,
                "path": r.path,
                "language": r.language
            } for r in inputs.imports
        ],
        "local_imports": [
            {
                "base": r.base,
                "parts": list(r.parts),
                "found": r.found,
                "path": r.path,
                "language": r.language
            } for r in inputs.local_imports
        ],
        "npm": [
            {
                "spec": r.spec,
                "base_path": r.base_path,
                "installed": r.installed,
                "entry": r.package_entry,
                "declarations": r.declarations,
                "entry_known": r.entry_known,
                "declarations_known": r.declarations_known
            } for r in inputs.npm
        ],
        "declared": [
            {
                "module_path": r.module_path,
                "fallback_app": r.fallback_app,
                "names": list(r.names) if r.names is not None else None
            } for r in inputs.declared
        ],
        "python_ifaces": [
            {
                "path": r.path,
                "pkg_dir": r.pkg_dir,
                "data": base64.b64encode(r.data).decode("ascii")
            } for r in inputs.python_ifaces
        ]
    };
}

def json_opt_str(value: object) -> (str | None) {
    if value is None {
        return None;
    }
    return str(value);
}

def inputs_from_dict(raw: dict[str, any]) -> KernelInputs {
    version = json_int(raw.get("version"), 0);
    if version != KERNEL_INPUTS_VERSION {
        raise ValueError(
            f"kernel inputs version {version} does not match {KERNEL_INPUTS_VERSION}"
        );
    }
    defaults_raw = raw.get("project_defaults");
    platform_raw = json_map(raw.get("host_platform"));
    env_raw = json_map(raw.get("ct_environment"));
    inputs = KernelInputs(
        version=version,
        entry_path=str(raw.get("entry_path", "")),
        module_projection=str(raw.get("module_projection", "")),
        target_app=str(raw.get("target_app", "")),
        request=request_from_dict(json_map(raw.get("request"))),
        project_defaults=defaults_from_dict(json_map(defaults_raw))
            if defaults_raw is not None
            else None,
        host_platform=HostPlatform(
            machine=str(platform_raw.get("machine", "")),
            python_major=json_int(platform_raw.get("python_major")),
            python_minor=json_int(platform_raw.get("python_minor"))
        ),
        ct_environment=CtEnvironment(
            os=str(env_raw.get("os", "linux")), arch=str(env_raw.get("arch", ""))
        ),
        target_triple=str(raw.get("target_triple", "")),
        target_triple_known=bool(raw.get("target_triple_known", False)),
        native_pipeline=bool(raw.get("native_pipeline", False)),
        native_pipeline_reason=str(raw.get("native_pipeline_reason", "")),
        native_pipeline_known=bool(raw.get("native_pipeline_known", False)),
        stub_catalog_active=bool(raw.get("stub_catalog_active", False)),
        stub_catalog_dir=str(raw.get("stub_catalog_dir", "")),
        stub_catalog_file=str(raw.get("stub_catalog_file", "")),
        stub_catalog_offset=json_int(raw.get("stub_catalog_offset"), 0),
        stub_catalog_length=json_int(raw.get("stub_catalog_length"), 0),
        typeshed_roots=json_str_list(raw.get("typeshed_roots")),
        search_paths=json_str_list(raw.get("search_paths")),
        native_session_active=bool(raw.get("native_session_active", False)),
        scanned_modules=json_int(raw.get("scanned_modules"), 0),
        manifest=manifest_from_dict(json_map(raw.get("manifest"))),
        layout=layout_from_dict(json_map(raw.get("layout"))),
        facts_of=json_str_map(raw.get("facts_of")),
        workspace_of=json_str_map(raw.get("workspace_of")),
        app_of=json_str_map(raw.get("app_of")),
        project_root_of=json_str_map(raw.get("project_root_of")),
        untyped=json_bool_map(raw.get("untyped")),
        siblings=json_str_map(raw.get("siblings")),
        path_aliases=json_bool_map(raw.get("path_aliases")),
        virtual_modules=json_str_map(raw.get("virtual_modules"))
    );
    for (app, check) in json_map(raw.get("check_settings")).items() {
        inputs.check_settings[app] = check_from_dict(json_map(check));
    }
    for (owner_root, facts) in json_map(raw.get("project_facts")).items() {
        inputs.project_facts[owner_root] = facts_from_dict(json_map(facts));
    }
    for (owner_root, ws) in json_map(raw.get("workspaces")).items() {
        inputs.workspaces[owner_root] = workspace_from_dict(json_map(ws));
    }
    for (path, lint) in json_map(raw.get("lint_of")).items() {
        inputs.lint_of[path] = lint_from_dict(json_map(lint));
    }
    for (path, verdict) in json_map(raw.get("verdicts")).items() {
        inputs.verdicts[path] = verdict_from_dict(json_map(verdict))
            if verdict is not None
            else None;
    }
    for r in json_maps(raw.get("imports")) {
        inputs.imports.append(
            ImportResolution(
                target=str(r.get("target", "")),
                base_path=str(r.get("base_path", "")),
                string_spec=bool(r.get("string_spec", False)),
                path=str(r.get("path", "")),
                language=str(r.get("language", ""))
            )
        );
    }
    for r in json_maps(raw.get("local_imports")) {
        inputs.local_imports.append(
            LocalResolution(
                base=str(r.get("base", "")),
                parts=json_str_list(r.get("parts")),
                found=bool(r.get("found", False)),
                path=str(r.get("path", "")),
                language=str(r.get("language", ""))
            )
        );
    }
    for r in json_maps(raw.get("npm")) {
        inputs.npm.append(
            NpmAnswer(
                spec=str(r.get("spec", "")),
                base_path=str(r.get("base_path", "")),
                installed=bool(r.get("installed", False)),
                package_entry=json_opt_str(r.get("entry")),
                declarations=json_opt_str(r.get("declarations")),
                entry_known=bool(r.get("entry_known", False)),
                declarations_known=bool(r.get("declarations_known", False))
            )
        );
    }
    for r in json_maps(raw.get("declared")) {
        inputs.declared.append(
            DeclaredDependencies(
                module_path=str(r.get("module_path", "")),
                fallback_app=str(r.get("fallback_app", "")),
                names=optional_list(r.get("names"))
            )
        );
    }
    for r in json_maps(raw.get("python_ifaces")) {
        inputs.python_ifaces.append(
            PythonInterface(
                path=str(r.get("path", "")),
                pkg_dir=str(r.get("pkg_dir", "")),
                data=base64.b64decode(str(r.get("data", "")).encode("ascii"))
            )
        );
    }
    return inputs;
}
