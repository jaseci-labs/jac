impl no_passes(request: ProductRequest) -> PassSchedule {
    return [];
}

impl unavailable_schedule(request: ProductRequest) -> (PassSchedule | None) {
    return None;
}

impl empty_schedule(request: ProductRequest) -> (PassSchedule | None) {
    return [];
}

impl no_action(program: JacProgram, module: Module) -> bool {
    return True;
}

impl no_drop(program: JacProgram, module: Module) {}

impl no_precheck {}

impl front_passes -> PassSchedule {
    return [
        AppContextPass,
        GraphLoweringPass,
        ASTValidationPass,
        AbsorbImportsPass,
        SymTabBuildPass
    ];
}

impl symbols_passes(request: ProductRequest) -> PassSchedule {
    return front_passes() + [DeclImplMatchPass, PlacementApplyPass];
}

impl bootstrap_ir_passes(request: ProductRequest) -> (PassSchedule | None) {
    return front_passes() + [DeclImplMatchPass, SemanticAnalysisPass];
}

impl ir_passes(request: ProductRequest) -> PassSchedule {
    passes = front_passes()
        + [
            ImportWiringPass,
            PackageBoundaryPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass
        ];
    if request.gen_mtir {
        import from jaclang.compiler.passes.mtir_gen_pass { MTIRGenPass }
        passes.append(MTIRGenPass);
    }
    passes.append(JsxIntrinsicGuardPass);
    passes.append(PlacementApplyPass);
    import from jaclang.compiler.passes.comptime_resolve_pass { ComptimeResolvePass }
    passes.append(ComptimeResolvePass);
    return passes;
}

impl flow_passes(request: ProductRequest) -> PassSchedule {
    return [CFGBuildPass];
}

impl analysis_passes(request: ProductRequest) -> PassSchedule {
    return [
        RegionInferPass,
        VariantAgreementPass,
        TypeCheckPass,
        StaticAnalysisPass,
        AccessCheckPass,
        OwnershipCheckPass,
        PlacementPass,
        PortabilityWarnPass,
        JacLintCheckPass
    ];
}

impl boundary_passes(request: ProductRequest) -> PassSchedule {
    if not request.endpoint_effects {
        return [BoundaryFactsPass, BoundaryAnalysisPass];
    }
    return [BoundaryFactsPass, BoundaryAnalysisPass, EndpointEffectPass];
}

impl client_passes(request: ProductRequest) -> PassSchedule {
    return [EsastGenPass];
}

impl layout_passes(request: ProductRequest) -> PassSchedule {
    return [LayoutPass];
}

impl codegen_passes(request: ProductRequest) -> PassSchedule {
    passes: PassSchedule = [RcFactsPass, EsastGenPass];
    if request.native and not unavailable(CompilationProduct.NATIVE_LOWER) {
        import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
        passes.append(NaIRGenPass);
    }
    return passes;
}

impl py_ir_passes(request: ProductRequest) -> PassSchedule {
    return [NativeImportFactsPass, JcirGenPass];
}

impl frozen_passes(request: ProductRequest) -> PassSchedule {
    return [FreezeStructurePass];
}

impl bytecode_passes(request: ProductRequest) -> PassSchedule {
    return [JcirBytecodeGenPass];
}

impl native_ir_passes(request: ProductRequest) -> PassSchedule {
    return [NativeImportFactsPass, RcFactsPass, NaIRGenPass];
}

impl native_lower_passes(request: ProductRequest) -> PassSchedule {
    return [RcFactsPass, NaIRGenPass];
}

impl native_object_passes(request: ProductRequest) -> PassSchedule {
    return [NativeCompilePass];
}

impl format_passes(request: ProductRequest) -> PassSchedule {
    return [CommentAttachPass, DocIRGenPass, JacFormatPass];
}

impl format_lintfix_passes(request: ProductRequest) -> PassSchedule {
    return [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass];
}

impl lint_passes(request: ProductRequest) -> PassSchedule {
    return [JacLintCheckPass];
}

