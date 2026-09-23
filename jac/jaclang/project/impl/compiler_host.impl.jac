impl ProjectHost.session -> Iterator[None] {
    import from jaclang.project.workspace { workspace_scope }
    import from jaclang.compiler.driver.wiring { wiring_scope }
    with workspace_scope(), wiring_scope() {
        yield ;
    }
}

impl ProjectHost.project_defaults -> (ProjectDefaults | None) {
    if self._defaults_active {
        return self._last_defaults;
    }
    self._defaults_active = True;
    try {
        cfg: any = None;
        try {
            import from jaclang.project.config { get_config }
            cfg = get_config();
        } except Exception {
            return None;
        }
        if cfg is None {
            import from jaclang.project.config { JacConfig }
            cfg = JacConfig();
        }
        self._last_defaults = project_defaults_of(cfg);
        return self._last_defaults;
    } finally {
        self._defaults_active = False;
    }
}

impl ProjectHost.check_settings(target_app: str) -> CheckSettings {
    cfg: any = None;
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
    } except Exception {
        return CheckSettings();
    }
    if cfg is None {
        return CheckSettings();
    }
    if target_app and isinstance(cfg.apps, dict) and target_app in cfg.apps {
        try {
            cfg = cfg.effective_for_app(target_app);
        } except Exception {}
    }
    return check_settings_of(cfg.check);
}

impl ProjectHost.project_facts(path: str) -> (ProjectFacts | None) {
    import from pathlib { Path }
    try {
        import from jaclang.project.config { get_config_for_path }
        cfg = get_config_for_path(Path(path));
    } except Exception {
        return None;
    }
    if cfg is None or cfg.project_root is None {
        return None;
    }
    project_root = str(cfg.project_root);
    cached = self._facts.get(project_root);
    if cached is not None and cached[0] is cfg {
        return cached[1];
    }
    facts = ProjectFacts(
        project_root=project_root,
        check=check_settings_of(cfg.check),
        arch_closed=list(cfg.arch.closed),
        client_framework=cfg.client.framework if cfg.client else "react"
    );
    self._facts[project_root] = (cfg, facts);
    return facts;
}

impl ProjectHost.workspace(path: str) -> (WorkspaceSpec | None) {
    if not path {
        return None;
    }
    import from jaclang.project.workspace { workspace_for_path }
    return workspace_for_path(path);
}

impl ProjectHost.app_for_path(path: str) -> (AppSpec | None) {
    import from jaclang.project.workspace { app_for_path }
    return app_for_path(path);
}

impl ProjectHost.project_root(path: str) -> (str | None) {
    import from jaclang.project.modresolver { find_jac_project_root }
    return find_jac_project_root(path);
}

impl ProjectHost.declared_dependencies(
    module_path: str, fallback_app: str
) -> (list[str] | None) {
    import from pathlib { Path }
    try {
        import from jaclang.project.config { get_config_for_path }
        cfg = get_config_for_path(Path(module_path));
    } except Exception {
        return None;
    }
    if cfg is None {
        return None;
    }
    names: list[str] = [*cfg.dependencies, *cfg.dev_dependencies];
    owner = cfg.app_for_path(str(Path(module_path).resolve()));
    app_name = owner.name if owner is not None else fallback_app;
    if app_name and app_name in cfg.apps {
        try {
            app_cfg = cfg.effective_for_app(app_name);
            names.extend([*app_cfg.dependencies, *app_cfg.dev_dependencies]);
        } except Exception {}
    }
    return [str(n) for n in names];
}

impl ProjectHost.resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[str, str] {
    import from jaclang.project.modresolver { resolve_module }
    return resolve_module(target, base_path, string_spec=string_spec);
}

impl ProjectHost.is_path_alias(target: str, base_path: str) -> bool {
    import from jaclang.project.modresolver { is_path_alias_import }
    return is_path_alias_import(target, base_path);
}

