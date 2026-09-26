import os;
import sys;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host {
    HostServices,
    active_host,
    install_host,
    kernel_host_mode
}
import from jaclang.compiler.frontend.kernel_inputs {
    KernelInputs,
    ManifestSets,
    PythonInterface,
    request_of
}
import from jaclang.compiler.frontend.kernel_host { HostCensus, KernelHost }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_CRASHED,
    ANALYSIS_OK,
    AnalysisReport,
    analysis_report,
    run_kernel_analysis
}
import from jaclang.compiler.driver.module_analysis { ModuleAnalysis, analyze_module }
import from jaclang.compiler.driver.session_compile {
    CompileFrame,
    SessionContext,
    SessionHooks,
    compile_in_session
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { is_compiler_source_path }

glob SCAN_LIMIT: int = 4000,
     THIRD_PARTY_DIRS: tuple[str, ...] = ("/site-packages/", "/dist-packages/"),
     _TOTALS: list[HostCensus] = [],
     _EXIT_REPORT: list[bool] = [];

obj ClosureScan {
    has learner: KernelHost,
        program: JacProgram,
        options: CompileOptions,
        entry_path: str,
        entry_source: (str | None) = None,
        scratch: (JacProgram | None) = None,
        scope: list[str] = [],
        seen: set[str] = set(),
        learned: set[str] = set(),
        queue: list[str] = [];

    def run {
        owner = self.learner.project_root(self.entry_path);
        top = owner or os.path.dirname(os.path.abspath(self.entry_path));
        self.scope.append(os.path.join(os.path.realpath(top), ""));
        self.queue.append(self.entry_path);
        while self.queue and len(self.seen) < SCAN_LIMIT {
            path = self.queue.pop();
            if path in self.seen {
                continue;
            }
            self.seen.add(path);
            self.scan_module(path);
        }
    }

    def scan_module(path: str) {
        self.learn_path(path);
        if path.endswith(".jac") {
            self.scan_jac(path);
        } elif path.endswith(".py") {
            self.scan_python(path);
        }
    }

    def scan_jac(path: str) {
        import from jaclang.compiler.frontend.parser.frontend { parse }
        learner = self.learner;
        sources = [path];
        sources.extend(learner.annex_files(path, ".impl.jac"));
        sources.extend(learner.annex_files(path, ".test.jac"));
        arch = learner.wiring_file(path);
        if arch {
            sources.append(arch);
        }
        for source_path in sources {
            self.learn_path(source_path);
            try {
                text = self.source_of(source_path);
                (tree, _) = parse(text, source_path);
            } except Exception {
                continue;
            }
            self.scan_imports(tree);
        }
        try {
            import from jaclang.compiler.driver.wiring { wiring_for_path }
            wiring_for_path(path);
        } except Exception {}
    }

    def scan_python(path: str) {
        if any(marker in path.replace("\\", "/") for marker in THIRD_PARTY_DIRS) {
            return;
        }
        if self.scratch is None {
            self.scratch = JacProgram();
        }
        try {
            (tree, _) = self.learner.parse_python(
                self.source_of(path), path, self.scratch
            );
        } except Exception {
            return;
        }
        self.scan_imports(tree);
    }

    def source_of(path: str) -> str {
        if path == self.entry_path and self.entry_source is not None {
            return self.entry_source;
        }
        return self.learner.read_source(path);
    }

    def scan_imports(tree: uni.Module) {
        learner = self.learner;
        for mod_path in tree.get_all_sub_nodes(uni.ModulePath) {
            owner = mod_path.loc.mod_path if mod_path.loc else "";
            if not owner {
                continue;
            }
            spec = mod_path.string_path_value;
            if spec is not None {
                learner.is_path_alias(spec, owner);
            } else {
                spec = mod_path.dot_path_str;
            }
            self.follow(self.resolved(mod_path, None));
            self.learn_npm(spec, owner);
            if spec.startswith("@jac/") {
                learner.jac_virtual_module_path(spec);
            }
            if spec.startswith("jaclang.") {
                learner.resolve_module(spec, os.path.join(os.path.dirname(owner), ""));
            }
        }
        for item in tree.get_all_sub_nodes(uni.ModuleItem) {
            if item.parent is None or not isinstance(item.parent, uni.Import) {
                continue;
            }
            if item.from_parent.from_loc is None {
                continue;
            }
            self.follow(self.resolved(None, item));
        }
    }

    def resolved(
        mod_path: (uni.ModulePath | None), item: (uni.ModuleItem | None)
    ) -> str {
        try {
            if mod_path is not None {
                return mod_path.resolve_relative_path();
            }
            if item is not None {
                return item.resolve_relative_path();
            }
        } except Exception {}
        return "";
    }

    def learn_npm(spec: str, owner: str) {
        if not spec {
            return;
        }
        learner = self.learner;
        for base in (owner, self.entry_path) {
            if learner.has_npm_package(spec, base) {
                learner.resolve_npm_package(spec, base);
                learner.npm_declarations(spec, base);
            }
        }
    }

    def follow(path: str) {
        if not path or not os.path.isfile(path) {
            return;
        }
        self.learn_path(path);
        if not self.in_scope(path) {
            return;
        }
        if path.endswith(".jac") or path.endswith(".py") {
            if path not in self.seen {
                self.queue.append(path);
            }
        }
    }

    def in_scope(path: str) -> bool {
        if is_compiler_source_path(path) {
            return False;
        }
        real = os.path.realpath(path);
        return any(real.startswith(top) for top in self.scope);
    }

    def learn_path(path: str) {
        if not path or path in self.learned {
            return;
        }
        self.learned.add(path);
        learner = self.learner;
        owner_root = learner.project_root(path);
        learner.project_facts(path);
        if owner_root {
            learner.project_facts(owner_root);
            learner.project_root(owner_root);
        }
        learner.workspace(path);
        learner.app_for_path(path);
        learner.lint_settings(path);
        learner.native_verdict(path, self.program);
        learner.is_untyped_third_party(path);
        learner.declared_dependencies(path, self.options.target_app or "");
        if path.endswith(".js") {
            learner.sibling_declaration(path);
        }
        real = os.path.realpath(path);
        if real != path {
            self.learn_path(real);
        }
    }
}

def manifest_sets -> ManifestSets {
    import from jaclang.bootstrap_manifest {
        NATIVE_LOWERED_PATHS,
        NATIVE_ONLY_DIR_REL,
        NATIVE_ONLY_REL,
        SEED_PATHS
    }
    return ManifestSets(
        seed_paths=list(SEED_PATHS),
        native_only_files=list(NATIVE_ONLY_REL),
        native_only_dirs=list(NATIVE_ONLY_DIR_REL),
        native_lowered=list(NATIVE_LOWERED_PATHS)
    );
}

def python_interface(path: str, options: CompileOptions) -> (PythonInterface | None) {
    import from jaclang.compiler.types.stubcat.writer {
        IncoherentInterface,
        build_module_iface
    }
    resolved = os.path.realpath(path);
    scratch = JacProgram();
    try {
        mod = scratch.compile(resolved, options=options.for_symbols());
        pkg_dir = os.path.dirname(resolved);
        data = build_module_iface(mod, scratch.get_type_evaluator(), pkg_dir);
    } except IncoherentInterface {
        return None;
    }
    return PythonInterface(path=resolved, pkg_dir=pkg_dir, data=data);
}

def python_interfaces(
    paths: list[str], options: CompileOptions
) -> list[PythonInterface] {
    out: list[PythonInterface] = [];
    for path in sorted(paths) {
        if not path.endswith(".py")
            or any(marker in path.replace("\\", "/") for marker in THIRD_PARTY_DIRS) {
            continue;
        }
        iface = python_interface(path, options);
        if iface is not None {
            out.append(iface);
        }
    }
    return out;
}

def snapshot_inputs(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> KernelInputs {
    import from jaclang.compiler.driver.bccache { host_layout_tables }
    import from jaclang.project.modresolver { get_jac_search_paths, get_typeshed_paths }
    import from jaclang.compiler.types.stubcat.locate { catalog_origin }
    catalog_dir = "";
    catalog_active = host.has_active_stub_catalog();
    if catalog_active {
        import from jaclang.jac0core.stubcat_hook { active }
        catalog: any = active();
        catalog_dir = str(catalog.pkg_dir) if catalog is not None else "";
    }
    origin = catalog_origin() if catalog_active else None;
    natives = program._natives;
    import from jaclang.compiler.frontend.host { package_root }
    inputs = KernelInputs(
        entry_path=path,
        package_root=package_root(),
        module_projection=options.module_projection(),
        target_app=options.target_app or "",
        request=request_of(options),
        project_defaults=host.project_defaults(),
        host_platform=host.host_platform(),
        ct_environment=host.ct_environment(),
        stub_catalog_active=catalog_active,
        stub_catalog_dir=catalog_dir,
        stub_catalog_file=origin.path if origin is not None else "",
        stub_catalog_offset=origin.offset if origin is not None else 0,
        stub_catalog_length=origin.length if origin is not None else 0,
        typeshed_roots=get_typeshed_paths(),
        search_paths=get_jac_search_paths(os.path.dirname(os.path.abspath(path))),
        native_session_active=natives is not None and natives.session is not None,
        manifest=manifest_sets(),
        layout=host_layout_tables()
    );
    for app in {"", options.target_app or ""} {
        inputs.check_settings[app] = host.check_settings(app);
    }
    inputs.lint_of[""] = host.lint_settings("");
    (inputs.native_pipeline, inputs.native_pipeline_reason) = host.native_pipeline_available();
    inputs.native_pipeline_known = True;
    inputs.target_triple = host.default_target_triple();
    inputs.target_triple_known = True;
    learner = KernelHost(inputs=inputs, fallback=host);
    previous = active_host();
    install_host(learner);
    scan = ClosureScan(
        learner=learner,
        program=program,
        options=options,
        entry_path=path,
        entry_source=source
    );
    try {
        scan.run();
    } finally {
        install_host(previous);
    }
    inputs.scanned_modules = len(scan.seen);
    return inputs;
}

def kernel_analysis_inputs(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> KernelInputs {
    inputs = snapshot_inputs(host, program, path, options, source);
    for ws in list(inputs.workspaces.values()) {
        for name in ws.apps {
            if name not in inputs.check_settings {
                inputs.check_settings[name] = host.check_settings(name);
            }
        }
    }
    local = [
        p
        for (p, untyped) in inputs.untyped.items()
        if not untyped
    ];
    inputs.python_ifaces = python_interfaces(local, options);
    return inputs;
}

class KernelAnalysisError(RuntimeError) {}

obj HostReferenceSession(SessionHooks) {
    has compiler: any,
        entry_path: str,
        task: (ModuleAnalysis | None) = None;

    def enter_compile(ctx: SessionContext) -> CompileFrame {
        return self.compiler.enter_compile(ctx);
    }

    def leave_compile(ctx: SessionContext, frame: CompileFrame) {
        self.compiler.leave_compile(ctx, frame);
    }

    def finish_compile(frame: CompileFrame) {
        self.compiler.finish_compile(frame);
    }

    def check_crash(crash: Exception, file_path: str) {
        self.compiler.check_crash(crash, file_path);
    }

    def closure_options -> (CompileOptions | None) {
        return self.compiler.closure_options();
    }

    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        if self.task is None and os.path.realpath(file_path) == self.entry_path {
            task = analyze_module(target_program, file_path, options, use_str);
            self.task = task;
            return task.module;
        }
        return self.compiler.run_module(file_path, target_program, use_str, options);
    }
}

def host_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> AnalysisReport {
    session = HostReferenceSession(
        compiler=host.compiler_for(program), entry_path=os.path.realpath(path)
    );
    status = ANALYSIS_OK;
    message = "";
    try {
        compile_in_session(session, path, program, source, options);
    } except Exception as err {
        status = ANALYSIS_CRASHED;
        message = f"{type(err).__name__}: {err}";
    }
    tasks = [session.task] if session.task is not None else [];
    return analysis_report(program, path, tasks, status, message);
}

def kernel_analysis_json(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> str {
    compiler: any = host.compiler_for(program);
    compiler.ensure_stub_catalog();
    return kernel_analysis_inputs(host, program, path, options, source).to_json();
}

def call_kernel_analyze(
    kernel: any, inputs_json: str, path: str, source: (str | None)
) -> str {
    import from ctypes { c_int64, c_void_p }
    lib = kernel.lib;
    analyze = lib.jc_analyze;
    analyze.argtypes = [c_void_p, c_void_p, c_int64] * 3 + [c_int64];
    analyze.restype = c_int64;
    take = lib.jc_take_analysis;
    take.argtypes = [];
    take.restype = c_void_p;
    handles: list[int] = [];
    args: list[object] = [];
    try {
        for text in (inputs_json, path, source or "") {
            data = text.encode();
            handle = lib.jac_str_new(data, len(data));
            handles.append(handle);
            args.extend([c_void_p(handle), c_void_p(handle), c_int64(len(data))]);
        }
        args.append(c_int64(1 if source is not None else 0));
        analyze(*args);
    } finally {
        for handle in handles {
            lib.jac_release(handle);
        }
    }
    return kernel._take(take()) or "";
}

def kernel_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False
) -> AnalysisReport {
    inputs_json = kernel_analysis_json(host, program, path, options, source);
    if in_process {
        outcome = run_kernel_analysis(inputs_json, path, source);
    } else {
        import from jaclang.compiler.native_compiler { ensure_loaded }
        kernel = ensure_loaded();
        if kernel is None {
            raise KernelAnalysisError("no native compiler kernel is available");
        }
        outcome = AnalysisReport.from_json(
            call_kernel_analyze(kernel, inputs_json, path, source)
        );
    }
    if outcome.status == ANALYSIS_CRASHED {
        raise KernelAnalysisError(outcome.message);
    }
    return outcome;
}

def kernel_census -> HostCensus {
    if not _TOTALS {
        _TOTALS.append(HostCensus());
    }
    return _TOTALS[0];
}

def reset_kernel_census {
    _TOTALS.clear();
}

def record_kernel_session(census: HostCensus, path: str) {
    census.sessions += 1;
    census.entry_path = path;
    kernel_census().merge(census);
    if kernel_host_mode() != "census" {
        return;
    }
    if not _EXIT_REPORT {
        import atexit;
        _EXIT_REPORT.append(True);
        atexit.register(report_kernel_census);
    }
    if census.total_misses() {
        report_stream().write(f"[{path}] {census.summary()}\n");
    }
}

def report_kernel_census {
    report_stream().write(kernel_census().summary() + "\n");
}

def report_stream -> any {
    return sys.__stderr__ or sys.stderr;
}
