import json;
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

glob KERNEL_INPUTS_VERSION: int = 1;

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
        imports: list[ImportResolution] = [],
        local_imports: list[LocalResolution] = [],
        npm: list[NpmAnswer] = [],
        declared: list[DeclaredDependencies] = [];

    def to_json -> str {
        return json.dumps(inputs_to_dict(self), sort_keys=True);
    }

    static def from_json(text: str) -> KernelInputs {
        return inputs_from_dict(json.loads(text));
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

def check_to_dict(check: CheckSettings) -> dict[str, any] {
    return {
        "suppress": list(check.suppress),
        "suppress_categories": list(check.suppress_categories),
        "lint_active": check.lint_active,
        "lint_select": list(check.lint_select),
        "lint_ignore": list(check.lint_ignore),
        "enforce_access": check.enforce_access,
        "untyped_external_error": check.untyped_external_error
    };
}

def check_from_dict(raw: dict[str, any]) -> CheckSettings {
    return CheckSettings(
        suppress=[str(x) for x in raw.get("suppress", [])],
        suppress_categories=[str(x) for x in raw.get("suppress_categories", [])],
        lint_active=bool(raw.get("lint_active", False)),
        lint_select=[str(x) for x in raw.get("lint_select", [])],
        lint_ignore=[str(x) for x in raw.get("lint_ignore", [])],
        enforce_access=bool(raw.get("enforce_access", False)),
        untyped_external_error=bool(raw.get("untyped_external_error", False))
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
        "check": check_to_dict(defaults.check)
    };
}

def defaults_from_dict(raw: dict[str, any]) -> ProjectDefaults {
    return ProjectDefaults(
        default_codespace=str(raw["default_codespace"]),
        native_closure_cap=int(raw["native_closure_cap"]),
        native_require=[str(x) for x in raw["native_require"]],
        native_target=str(raw["native_target"]),
        native_debug=bool(raw["native_debug"]),
        native_opt=int(raw["native_opt"]),
        native_threads=int(raw["native_threads"]),
        native_link_mode=str(raw["native_link_mode"]),
        memory_profile=str(raw["memory_profile"]),
        memory_enforce=[str(x) for x in raw["memory_enforce"]],
        memory_exempt=[str(x) for x in raw["memory_exempt"]],
        check=check_from_dict(raw["check"])
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
        project_root=str(raw["project_root"]),
        check=check_from_dict(raw["check"]),
        arch_closed=[str(x) for x in raw.get("arch_closed", [])],
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
        check=check_from_dict(raw["check"]),
        exclude=[str(x) for x in raw.get("exclude", [])],
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
        name=str(raw["name"]),
        kind=str(raw.get("kind", "")),
        `entry=str(raw.get("entry", "")),
        ui=str(raw.get("ui", "")),
        platform=str(raw.get("platform", "")),
        route=str(raw.get("route", "")),
        pins={str(k): str(v) for (k, v) in dict(raw.get("pins", {})).items()},
        npm_names={str(x) for x in raw.get("npm_names", [])},
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
    for entry_raw in raw.get("apps", []) {
        app = app_from_dict(entry_raw);
        apps[app.name] = app;
    }
    return WorkspaceSpec(
        project_root=str(raw["project_root"]),
        toml_path=str(raw["toml_path"]),
        apps=apps,
        default_app=str(raw.get("default_app", "")),
        explicit=bool(raw.get("explicit", False)),
        digest=str(raw.get("digest", "")),
        base_pins={str(k): str(v) for (k, v) in dict(raw.get("base_pins", {})).items()},
        base_npm_names={str(x) for x in raw.get("base_npm_names", [])}
    );
}

def verdict_to_dict(verdict: (NativeVerdict | None)) -> (dict[str, any] | None) {
    if verdict is None {
        return None;
    }
    return {"demoted": verdict.demoted, "code": verdict.code, "detail": verdict.detail};
}

def verdict_from_dict(raw: (dict[str, any] | None)) -> (NativeVerdict | None) {
    if raw is None {
        return None;
    }
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
    folders = dict(raw.get("annex_folders", {}));
    ordered: dict[str, str] = {};
    for suffix in raw.get("annex_order", list(folders.keys())) {
        ordered[str(suffix)] = str(folders[suffix]);
    }
    return LayoutTables(
        jac_suffix=str(raw.get("jac_suffix", ".jac")),
        annex_folders=ordered,
        module_suffixes=[str(x) for x in raw.get("module_suffixes", [])],
        init_files=[str(x) for x in raw.get("init_files", [])],
        stem_rekey_suffixes=[str(x) for x in raw.get("stem_rekey_suffixes", [])],
        foreign_suffixes=[str(x) for x in raw.get("foreign_suffixes", [])],
        retired_native=[str(x) for x in raw.get("retired_native", [])],
        retired_client=[str(x) for x in raw.get("retired_client", [])]
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
        seed_paths=[str(x) for x in raw.get("seed_paths", [])],
        native_only_files=[str(x) for x in raw.get("native_only_files", [])],
        native_only_dirs=[str(x) for x in raw.get("native_only_dirs", [])],
        native_lowered=[str(x) for x in raw.get("native_lowered", [])]
    );
}

def optional_list(raw: any) -> (list[str] | None) {
    if raw is None {
        return None;
    }
    return [str(x) for x in raw];
}

def inputs_to_dict(inputs: KernelInputs) -> dict[str, any] {
    defaults = inputs.project_defaults;
    return {
        "version": inputs.version,
        "entry_path": inputs.entry_path,
        "module_projection": inputs.module_projection,
        "target_app": inputs.target_app,
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
        ]
    };
}

def inputs_from_dict(raw: dict[str, any]) -> KernelInputs {
    version = int(raw.get("version", 0));
    if version != KERNEL_INPUTS_VERSION {
        raise ValueError(
            f"kernel inputs version {version} does not match {KERNEL_INPUTS_VERSION}"
        );
    }
    defaults_raw = raw.get("project_defaults");
    platform_raw = dict(raw.get("host_platform", {}));
    env_raw = dict(raw.get("ct_environment", {}));
    return KernelInputs(
        version=version,
        entry_path=str(raw.get("entry_path", "")),
        module_projection=str(raw.get("module_projection", "")),
        target_app=str(raw.get("target_app", "")),
        project_defaults=defaults_from_dict(defaults_raw)
            if defaults_raw is not None
            else None,
        check_settings={
            str(app): check_from_dict(check)
            for (app, check) in dict(raw.get("check_settings", {})).items()
        },
        host_platform=HostPlatform(
            machine=str(platform_raw.get("machine", "")),
            python_major=int(platform_raw.get("python_major", 0)),
            python_minor=int(platform_raw.get("python_minor", 0))
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
        typeshed_roots=[str(x) for x in raw.get("typeshed_roots", [])],
        search_paths=[str(x) for x in raw.get("search_paths", [])],
        native_session_active=bool(raw.get("native_session_active", False)),
        scanned_modules=int(raw.get("scanned_modules", 0)),
        manifest=manifest_from_dict(dict(raw.get("manifest", {}))),
        layout=layout_from_dict(dict(raw.get("layout", {}))),
        project_facts={
            str(owner_root): facts_from_dict(facts)
            for (owner_root, facts) in dict(raw.get("project_facts", {})).items()
        },
        workspaces={
            str(owner_root): workspace_from_dict(ws)
            for (owner_root, ws) in dict(raw.get("workspaces", {})).items()
        },
        facts_of={str(k): str(v) for (k, v) in dict(raw.get("facts_of", {})).items()},
        workspace_of={
            str(k): str(v) for (k, v) in dict(raw.get("workspace_of", {})).items()
        },
        app_of={str(k): str(v) for (k, v) in dict(raw.get("app_of", {})).items()},
        project_root_of={
            str(k): str(v) for (k, v) in dict(raw.get("project_root_of", {})).items()
        },
        lint_of={
            str(path): lint_from_dict(lint)
            for (path, lint) in dict(raw.get("lint_of", {})).items()
        },
        verdicts={
            str(path): verdict_from_dict(verdict)
            for (path, verdict) in dict(raw.get("verdicts", {})).items()
        },
        untyped={str(k): bool(v) for (k, v) in dict(raw.get("untyped", {})).items()},
        siblings={str(k): str(v) for (k, v) in dict(raw.get("siblings", {})).items()},
        path_aliases={
            str(k): bool(v) for (k, v) in dict(raw.get("path_aliases", {})).items()
        },
        imports=[
            ImportResolution(
                target=str(r["target"]),
                base_path=str(r["base_path"]),
                string_spec=bool(r.get("string_spec", False)),
                path=str(r.get("path", "")),
                language=str(r.get("language", ""))
            ) for r in raw.get("imports", [])
        ],
        local_imports=[
            LocalResolution(
                base=str(r["base"]),
                parts=[str(x) for x in r.get("parts", [])],
                found=bool(r.get("found", False)),
                path=str(r.get("path", "")),
                language=str(r.get("language", ""))
            ) for r in raw.get("local_imports", [])
        ],
        npm=[
            NpmAnswer(
                spec=str(r["spec"]),
                base_path=str(r["base_path"]),
                installed=bool(r.get("installed", False)),
                package_entry=r.get("entry"),
                declarations=r.get("declarations"),
                entry_known=bool(r.get("entry_known", False)),
                declarations_known=bool(r.get("declarations_known", False))
            ) for r in raw.get("npm", [])
        ],
        declared=[
            DeclaredDependencies(
                module_path=str(r["module_path"]),
                fallback_app=str(r.get("fallback_app", "")),
                names=optional_list(r.get("names"))
            ) for r in raw.get("declared", [])
        ]
    );
}
