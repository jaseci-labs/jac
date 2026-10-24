impl ModuleAnalysis.postinit {
    self.module = Module.make_stub();
}

impl ModuleAnalysis.parse {
    existing = self.program.mod.hub.get(os.path.realpath(self.path));
    built = self.program.analysis.peek(existing) if existing is not None else None;
    if self.source is None
        and not self.program.internal
        and existing is not None
        and not existing.stub_only
        and not existing.parse_failed
        and self.program.is_hub_entry_fresh(os.path.realpath(self.path))
        and built is not None
        and built.done {
        self.module = existing;
        return;
    }
    keep_str = self.source
        if self.source is not None
        else active_host().read_source(self.path);
    errors_before = len(self.program.errors_had);
    self.module = self.program.parse_source(
        keep_str, self.path, cancel_token=self.options.cancel_token
    );
    self.parse_failed = len(self.program.errors_had) > errors_before;
    self.program.ingest_comptime_producers(self.module, self.path);
}

impl ModuleAnalysis.require(
    product: CompilationProduct, request: (ProductRequest | None) = None
) -> bool {
    return require(
        self.program,
        self.module,
        product,
        cancel_token=self.options.cancel_token,
        request=request
    );
}

impl ModuleAnalysis.ready(product: CompilationProduct) -> bool {
    return product_ready(self.program, self.module, product);
}

impl ModuleAnalysis.has_full_ir -> bool {
    return not self.options.symtab_ir_only
        and self.program.analysis.provides(self.module, AnalysisFact.CFG_SUCC);
}

impl cancelled(options: CompileOptions) -> bool {
    return options.cancel_token is not None and options.cancel_token.is_set();
}

impl always(task: ModuleAnalysis) -> bool {
    return True;
}

impl run_parse(task: ModuleAnalysis) {
    task.parse();
}

impl run_head(task: ModuleAnalysis) {
    task.module_path = os.path.normpath(task.path);
    before = task.program.count_module_blocking_errors(task.module_path);
    if task.options.symtab_ir_only {
        task.require(CompilationProduct.SYMBOLS);
    } else {
        task.require(
            CompilationProduct.IR, ProductRequest(gen_mtir=not task.options.no_cgen)
        );
    }
    task.blocked = task.program.count_module_blocking_errors(task.module_path) > before;
}

impl admits_placement(task: ModuleAnalysis) -> bool {
    return not task.options.symtab_ir_only and not task.blocked;
}

impl run_placement(task: ModuleAnalysis) {
    task.require(CompilationProduct.PLACEMENT);
}

impl run_analysis(task: ModuleAnalysis) {
    program = task.program;
    module = task.module;
    task.native = module is not None
        and module.declares_codespace(_CodeCtx.NATIVE, path_hint=task.path);
    candidate = task.native
        or (
            module is not None
            and not task.parse_failed
            and not module.gen.placement_mode
            and module.gen.native_undecided
            and program.infers_native_codespace(task.path)
        );
    if candidate {
        task.options.native_tree_demand = True;
    }
    _is_decl_stub = str(task.path).endswith('.pyi')
        or str(task.path).endswith('.py')
        or (module is not None and module.stub_only)
        or (module is not None and module.is_raised_from_py);
    host = active_host();
    _annex_of_base = host.path_facts(task.path).is_annex
        and host.base_file(str(task.path)) is not None;
    _unasked = task.options.skip_analysis
        or (program.internal and host.import_in_flight(task.path));
    _analyze = task.has_full_ir()
        and not _is_decl_stub
        and not _annex_of_base
        and (candidate or not _unasked);
    task.placement_only = _analyze and _unasked and not task.native;
    errors_mark = len(program.errors_had);
    blocked_before = task.blocked;
    if _analyze
        and not task.ready(CompilationProduct.ANALYSIS)
        and not task.require(CompilationProduct.ANALYSIS) {
        task.blocked = True;
    }
    if task.placement_only
        and not blocked_before
        and len(program.errors_had) > errors_mark
        and not cancelled(task.options) {
        import from jaclang.compiler.placement.placement_facts { settle_server }
        del program.errors_had[errors_mark:];
        settle_server(module);
        import from jaclang.compiler.placement.placement { record_decided }
        record_decided(program, module);
        task.blocked = False;
    }
    if not task.blocked and program.count_module_errors(task.module_path) > 0 {
        task.blocked = True;
    }
    if _analyze and not task.blocked {
        import from jaclang.compiler.placement.placement_solver { placement_work }
        placement_work(program).drain(program);
    }
    task.native = module is not None
        and module.declares_codespace(_CodeCtx.NATIVE, path_hint=task.path);
}

impl admits_boundaries(task: ModuleAnalysis) -> bool {
    return not task.parse_failed
        and not task.blocked
        and not task.options.symtab_ir_only;
}

impl run_boundaries(task: ModuleAnalysis) {
    options = task.options;
    native = options.aot_mode and options.default_codespace == "native";
    task.require(
        CompilationProduct.BOUNDARIES, ProductRequest(endpoint_effects=not native)
    );
}

impl run_plan(task: ModuleAnalysis, steps: tuple[PlanStep, ...]) {
    times = task.program.analysis.phase_time;
    for step in steps {
        if cancelled(task.options) {
            break;
        }
        started = time.perf_counter();
        try {
            if step.admit(task) {
                step.run(task);
            }
        } finally {
            times[step.name] = times.get(step.name, 0.0) + time.perf_counter()
                - started;
        }
    }
}

impl analyze_module(
    program: JacProgram, path: str, options: CompileOptions, source: str | None = None
) -> ModuleAnalysis {
    program.analysis.capability_notes.pop(os.path.realpath(path), None);
    task = ModuleAnalysis(program, path, options, source);
    run_plan(task, ANALYSIS_PLAN);
    return task;
}
