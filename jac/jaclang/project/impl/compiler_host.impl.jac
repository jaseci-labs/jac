impl HostSession.closure_options -> (CompileOptions | None) {
    return self.closure;
}

impl HostSession.run_module(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> Module {
    task = analyze_module(target_program, file_path, options, use_str)
        if options.no_cgen or options.symtab_ir_only
        else compile_task(self, target_program, file_path, options, use_str);
    self.host.analyses[os.path.realpath(file_path)] = task;
    self.host.record_unit(task);
    return task.module;
}

impl ProjectHost.postinit {
    self._session = HostSession(host=self, closure=self.closure);
}

impl ProjectHost.close_over(options: CompileOptions) {
    self.closure = options;
    if self._session is not None {
        self._session.closure = options;
    }
}

impl ProjectHost.record_unit(task: ModuleAnalysis) {
    if task.parse_failed or task.blocked or not task.ready(CompilationProduct.PY_IR) {
        return;
    }
    module = task.module;
    real = os.path.realpath(task.path);
    products = unit_products(module, task.program);
    if not products.path {
        products.path = real;
    }
    lowered = self._lowered.get(real);
    if lowered is not None and lowered is not module and not products.native_ir {
        native_products(lowered, products);
    }
    self.units[real] = products;
}

impl ProjectHost.forget_unit(path: str) {
    real = os.path.realpath(path);
    self.analyses.pop(real, None);
    self.units.pop(real, None);
    self._native_ifaces.pop(real, None);
    self._lowered.pop(real, None);
    self.grown.discard(real);
    self._facts.clear();
    self._last_defaults = None;
}

impl ProjectHost.project_config(path: str = "") -> JacConfig {
    start = path or self.root;
    if not start {
        raise RuntimeError(
            "the kernel host has no project root: a request names no project and no path"
        );
    }
    cfg = get_config_for_path(Path(start));
    return cfg if cfg is not None else JacConfig();
}

impl ProjectHost.session -> Iterator[None] {
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
        self._last_defaults = project_defaults_of(self.project_config());
        return self._last_defaults;
    } finally {
        self._defaults_active = False;
    }
}

impl ProjectHost.check_settings(target_app: str) -> CheckSettings {
    cfg = self.project_config();
    if target_app and target_app in cfg.apps {
        cfg = cfg.effective_for_app(target_app);
    }
    return check_settings_of(cfg.check);
}

impl ProjectHost.project_facts(path: str) -> (ProjectFacts | None) {
    cfg = get_config_for_path(Path(path));
    if cfg is None or cfg.project_root is None {
        return None;
    }
    project_root = str(cfg.project_root);
    cached = self._facts.get(project_root);
    if cached is not None {
        return cached;
    }
    facts = ProjectFacts(
        project_root=project_root,
        check=check_settings_of(cfg.check),
        client_framework=cfg.client.framework,
        package_name=package_name_of(cfg.project.name),
        package_exports=list(cfg.project.exports),
        package_mounts=project_mounts_dir(project_root)
    );
    self._facts[project_root] = facts;
    return facts;
}

impl ProjectHost.workspace(path: str) -> (WorkspaceSpec | None) {
    if not path {
        return None;
    }
    return workspace_for_path(path);
}

impl ProjectHost.app_for_path(path: str) -> (AppSpec | None) {
    return app_for_path(path);
}

impl ProjectHost.project_root(path: str) -> (str | None) {
    return find_jac_project_root(path);
}

impl ProjectHost.declared_dependencies(
    module_path: str, fallback_app: str
) -> (list[str] | None) {
    cfg = get_config_for_path(Path(module_path));
    if cfg is None {
        return None;
    }
    scopes = [cfg];
    owner = cfg.app_for_path(os.path.realpath(module_path));
    app_name = owner.name if owner is not None else fallback_app;
    if app_name and app_name in cfg.apps {
        scopes.append(cfg.effective_for_app(app_name));
    }
    names: list[str] = [];
    for scope in scopes {
        names.extend(scope.dependencies.keys());
        names.extend(scope.dev_dependencies.keys());
        names.extend(scope.pypi_dependencies.keys());
        names.extend(scope.pypi_dev_dependencies.keys());
    }
    return names;
}

impl ProjectHost.resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[str, str] {
    return resolve_module(target, base_path, string_spec=string_spec);
}

impl ProjectHost.resolve_local_module(
    base: str, parts: list[str]
) -> (tuple[str, str] | None) {
    return resolve_local_module(base, parts);
}

