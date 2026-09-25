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

impl ProjectHost.note(message: str, style: str = "dim") {
    import sys;
    try {
        import from jaclang.cli.console { console }
        console.print(message, style=style, file=sys.stderr);
    } except Exception {}
}

impl ProjectHost.drop_python_lane_products(path: str, program: JacProgram) {
    import from jaclang.compiler.driver.compilation_context {
        cache_scope,
        owner_scope_options
    }
    import from jaclang.compiler.driver.jir { drop_python_lane_products }
    with cache_scope(owner_scope_options(program)) {
        try {
            drop_python_lane_products(path);
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

impl ProjectHost.native_session_declares(
    program: JacProgram, source: str, element: str
) -> (bool | None) {
    registry = program._natives;
    session = registry.session if registry is not None else None;
    if session is None {
        return None;
    }
    import from jaclang.compiler.placement.placement_facts { session_declares_native }
    return session_declares_native(
        session.options, source, element, session.registry.prog
    );
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

impl ProjectHost.record_native_verdict(
    program: JacProgram, path: str, code: str, detail: str
) {
    program.native_units().record_verdict(path, code, detail);
}

impl ProjectHost.native_analyze(
    program: JacProgram, path: str, options: CompileOptions, source: (str | None)
) -> (ModuleAnalysis | None) {
    import from jaclang.compiler.frontend.host { kernel_host_enabled }
    if program.internal or not kernel_host_enabled() {
        return None;
    }
    import from jaclang.compiler.frontend.kernel_host {
        KernelHost,
        record_kernel_session
    }
    import from jaclang.compiler.driver.module_analysis { analyze_module }
    import from jaclang.compiler.frontend.host { active_host, install_host }
    import time;
    started = time.perf_counter();
    inputs = self.kernel_inputs(program, path, options, source);
    kernel = KernelHost(
        inputs=inputs,
        fallback=self,
        closure=self.compiler_for(program).closure_options()
    );
    kernel.census.snapshot_seconds = time.perf_counter() - started;
    kernel.census.scanned_modules = inputs.scanned_modules;
    previous = active_host();
    install_host(kernel);
    try {
        return analyze_module(program, path, options, source);
    } finally {
        install_host(previous);
        kernel.replay(previous);
        record_kernel_session(kernel.census, path);
    }
}

impl ProjectHost.kernel_inputs(
    program: JacProgram, path: str, options: CompileOptions, source: (str | None) = None
) -> KernelInputs {
    import from jaclang.project.kernel_snapshot { snapshot_inputs }
    return snapshot_inputs(self, program, path, options, source);
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

impl ProjectHost.is_seed_source(rel_path: str) -> bool {
    import from jaclang.bootstrap_manifest { is_seed_source }
    return is_seed_source(rel_path);
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
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.compiler.frontend.source_layout { path_facts_of }
    return path_facts_of(host_layout_tables(), path);
}

impl ProjectHost.read_source(path: str) -> str {
    import from jaclang.project.textio { read_file_with_encoding }
    return read_file_with_encoding(path);
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
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.compiler.frontend.source_layout { is_annex_path_of }
    return is_annex_path_of(host_layout_tables(), candidate, base);
}

impl ProjectHost.package_init(directory: str) -> (str | None) {
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.compiler.frontend.source_layout { package_init_of }
    return package_init_of(host_layout_tables(), directory);
}

impl ProjectHost.host_platform -> HostPlatform {
    if self._platform is None {
        import platform;
        import sys;
        self._platform = HostPlatform(
            machine=platform.machine(),
            python_major=sys.version_info.major,
            python_minor=sys.version_info.minor
        );
    }
    return self._platform;
}

impl ProjectHost.ct_environment -> CtEnvironment {
    import sys;
    import platform;
    import from jaclang.compiler.types.ct_value { CtEnvironment }
    host_os = "linux";
    if sys.platform.startswith("win") {
        host_os = "windows";
    } elif sys.platform == "darwin" {
        host_os = "darwin";
    }
    return CtEnvironment(os=host_os, arch=platform.machine());
}

impl ProjectHost.stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
    return self.compiler_for(program).stub_catalog();
}

impl ProjectHost.parse_python(
    source_str: str, file_path: str, program: JacProgram
) -> tuple[Module, bool] {
    import ast as py_ast;
    import jaclang.compiler.frontend.unitree as uni;
    import from jaclang.compiler.driver.pipeline_runner { run_utility, UtilityProduct }
    built = run_utility(
        UtilityProduct.PYTHON_AST,
        uni.PythonModuleAst(
            py_ast.parse(source_str),
            orig_src=uni.Source(source_str, mod_path=file_path)
        ),
        program,
        cancel_token=program.options.cancel_token if program.options else None
    );
    return (built.module, len(built.ctx.errors_had) > 0);
}

impl UnitCollectBudget.due -> bool {
    import os;
    import sys;
    def env_int(name: str, fallback: int) -> int {
        raw = os.environ.get(name, "").strip();
        if not raw {
            return fallback;
        }
        try {
            return int(raw);
        } except ValueError {
            return fallback;
        }
    }
    def peak_rss_mb -> int {
        try {
            import resource;
        } except ImportError {
            return 0;
        }
        peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
        if sys.platform == "darwin" {
            return int(peak // (1024 * 1024));
        }
        return int(peak // 1024);
    }
    self.releases += 1;
    every = env_int("JAC_UNIT_COLLECT_EVERY", UNIT_COLLECT_EVERY);
    growth = env_int("JAC_UNIT_COLLECT_GROWTH_MB", UNIT_COLLECT_GROWTH_MB);
    peak = peak_rss_mb();
    if self.last_peak_mb == 0 {
        self.last_peak_mb = peak;
    }
    by_count = every > 0 and self.releases >= every;
    by_growth = growth > 0 and (peak - self.last_peak_mb) >= growth;
    if not (by_count or by_growth) {
        return False;
    }
    self.releases = 0;
    self.last_peak_mb = peak;
    return True;
}

impl ProjectHost.compile_module(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> Module {
    return self.compiler_for(program).compile(
        file_path=file_path, target_program=program, use_str=use_str, options=options
    );
}

impl ProjectHost.build_module(
    program: JacProgram, file_path: str, use_str: (str | None)
) -> Module {
    return self.compiler_for(program).build(file_path, program, use_str);
}

impl ProjectHost.internal_program(program: JacProgram) -> (JacProgram | None) {
    return self.compiler_for(program).selfhost.peek_program();
}

impl ProjectHost.bind_context_program(context_root: JacProgram, program: JacProgram) {
    program._compiler = self.compiler_for(context_root);
    root_iface = context_root._iface;
    if root_iface is not None and root_iface.verifying {
        self.iface_registry_for(program).verifying = True;
    }
}

impl ProjectHost.note_program_dependency(program: JacProgram, resolved_path: str) {
    try {
        self.iface_registry_for(program).note_dep(resolved_path);
    } except Exception {}
}

impl ProjectHost.forget_program_products(program: JacProgram, resolved_path: str) {
    if program._natives is not None {
        program._natives.forget(resolved_path);
    }
    if program._iface is not None {
        program._iface.forget(resolved_path);
    }
}

impl ProjectHost.release_program_products(program: JacProgram, retain_stubs: bool) {
    natives = program._natives;
    if natives is not None and natives.session is None {
        if retain_stubs {
            natives.release_products();
        } else {
            natives.clear();
        }
    }
    if program._iface is not None {
        program._iface.on_closure_release();
    }
}

impl ProjectHost.prepare_interface(
    program: JacProgram, path: str, module: Module
) -> bool {
    return bool(self.iface_registry_for(program).prepare_interface(path, module));
}

impl ProjectHost.collect_released_memory{
    if self._collect_budget.due() {
        import gc;
        gc.collect();
    }
}

impl ProjectHost.load_modules(names: list[str]) {
    import importlib;
    for name in names {
        try {
            importlib.import_module(name);
        } except ImportError as err {
            import from jaclang.compiler.driver.source_failures {
                fail_loud_on_compiler_source
            }
            fail_loud_on_compiler_source(err);
            raise;
        }
    }
}

impl ProjectHost.module_in_flight(names: list[str]) -> str {
    import sys;
    for name in names {
        spec = sys.modules.get(name)?.__spec__;
        if spec is not None and getattr(spec, '_initializing', False) {
            return name;
        }
    }
    return '';
}

impl ProjectHost.import_in_flight(path: str) -> bool {
    import from jaclang.compiler.driver.source_failures { module_import_in_flight }
    return module_import_in_flight(path);
}

impl ProjectHost.has_active_stub_catalog -> bool {
    import from jaclang.jac0core.stubcat_hook { active }
    return active() is not None;
}

impl ProjectHost.is_native_only_source(rel: str) -> bool {
    import from jaclang.bootstrap_manifest { is_native_only }
    return is_native_only(rel);
}

impl ProjectHost.is_native_lowered_source(rel: str) -> bool {
    import from jaclang.bootstrap_manifest { is_native_lowered }
    return is_native_lowered(rel);
}

impl ProjectHost.default_target_triple -> str {
    try {
        import from jaclang.compiler.backends.native.llvm.binding { get_default_triple }
        return str(get_default_triple());
    } except Exception {
        return "";
    }
}