impl python_ast_passes(request: ProductRequest) -> PassSchedule {
    return [PyastBuildPass];
}

impl python_symbols_passes(request: ProductRequest) -> PassSchedule {
    return [SymTabBuildPass];
}

impl grammar_passes(request: ProductRequest) -> PassSchedule {
    return [GrammarExtractPass];
}

impl cfg_dot_passes(request: ProductRequest) -> PassSchedule {
    return [CoalesceBBPass];
}

impl normalize_passes(request: ProductRequest) -> PassSchedule {
    return [NormalizePass];
}

impl unparse_passes(request: ProductRequest) -> PassSchedule {
    return [UnparsePass];
}

impl doc_passes(request: ProductRequest) -> PassSchedule {
    return [DocIRGenPass];
}

impl format_text_passes(request: ProductRequest) -> PassSchedule {
    return [JacFormatPass];
}

impl place_module(program: JacProgram, module: Module) -> bool {
    refresh_placement_module(module, program);
    solve_program_placement(module, program);
    return True;
}

impl prepare_interface(program: JacProgram, module: Module) -> bool {
    return active_host().prepare_interface(
        program,
        os.path.realpath(module.loc.mod_path or module.source.file_path),
        module
    );
}

impl drop_client(program: JacProgram, module: Module) {
    module.gen.js = '';
    module.gen.es_ast = None;
    path = os.path.realpath(module.loc.mod_path);
    program.hub.client_artifacts.pop(path, None);
    active_host().drop_python_lane_products(path, program);
}

impl drop_native_ir(program: JacProgram, module: Module) {
    module.gen.drop_native_ir();
    module.gen.native_iface = None;
}

impl drop_native_object(program: JacProgram, module: Module) {
    module.gen.native_bitcode = None;
    module.gen.native_object = None;
}

impl require_typeshed_stubs -> None {
    if active_host().has_active_stub_catalog() {
        return;
    }
    why = active_host().typeshed_unavailable_reason();
    if why {
        raise TypeshedUnavailableError(
            "type inference is on the critical path of every compilation, but "
            f"this environment has neither a stub catalog nor typeshed: {why}"
        );
    }
}

impl contract_of(p: type[CompilerPass]) -> PassContract {
    contract = p.contract;
    if contract is None {
        raise RuntimeError(
            f"scheduling error: pass {p.__name__} declares no contract; every "
            "scheduled pass states the analysis facts it requires and provides"
        );
    }
    return contract;
}

impl validate_schedule(
    passes: PassSchedule,
    preprovided: (set[AnalysisFact] | None) = None,
    origin: str = 'schedule'
) -> PassSchedule {
    provided: set[AnalysisFact] = set(preprovided)
        if preprovided is not None
        else set();
    for p in passes {
        contract = contract_of(p);
        for tag in contract.requires {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.__name__} requires analysis "
                    f"'{tag}' which is neither provided by an earlier pass in "
                    f"the {origin} nor already available -- the schedule was "
                    f"constructed missing a declared dependency."
                );
            }
        }
        for tag in contract.provides {
            provided.add(tag);
        }
    }
    return passes;
}

impl providers_of(passes: PassSchedule) -> set[AnalysisFact] {
    out: set[AnalysisFact] = set();
    for p in passes {
        for tag in contract_of(p).provides {
            out.add(tag);
        }
    }
    return out;
}

impl schedule_loading -> bool {
    return bool(_LOADING.get());
}

impl tier_reason(product: CompilationProduct) -> str {
    spec = PRODUCTS[product];
    if product in _LOADING.get() {
        return f"the {product.value} schedule was still loading";
    }
    if spec.loads {
        dep = active_host().module_in_flight(list(spec.loads));
        if dep {
            return f"'{dep}', a dependency of the {product.value} schedule, was mid-import";
        }
    }
    for other in spec.tier_with {
        reason = tier_reason(other);
        if reason {
            return reason;
        }
    }
    return '';
}