impl ProjectHost.jac_virtual_module_path(target: str) -> (str | None) {
    return resolve_jac_virtual_module_path(target);
}

impl ProjectHost.is_path_alias(target: str, base_path: str) -> bool {
    return is_path_alias_import(target, base_path);
}

impl ProjectHost.is_untyped_third_party(path: str) -> bool {
    return is_untyped_third_party_module(path);
}

impl ProjectHost.in_typeshed_tree(path: str) -> bool {
    return in_typeshed_tree(path);
}

impl ProjectHost.sibling_declaration(js_path: str) -> (str | None) {
    return sibling_declaration_file(js_path);
}

impl ProjectHost.has_npm_package(spec: str, base_path: str) -> bool {
    return has_client_npm_package(spec, base_path);
}

impl ProjectHost.resolve_npm_package(spec: str, base_path: str) -> (str | None) {
    return resolve_client_npm_package(spec, base_path);
}

impl ProjectHost.npm_declarations(spec: str, base_path: str) -> (str | None) {
    return resolve_client_npm_declarations(spec, base_path);
}

impl ProjectHost.native_pipeline_available -> tuple[bool, str] {
    return native_pipeline_available();
}

impl ProjectHost.note(message: str, style: str = "dim") {
    sys.stderr.write(message + "\n");
}

impl ProjectHost.drop_python_lane_products(path: str, program: JacProgram) {
    with cache_scope(owner_scope_options(program)) {
        drop_python_lane_products(path);
    }
}

impl ProjectHost.lint_settings(path: str) -> LintSettings {
    config = self.project_config(path);
    if path {
        owner = (self.base_file(path) or path)
            if self.path_facts(path).is_annex
            else path;
        app = context_app(os.path.realpath(owner));
        if app is not None and not app.implicit and app.name in config.apps {
            config = config.effective_for_app(app.name);
        }
    }
    lint = config.check.lint;
    return LintSettings(
        check=check_settings_of(config.check),
        exclude=list(lint.exclude),
        project_root=str(config.project_root) if config.project_root else ""
    );
}

impl ProjectHost.compiler_for(program: JacProgram) -> JacCompiler {
    import from jaclang.compiler.driver.compiler { JacCompiler }
    if program._compiler is None {
        program._compiler = JacCompiler();
    }
    return program._compiler;
}

impl ProjectHost.iface_registry_for(program: JacProgram) -> IfaceRegistry {
    import from jaclang.compiler.driver.ifacecache { IfaceRegistry }
    if program._iface is None {
        program._iface = IfaceRegistry(prog=program);
    }
    return program._iface;
}

impl ProjectHost.native_units_for(program: JacProgram) -> NativeUnitRegistry {
    import from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
    if program._natives is None {
        program._natives = NativeUnitRegistry(prog=program);
    }
    return program._natives;
}

impl ProjectHost.native_session_declares(
    program: JacProgram, source: str, element: str
) -> (bool | None) {
    import from jaclang.compiler.placement.placement_facts { session_declares_native }
    registry = program._natives;
    session = registry.session if registry is not None else None;
    if session is None {
        return None;
    }
    return session_declares_native(
        session.options, source, element, session.registry.prog
    );
}

impl ProjectHost.client_boundary_facts(
    program: JacProgram, path: str
) -> (list[str] | None) {
    return self.iface_registry_for(program).client_boundary_facts(path);
}

impl ProjectHost.in_compiler_tree(path: str) -> bool {
    return is_compiler_tree_path(path);
}

impl ProjectHost.schedule_import_failed(err: ImportError) {
    raise err;
}

impl ProjectHost.client_osp_core_js -> str {
    return osp_core_js();
}

impl ProjectHost.client_pulls(path: str) -> str {
    return cached_client_pulls(path);
}

impl ProjectHost.client_stub_globals -> list[str] {
    if not self._stub_globals {
        stub_dir = os.path.join(jaclang_pkg_root(), "compiler", "types");
        names: set[str] = set();
        for stub in ("js_globals.pyi", "dom_types.pyi") {
            names.update(python_top_level_names(os.path.join(stub_dir, stub)));
        }
        self._stub_globals.extend(sorted(names));
    }
    return list(self._stub_globals);
}