impl ProjectHost.is_untyped_third_party(path: str) -> bool {
    import from jaclang.project.modresolver { is_untyped_third_party_module }
    return is_untyped_third_party_module(path);
}

impl ProjectHost.in_typeshed_tree(path: str) -> bool {
    import from jaclang.project.modresolver { in_typeshed_tree }
    return in_typeshed_tree(path);
}

impl ProjectHost.sibling_declaration(js_path: str) -> (str | None) {
    import from jaclang.project.modresolver { sibling_declaration_file }
    return sibling_declaration_file(js_path);
}

impl ProjectHost.has_npm_package(spec: str, base_path: str) -> bool {
    import from jaclang.project.modresolver { has_client_npm_package }
    return has_client_npm_package(spec, base_path);
}

impl ProjectHost.resolve_npm_package(spec: str, base_path: str) -> (str | None) {
    import from jaclang.project.modresolver { resolve_client_npm_package }
    return resolve_client_npm_package(spec, base_path);
}

impl ProjectHost.npm_declarations(spec: str, base_path: str) -> (str | None) {
    import from jaclang.project.modresolver { resolve_client_npm_declarations }
    return resolve_client_npm_declarations(spec, base_path);
}

impl ProjectHost.native_pipeline_available -> tuple[bool, str] {
    import from jaclang.compiler.driver.toolchain { native_pipeline_available }
    return native_pipeline_available();
}

impl ProjectHost.note(message: str) {
    import sys;
    try {
        import from jaclang.cli.console { console }
        console.print(message, style="dim", file=sys.stderr);
    } except Exception {}
}

impl ProjectHost.discard_module_artifact(path: str, program: JacProgram) {
    import from jaclang.compiler.driver.compilation_context {
        cache_scope,
        owner_scope_options
    }
    import from jaclang.compiler.driver.jir { get_module_cache_path }
    with cache_scope(owner_scope_options(program)) {
        try {
            get_module_cache_path(path).unlink(missing_ok=True);
        } except OSError {}
    }
}

impl ProjectHost.lint_settings(path: str) -> LintSettings {
    import from pathlib { Path }
    import from jaclang.compiler.driver.compilation_context { context_app }
    import from jaclang.project.config {
        JacConfig,
        get_config_for_path,
        get_explicit_config
    }
    config = (get_config_for_path(Path(path)) if path else get_explicit_config())
        or JacConfig();
    if path {
        app = context_app(str(Path(path).resolve()));
        if app is not None and not app.implicit and app.name in config.apps {
            config = config.effective_for_app(app.name);
        }
    }
    lint = config.check.lint if config.check else None;
    return LintSettings(
        check=check_settings_of(config.check),
        exclude=list(lint.exclude) if lint else [],
        project_root=str(config.project_root) if (lint and config.project_root) else ""
    );
}

impl ProjectHost.compiler_for(program: JacProgram) -> JacCompiler {
    if program._compiler is None {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        program._compiler = JacCompiler();
    }
    return program._compiler;
}

impl ProjectHost.iface_registry_for(program: JacProgram) -> IfaceRegistry {
    if program._iface is None {
        import from jaclang.compiler.driver.ifacecache { IfaceRegistry }
        program._iface = IfaceRegistry(prog=program);
    }
    return program._iface;
}

impl ProjectHost.native_units_for(program: JacProgram) -> NativeUnitRegistry {
    if program._natives is None {
        import from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
        program._natives = NativeUnitRegistry(prog=program);
    }
    return program._natives;
}

impl ProjectHost.native_verdict(
    path: str, program: (JacProgram | None) = None
) -> (NativeVerdict | None) {
    try {
        if program is not None {
            return program.native_units().verdict_for(path);
        }
        import from jaclang.compiler.driver.nativecache { read_native_verdict }
        return read_native_verdict(path);
    } except Exception {
        return None;
    }
}

impl ProjectHost.record_native_coverage(
    path: str, outcome: str, code: str = "", detail: str = ""
) {
    import from jaclang.compiler.driver.na_coverage { na_coverage_record }
    na_coverage_record(path, outcome, code, detail);
}