impl resolve(
    product: CompilationProduct,
    request: (ProductRequest | None) = None,
    internal: bool = False,
    peer_fell_back: bool = False
) -> tuple[(PassSchedule | None), bool, bool] {
    spec = PRODUCTS[product];
    req = request if request is not None else ProductRequest();
    if spec.tiered and (peer_fell_back or tier_reason(product)) {
        return (spec.bootstrap(req), False, False);
    }
    spec.precheck();
    token = _LOADING.set(_LOADING.get() + [product]);
    schedule: PassSchedule = [];
    try {
        if spec.loads {
            active_host().load_modules(list(spec.loads));
        }
        schedule = spec.passes(req);
    } except ImportError as e {
        fallback = spec.on_import_error;
        if fallback == ImportFallback.RAISE
            or (fallback == ImportFallback.BOOTSTRAP_INTERNAL and not internal) {
            raise;
        }
        if fallback == ImportFallback.REPORT {
            active_host().schedule_import_failed(e);
        }
        return (spec.bootstrap(req), True, False);
    } finally {
        _LOADING.reset(token);
    }
    return (schedule, False, True);
}

impl schedule_for(
    product: CompilationProduct,
    request: (ProductRequest | None) = None,
    internal: bool = False
) -> (PassSchedule | None) {
    return resolve(product, request, internal)[0];
}

impl unavailable(product: CompilationProduct) -> str {
    spec = PRODUCTS[product];
    try {
        if spec.loads {
            active_host().load_modules(list(spec.loads));
        }
        spec.passes(ProductRequest());
    } except ImportError as e {
        active_host().schedule_import_failed(e);
        return f"{type(e).__name__}: {e}";
    }
    return '';
}

impl product_passes(
    product: CompilationProduct, request: (ProductRequest | None) = None
) -> PassSchedule {
    return PRODUCTS[product].passes(
        request if request is not None else ProductRequest()
    );
}

impl product_facts(product: CompilationProduct) -> set[AnalysisFact] {
    return providers_of(product_passes(product));
}

impl early_passes -> PassSchedule {
    return [
        p
        for p in product_passes(CompilationProduct.IR)
        if contract_of(p).kernel_safe
    ];
}

impl dependents(product: CompilationProduct) -> list[CompilationProduct] {
    out: list[CompilationProduct] = [];
    frontier: list[CompilationProduct] = [product];
    while frontier {
        current = frontier.pop();
        for (candidate, spec) in PRODUCTS.items() {
            if current in spec.needs and candidate not in out {
                out.append(candidate);
                frontier.append(candidate);
            }
        }
    }
    return out;
}

impl product_ready(
    program: JacProgram, module: Module, product: CompilationProduct
) -> bool {
    spec = PRODUCTS[product];
    build = program.analysis.peek(module);
    if not spec.acts {
        facts = program.analysis.product_facts.get(product);
        if facts is None {
            return False;
        }
        if facts and (build is None or not facts.issubset(build.facts)) {
            return False;
        }
    }
    for need in spec.needs {
        if not product_ready(program, module, need) {
            return False;
        }
    }
    task = build.tasks.get(product) if build is not None else None;
    return task is None or task.state == TaskState.SUCCEEDED;
}

impl cancelled(cancel_token: (CancelToken | None)) -> bool {
    return cancel_token is not None and cancel_token.is_set();
}

impl produce(
    program: JacProgram,
    module: Module,
    product: CompilationProduct,
    cancel_token: (CancelToken | None),
    request: (ProductRequest | None),
    task: (ProductTask | None) = None
) -> (bool | None) {
    spec = PRODUCTS[product];
    if spec.acts {
        return spec.action(program, module);
    }
    build = program.analysis.build(module);
    peer_fell_back = False;
    for peer in spec.tier_with {
        peer_task = build.tasks.get(peer);
        if peer_task is not None and peer_task.import_fallback {
            peer_fell_back = True;
        }
    }
    (schedule, fell_back, full) = resolve(
        product, request, program.internal, peer_fell_back
    );
    if task is not None {
        task.import_fallback = fell_back;
    }
    if schedule is None {
        return None;
    }
    if full {
        known = program.analysis.product_facts.get(product);
        facts = providers_of(schedule);
        if known is not None {
            facts.update(known);
        }
        program.analysis.product_facts[product] = facts;
    }
    execute_passes(program, module, schedule, cancel_token=cancel_token);
    return True;
}