impl ProjectHost.native_dep_iface(
    program: JacProgram, path: str, options: CompileOptions
) -> (NativeIface | None) {
    real = os.path.realpath(path);
    known = self._native_ifaces.get(real);
    if known is not None {
        return known;
    }
    if real in self._lowering {
        return None;
    }
    found: (NativeIface | None) = None;
    text = self.held_native_iface(program, real, options);
    if text {
        found = NativeIface.from_bytes(text.encode("utf-8"));
        if found is None {
            raise RuntimeError(f"the native interface cached for {real} is unreadable");
        }
        found.resolve_deps(real);
    } else {
        found = self.lower_dependency(program, real, options);
    }
    if found is not None {
        self._native_ifaces[real] = found;
    }
    return found;
}

impl ProjectHost.native_dep_discovery_open(program: JacProgram) -> bool {
    return self.native_units_for(program).dep_discovery_open();
}

impl ProjectHost.native_deps_deferred(program: JacProgram) -> bool {
    return self.native_units_for(program).close_dep_deferral();
}

impl ProjectHost.held_native_iface(
    program: JacProgram, path: str, options: CompileOptions
) -> str {
    ent = self.native_units_for(program).ensure(
        path,
        compile_on_miss=False,
        options=options,
        check_deps=False,
        products=not options.no_cgen
    );
    return ent.iface.to_bytes().decode("utf-8") if ent is not None else "";
}

impl ProjectHost.lower_dependency(
    program: JacProgram, real: str, options: CompileOptions
) -> (NativeIface | None) {
    self._lowering.add(real);
    previous = program.options;
    codespace = get_effective_default_codespace_override();
    mark = len(program.errors_had);
    try {
        opts = options.clone_for_native_import();
        opts.no_cgen = True;
        module = self.compile_module(program, real, None, opts);
        if len(program.errors_had) > mark {
            return None;
        }
        opts.no_cgen = False;
        program.options = opts;
        set_effective_default_codespace("native");
        if not product_ready(program, module, CompilationProduct.ANALYSIS)
            and not require(program, module, CompilationProduct.ANALYSIS) {
            return None;
        }
        require(program, module, CompilationProduct.NATIVE_LOWER);
        if len(program.errors_had) > mark {
            return None;
        }
        if module.gen.native_iface is not None {
            self.grown.add(real);
            self._lowered[real] = module;
        }
        return module.gen.native_iface;
    } finally {
        program.options = previous;
        set_effective_default_codespace(codespace);
        self._lowering.discard(real);
    }
}

impl ProjectHost.native_lowering_failed(program: JacProgram, path: str, detail: str) {
    self.native_units_for(program).failures[os.path.realpath(path)] = detail;
}

impl ProjectHost.save_native_debug_ir(path: str, text: str) {
    stem = os.path.splitext(os.path.basename(path))[0];
    ir_dir = str(get_native_debug_dir(path));
    os.makedirs(ir_dir, exist_ok=True);
    saved = os.path.join(ir_dir, stem + ".ll");
    with open(saved, "w") as f {
        f.write(text);
    }
    self.note(f"[native debug] IR saved to: {saved}", style="info");
}

impl ProjectHost.native_fact(kind: str, key: str) -> str {
    import from jaclang.compiler.backends.native.host_facts { host_native_fact }
    return host_native_fact(kind, key);
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
    if is_arch_file(path) {
        return None;
    }
    return arch_file_for(path);
}

impl ProjectHost.wiring_records(digest: str) -> str {
    path = wiring_records_path(digest);
    if not os.path.isfile(path) {
        return "";
    }
    with open(path, "r", encoding="utf-8") as f {
        return f.read();
    }
}

impl ProjectHost.keep_wiring_records(digest: str, text: str) {
    write_record(wiring_records_path(digest), text);
}

impl ProjectHost.native_scan_record(path: str, digest: str) -> str {
    store = native_scan_path(path, digest);
    if not os.path.isfile(store) {
        return "";
    }
    with open(store, "r", encoding="utf-8") as f {
        text = f.read();
    }
    os.utime(store, None);
    return text;
}

impl ProjectHost.keep_native_scan_record(path: str, digest: str, text: str) {
    write_record(native_scan_path(path, digest), text);
    maybe_sweep("jir-nativescan");
}

impl ProjectHost.is_seed_source(rel_path: str) -> bool {
    return is_seed_source(rel_path);
}

impl ProjectHost.woven_module(
    path: str, program: (JacProgram | None)
) -> (Module | None) {
    source = self.read_source(path);
    (module, had_error) = parse_woven(source, path, program, annex_sources(path));
    if had_error {
        return None;
    }
    self.place_wired_imports(module);
    return module;
}

impl ProjectHost.place_wired_imports(module: Module) {
    place_wired_imports(module);
}