impl ProjectHost.format_file(file_path: str, auto_lint: bool = False) -> JacProgram {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    return JacCompiler.jac_file_formatter(file_path, auto_lint);
}

impl ProjectHost.format_source(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    return JacCompiler.jac_str_formatter(source_str, file_path, auto_lint);
}

impl ProjectHost.lint_file(file_path: str) -> JacProgram {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    return JacCompiler.jac_file_linter(file_path);
}

impl ProjectHost.wiring_file(path: str) -> (str | None) {
    import from jaclang.compiler.driver.wiring { arch_file_for, is_arch_file }
    if is_arch_file(path) {
        return None;
    }
    return arch_file_for(path);
}

impl ProjectHost.native_parse(
    source_str: str,
    file_path: str,
    program: (JacProgram | None),
    annexes: list[WovenAnnex],
    early_context: str = ""
) -> (tuple[Module, bool] | None) {
    import from jaclang.compiler.frontend.parser.frontend { finish_parse }
    import jaclang.compiler.native_compiler as _jc;
    kernel = _jc.ensure_loaded();
    if kernel is None {
        return None;
    }
    kernel.prepare_early(early_context if program is not None else "");
    for annex in annexes {
        kernel.annex(annex);
    }
    if kernel.run(source_str, file_path) != 0 {
        return None;
    }
    module = kernel.take_module();
    if module is None {
        return None;
    }
    p_errs = kernel.err_count();
    lex_errs = kernel.lex_errs();
    p_diags = kernel.take_diags();
    lex_diags = kernel.take_lexdiags();
    comments = kernel.take_comments();
    had_error = finish_parse(
        module, p_errs, p_diags, comments, lex_diags, lex_errs, program
    );
    if program is not None {
        results = kernel.take_pass_results();
        if results {
            program.analysis.record_early(module, results);
        }
    }
    return (module, had_error);
}

impl ProjectHost.resolve_local_module(
    base: str, parts: list[str]
) -> (tuple[str, str] | None) {
    import from jaclang.project.modresolver { resolve_local_module }
    return resolve_local_module(base, parts);
}

impl ProjectHost.path_facts(path: str) -> PathFacts {
    import os;
    import from jaclang.jac0core.ext_registry {
        STEM_REKEY_SUFFIXES,
        base_stem,
        is_annex,
        is_jac,
        is_retired_client_marker,
        is_retired_native_marker
    }
    marker = "";
    if is_retired_native_marker(path) {
        marker = "native";
    } elif is_retired_client_marker(path) {
        marker = "client";
    }
    name = os.path.basename(path);
    dot = name.rfind(".");
    stem = name[:dot] if dot > 0 else name;
    for suffix in STEM_REKEY_SUFFIXES {
        if stem.endswith(suffix) {
            stem = stem[:-len(suffix)];
            break;
        }
    }
    return PathFacts(
        is_jac=is_jac(path),
        is_annex=is_annex(path),
        retired_marker=marker,
        module_stem=base_stem(path),
        scope_stem=stem
    );
}

impl ProjectHost.annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
    import from jaclang.compiler.driver.bccache { discover_annex_files }
    return discover_annex_files(path, suffix);
}

impl ProjectHost.base_file(annex_path: str) -> (str | None) {
    import from jaclang.compiler.driver.bccache { discover_base_file }
    return discover_base_file(annex_path);
}

impl ProjectHost.is_annex_path_of(candidate: str, base: str) -> bool {
    import from jaclang.jac0core.ext_registry { is_annex_path_of }
    return is_annex_path_of(candidate, base);
}

impl ProjectHost.package_init(directory: str) -> (str | None) {
    import os;
    import from jaclang.jac0core.ext_registry { INIT_FILES }
    for name in INIT_FILES {
        candidate = os.path.join(directory, name);
        if os.path.exists(candidate) {
            return candidate;
        }
    }
    return None;
}