impl require(
    program: JacProgram,
    module: Module,
    product: CompilationProduct,
    cancel_token: (CancelToken | None) = None,
    request: (ProductRequest | None) = None
) -> bool {
    spec = PRODUCTS[product];
    active_cancel = cancel_token
        if cancel_token is not None
        else program.options.cancel_token;
    build = program.analysis.build(module);
    task = build.tasks.get(product);
    if task is not None {
        if task.state == TaskState.RUNNING {
            if spec.cached {
                raise RuntimeError(
                    f"Compilation dependency cycle: {product.value} of {module.loc.mod_path}"
                );
            }
            return bool(produce(program, module, product, active_cancel, request));
        }
        if spec.cached {
            if task.state == TaskState.SUCCEEDED {
                if product_ready(program, module, product) {
                    return True;
                }
            } elif task.state == TaskState.FAILED or cancelled(active_cancel) {
                return False;
            }
        }
        task.state = TaskState.RUNNING;
    } else {
        task = ProductTask(product, TaskState.RUNNING);
        build.tasks[product] = task;
    }
    start = time.perf_counter();
    before = len(program.errors_had);
    try {
        for need in spec.needs {
            if product_ready(program, module, need) {
                continue;
            }
            if not require(program, module, need, cancel_token=active_cancel) {
                task.state = TaskState.CANCELLED
                    if cancelled(active_cancel)
                    else TaskState.FAILED;
                return False;
            }
        }
        produced = produce(program, module, product, active_cancel, request, task);
        if produced is None {
            task.state = TaskState.PENDING;
            return False;
        }
        if cancelled(active_cancel) {
            task.state = TaskState.CANCELLED;
        } elif not produced or len(program.errors_had) != before {
            task.state = TaskState.FAILED;
        } else {
            task.state = TaskState.SUCCEEDED;
        }
        return task.state == TaskState.SUCCEEDED;
    } except Exception {
        task.state = TaskState.FAILED;
        raise;
    } finally {
        task.elapsed = time.perf_counter() - start;
    }
}

impl invalidate(program: JacProgram, module: Module, product: CompilationProduct) {
    build = program.analysis.peek(module);
    for current in [product] + dependents(product) {
        spec = PRODUCTS[current];
        if build is not None {
            build.tasks.pop(current, None);
            if not spec.acts {
                for step in product_passes(current) {
                    if not contract_of(step).provides {
                        build.done.discard(step.__name__);
                    }
                }
            }
        }
        spec.drop(program, module);
    }
}

impl execute_passes(
    program: JacProgram,
    module: Module,
    passes: PassSchedule,
    cancel_token: (CancelToken | None) = None
) -> Module {
    build = program.analysis.build(module);
    validate_schedule(
        passes,
        preprovided=build.facts,
        origin=f"schedule for module {module.loc.mod_path}"
    );
    policy = build_diagnostic_policy(program);
    for step in passes {
        if step.__name__ in build.done {
            continue;
        }
        if cancelled(cancel_token) {
            return module;
        }
        module = run_pass(
            step, module, program, cancel_token=cancel_token, policy=policy
        ).module;
        build.facts.update(contract_of(step).provides);
        if cancelled(cancel_token) {
            return module;
        }
        build.done.add(step.__name__);
    }
    return module;
}

impl run_utility(
    product: CompilationProduct,
    ir: any,
    program: JacProgram,
    cancel_token: (CancelToken | None) = None
) -> any {
    if not PRODUCTS[product].tool {
        raise ValueError(f"{product.value} is not a utility product");
    }
    step = product_passes(product)[0];
    contract_of(step);
    return run_pass(step, ir, program, cancel_token=cancel_token);
}