impl ProjectHost.path_facts(path: str) -> PathFacts {
    return path_facts_of(host_layout_tables(), path);
}

impl ProjectHost.read_source(path: str) -> str {
    real = os.path.realpath(path);
    held = self.overlay.get(real);
    if held is not None {
        return held;
    }
    text = read_file_with_encoding(path);
    digest = hashlib.sha256(Path(real).read_bytes()).hexdigest();
    self.source_reads[real] = digest
        if self.source_reads.get(real, digest) == digest
        else "";
    return text;
}

impl ProjectHost.annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
    return discover_annex_files(path, suffix);
}

impl ProjectHost.base_file(annex_path: str) -> (str | None) {
    return discover_base_file(annex_path);
}

impl ProjectHost.is_annex_path_of(candidate: str, base: str) -> bool {
    return is_annex_path_of(host_layout_tables(), candidate, base);
}

impl ProjectHost.package_init(directory: str) -> (str | None) {
    return package_init_of(host_layout_tables(), directory);
}

impl ProjectHost.host_platform -> HostPlatform {
    if self._platform is None {
        (major, minor, _patch) = platform.python_version_tuple();
        self._platform = HostPlatform(
            machine=platform.machine(), python_major=int(major), python_minor=int(minor)
        );
    }
    return self._platform;
}

impl ProjectHost.ct_environment -> CtEnvironment {
    triple = effective_native_target().lower();
    if triple {
        arch = "";
        if "aarch64" in triple or "arm64" in triple {
            arch = "aarch64";
        } elif "x86_64" in triple or "amd64" in triple {
            arch = "x86_64";
        }
        if arch {
            if "darwin" in triple or "apple" in triple or "macos" in triple {
                return CtEnvironment(
                    os="darwin", arch=("arm64" if arch == "aarch64" else arch)
                );
            }
            if "windows" in triple or "msvc" in triple or "mingw" in triple {
                return CtEnvironment(
                    os="windows", arch=("AMD64" if arch == "x86_64" else arch)
                );
            }
            if "linux" in triple {
                return CtEnvironment(os="linux", arch=arch);
            }
        }
    }
    system = platform.system().lower();
    host_os = "linux";
    if system.startswith("win") {
        host_os = "windows";
    } elif system == "darwin" {
        host_os = "darwin";
    }
    return CtEnvironment(os=host_os, arch=platform.machine());
}

impl ProjectHost.stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
    return self.compiler_for(program).stub_catalog();
}

impl UnitCollectBudget.due -> bool {
    def env_int(name: str, fallback: int) -> int {
        raw = os.environ.get(name, "").strip();
        if not raw {
            return fallback;
        }
        if not raw.lstrip("-").isdigit() {
            raise ValueError(f"{name} must be an integer, not {raw!r}");
        }
        return int(raw);
    }
    self.releases += 1;
    every = env_int("JAC_UNIT_COLLECT_EVERY", UNIT_COLLECT_EVERY);
    growth = env_int("JAC_UNIT_COLLECT_GROWTH_MB", UNIT_COLLECT_GROWTH_MB);
    peak = peak_rss_mb();
    if self.last_peak_mb == 0 {
        self.last_peak_mb = peak;
    }
    by_count = every > 0 and self.releases >= every;
    by_growth = growth > 0 and peak > 0 and (peak - self.last_peak_mb) >= growth;
    if not (by_count or by_growth) {
        return False;
    }
    self.releases = 0;
    self.last_peak_mb = peak;
    return True;
}

impl peak_rss_mb -> int {
    status = "/proc/self/status";
    if not os.path.isfile(status) {
        return 0;
    }
    with open(status, encoding="utf-8") as handle {
        for line in handle {
            if line.startswith("VmHWM:") {
                return int(line.split()[1]) // 1024;
            }
        }
    }
    return 0;
}

impl ProjectHost.compile_module(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> Module {
    session = self._session;
    if session is None {
        raise RuntimeError("the kernel host was used before its session was opened");
    }
    return compile_in_session(session, file_path, program, use_str, options);
}

impl ProjectHost.build_module(
    program: JacProgram, file_path: str, use_str: (str | None)
) -> Module {
    return self.compile_module(program, file_path, use_str, CompileOptions());
}

impl ProjectHost.run_module_pipeline(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> Module {
    session = self._session;
    if session is None {
        raise RuntimeError("the kernel host was used before its session was opened");
    }
    return session.run_module(file_path, program, use_str, options);
}

impl ProjectHost.native_session_active(program: JacProgram) -> bool {
    natives = program._natives;
    return natives is not None and natives.session is not None;
}

impl ProjectHost.internal_program(program: JacProgram) -> (JacProgram | None) {
    return None;
}

impl ProjectHost.bind_context_program(context_root: JacProgram, program: JacProgram) {
    program._compiler = self.compiler_for(context_root);
    root_iface = context_root._iface;
    if root_iface is not None and root_iface.verifying {
        self.iface_registry_for(program).verifying = True;
    }
}

impl ProjectHost.note_program_dependency(program: JacProgram, resolved_path: str) {
    self.iface_registry_for(program).note_dep(resolved_path);
}

impl ProjectHost.forget_program_products(program: JacProgram, resolved_path: str) {
    if program._natives is not None {
        program._natives.forget(resolved_path);
    }
    if program._iface is not None {
        program._iface.forget(resolved_path);
    }
    self.forget_unit(resolved_path);
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

impl ProjectHost.collect_released_memory {
    if self._collect_budget.due() {
        gc.collect();
    }
}

impl ProjectHost.load_modules(names: list[str]) {}

impl ProjectHost.module_in_flight(names: list[str]) -> str {
    return "";
}

impl ProjectHost.import_in_flight(path: str) -> bool {
    return False;
}

impl ProjectHost.has_active_stub_catalog -> bool {
    return active_stub_catalog() is not None;
}

impl ProjectHost.typeshed_unavailable_reason -> str {
    for stdlib_dir in get_typeshed_paths() {
        if not os.path.isdir(stdlib_dir) {
            return f"typeshed is not installed at {stdlib_dir}";
        }
    }
    return "";
}

impl ProjectHost.is_native_only_source(rel: str) -> bool {
    return is_native_only(rel);
}

impl ProjectHost.is_native_lowered_source(rel: str) -> bool {
    return is_native_lowered(rel);
}

impl ProjectHost.default_target_triple -> str {
    import from jaclang.compiler.backends.native.llvm.binding.targets { get_default_triple }
    return str(get_default_triple());
}

impl package_name_of(name: str) -> str {
    return name if is_scoped_package_name(name) else "";
}

impl other_compiler_root(path: str) -> str {
    if not path.endswith((".jac", ".py")) {
        return "";
    }
    folder = os.path.dirname(os.path.realpath(path));
    known = _OTHER_COMPILER_DIRS.get(folder);
    if known is not None {
        return known;
    }
    found = "";
    own = os.path.realpath(jaclang_pkg_root());
    current = folder;
    while True {
        if os.path.basename(current) == COMPILER_PACKAGE_NAME
            and os.path.isfile(os.path.join(current, OTHER_COMPILER_MARKER)) {
            if current != own {
                found = current;
            }
            break;
        }
        above = os.path.dirname(current);
        if above == current {
            break;
        }
        current = above;
    }
    _OTHER_COMPILER_DIRS[folder] = found;
    return found;
}

impl native_scan_path(path: str, digest: str) -> str {
    name = hashlib.sha256(
        (digest + "\x00" + module_env_fingerprint(path)).encode()
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "nativescan", name[:2], name + ".txt"
    );
}

impl write_record(path: str, text: str) {
    os.makedirs(os.path.dirname(path), exist_ok=True);
    scratch = f"{path}.{os.getpid()}.tmp";
    with open(scratch, "w", encoding="utf-8") as f {
        f.write(text);
    }
    os.replace(scratch, path);
}

impl wiring_records_path(digest: str) -> str {
    name = hashlib.sha256(
        (digest + "\x00" + running_compiler_digest()).encode()
    ).hexdigest();
    return os.path.join(
        str(get_jir_cache_dir()), "wiring-spec", name[:2], name + ".txt"
    );
}

impl check_settings_of(check: CheckConfig) -> CheckSettings {
    lint = check.lint;
    return CheckSettings(
        suppress=list(check.suppress),
        suppress_categories=list(check.suppress_categories),
        lint_active=True,
        lint_select=list(lint.select),
        lint_ignore=list(lint.ignore),
        enforce_access=check.enforce_access,
        untyped_external_error=check.untyped_external == "error",
        warn_native_seams=check.warn_native_seams
    );
}

impl project_defaults_of(cfg: JacConfig) -> ProjectDefaults {
    native = cfg.native;
    memory = cfg.memory;
    return ProjectDefaults(
        default_codespace=cfg.placement.default_codespace,
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
        client_framework=cfg.client.framework
    );
}
