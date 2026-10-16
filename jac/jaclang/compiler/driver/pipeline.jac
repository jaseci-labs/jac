import from jaclang.compiler.passes.context { CompilerPass, PassSchedule }
import os;
import time;
import type from jaclang.compiler.driver.compile_options { CancelToken }
import from contextvars { ContextVar }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.context_passes {
    AppContextPass,
    AbsorbImportsPass,
    BoundaryFactsPass,
    NativeImportFactsPass
}
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.import_wiring_pass { ImportWiringPass }
import from jaclang.compiler.passes.package_boundary_pass { PackageBoundaryPass }
import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    CompilationProduct,
    ImportFallback,
    PassContract,
    ProductRequest,
    ProductTask,
    TaskState
}

class TypeshedUnavailableError(RuntimeError) {}

def no_passes(request: ProductRequest) -> PassSchedule {
    return [];
}

def unavailable_schedule(request: ProductRequest) -> (PassSchedule | None) {
    return None;
}

def empty_schedule(request: ProductRequest) -> (PassSchedule | None) {
    return [];
}

def no_action(program: JacProgram, module: Module) -> bool {
    return True;
}

def no_drop(program: JacProgram, module: Module) {}

def no_precheck {}

obj ProductSpec {
    has needs: list[CompilationProduct] = [],
        passes: Callable[[ProductRequest], PassSchedule] = no_passes,
        bootstrap:
            Callable[[ProductRequest], (PassSchedule | None)] = unavailable_schedule,
        action: Callable[[JacProgram, Module], bool] = no_action,
        drop: Callable[[JacProgram, Module], None] = no_drop,
        precheck: Callable[[], None] = no_precheck,
        loads: list[str] = [],
        tier_with: list[CompilationProduct] = [],
        tiered: bool = False,
        acts: bool = False,
        cached: bool = False,
        tool: bool = False,
        on_import_error: ImportFallback = ImportFallback.RAISE;
}

def front_passes -> PassSchedule {
    return [
        AppContextPass,
        GraphLoweringPass,
        ASTValidationPass,
        AbsorbImportsPass,
        SymTabBuildPass
    ];
}

def symbols_passes(request: ProductRequest) -> PassSchedule {
    return front_passes() + [DeclImplMatchPass, PlacementApplyPass];
}

def bootstrap_ir_passes(request: ProductRequest) -> (PassSchedule | None) {
    return front_passes() + [DeclImplMatchPass, SemanticAnalysisPass];
}

def ir_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
    import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
    import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
        JsxIntrinsicGuardPass
    }
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

def flow_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
    return [CFGBuildPass];
}

def analysis_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
    import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
    import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
    import from jaclang.compiler.passes.variant_agreement_pass { VariantAgreementPass }
    import from jaclang.compiler.passes.capability_check_pass { PortabilityWarnPass }
    import from jaclang.compiler.passes.placement_pass { PlacementPass }
    import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
    import from jaclang.compiler.passes.region_infer_pass { RegionInferPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
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

def boundary_passes(request: ProductRequest) -> PassSchedule {
    return [BoundaryFactsPass, BoundaryAnalysisPass, EndpointEffectPass];
}

def client_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    return [EsastGenPass];
}

def layout_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.layout_pass { LayoutPass }
    return [LayoutPass];
}

def codegen_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
    passes: PassSchedule = [RcFactsPass, EsastGenPass];
    if request.native and not unavailable(CompilationProduct.NATIVE_LOWER) {
        import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
        passes.append(NaIRGenPass);
    }
    return passes;
}

def py_ir_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
    return [NativeImportFactsPass, JcirGenPass];
}

def frozen_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.freeze_structure_pass { FreezeStructurePass }
    return [FreezeStructurePass];
}

def bytecode_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
    return [JcirBytecodeGenPass];
}

def native_ir_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    return [NativeImportFactsPass, RcFactsPass, NaIRGenPass];
}

def native_lower_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    return [RcFactsPass, NaIRGenPass];
}

def native_object_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.backends.native.na_compile_pass { NativeCompilePass }
    return [NativeCompilePass];
}

def graphmend_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.graphmend.graph_break_detect_pass {
        GraphBreakDetectPass
    }
    import from jaclang.compiler.passes.graphmend.trap_lowering_pass {
        TrapLoweringPass
    }
    import from jaclang.compiler.passes.graphmend.predicate_ctrl_flow_pass {
        PredicateCtrlFlowPass
    }
    import from jaclang.compiler.passes.graphmend.defer_side_effect_pass {
        DeferSideEffectPass
    }
    return [
        GraphBreakDetectPass,
        TrapLoweringPass,
        PredicateCtrlFlowPass,
        DeferSideEffectPass
    ];
}

def format_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    return [CommentAttachPass, DocIRGenPass, JacFormatPass];
}

def format_lintfix_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    return [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass];
}

def lint_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return [JacLintCheckPass];
}

def python_ast_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
    return [PyastBuildPass];
}

def python_symbols_passes(request: ProductRequest) -> PassSchedule {
    return [SymTabBuildPass];
}

def grammar_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
    return [GrammarExtractPass];
}

def cfg_dot_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.cfg_dot { CoalesceBBPass }
    return [CoalesceBBPass];
}

def normalize_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.normalize_pass { NormalizePass }
    return [NormalizePass];
}

def unparse_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.unparse_pass { UnparsePass }
    return [UnparsePass];
}

def doc_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    return [DocIRGenPass];
}

def format_text_passes(request: ProductRequest) -> PassSchedule {
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    return [JacFormatPass];
}

def place_module(program: JacProgram, module: Module) -> bool {
    import from jaclang.compiler.placement.placement_solver {
        solve_program_placement,
        refresh_placement_module
    }
    refresh_placement_module(module, program);
    solve_program_placement(module, program);
    return True;
}

def prepare_interface(program: JacProgram, module: Module) -> bool {
    return active_host().prepare_interface(
        program,
        os.path.realpath(module.loc.mod_path or module.source.file_path),
        module
    );
}

def drop_client(program: JacProgram, module: Module) {
    module.gen.js = '';
    module.gen.es_ast = None;
    path = os.path.realpath(module.loc.mod_path);
    program.hub.client_artifacts.pop(path, None);
    active_host().drop_python_lane_products(path, program);
}

def drop_native_ir(program: JacProgram, module: Module) {
    module.gen.drop_native_ir();
    module.gen.native_iface = None;
}

def drop_native_object(program: JacProgram, module: Module) {
    module.gen.native_bitcode = None;
    module.gen.native_object = None;
}

def require_typeshed_stubs -> None {
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

glob IR_LOADS: list[str] = [
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.intrinsic_registry',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.types.stubcat.modiface',
         'jaclang.compiler.types.stubcat.writer',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.layout_pass',
         'jaclang.compiler.passes.cfg_build_pass',
         'jaclang.compiler.passes.sem_def_match_pass',
         'jaclang.compiler.passes.jsx_intrinsic_guard_pass',
         'jaclang.compiler.passes.mtir_gen_pass',
         'jaclang.compiler.passes.comptime_resolve_pass',
         'jaclang.project.mobui_scope'
     ],
     ANALYSIS_LOADS: list[str] = [
         'jaclang.compiler.field_semantics',
         'jaclang.compiler.passes.type_checker_pass',
         'jaclang.compiler.types.type_evaluator',
         'jaclang.compiler.passes.pyast_load_pass',
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.types.type_utils',
         'jaclang.compiler.types.ts_decl_parser',
         'jaclang.compiler.symbol_utils',
         'jaclang.compiler.expr_keys',
         'jaclang.compiler.type_registry',
         'jaclang.compiler.driver.bccache',
         'jaclang.compiler.frontend.codeinfo',
         'jaclang.compiler.frontend.diagnostic_utils',
         'jaclang.project.modresolver',
         'jaclang.project.tomlio',
         'jaclang.project.mobui_scope',
         'jaclang.project.config',
         'jaclang.compiler.passes.static_analysis_pass',
         'jaclang.compiler.passes.access_check_pass',
         'jaclang.compiler.passes.variant_agreement_pass',
         'jaclang.compiler.passes.capability_check_pass',
         'jaclang.compiler.capability_notes',
         'jaclang.compiler.boundary_rules',
         'jaclang.compiler.native_bindings',
         'jaclang.compiler.passes.placement_pass',
         'jaclang.compiler.passes.ownership_check_pass',
         'jaclang.compiler.passes.region_infer_pass',
         'jaclang.compiler.tools.jac_auto_lint_pass'
     ],
     CODEGEN_LOADS: list[str] = [
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.passes.freeze_structure_pass'
     ],
     NATIVE_LOADS: list[str] = ['jaclang.compiler.backends.native.na_ir_gen_pass', ],
     GRAPHMEND_LOADS: list[str] = [
         'jaclang.compiler.passes.graphmend.graph_break_detect_pass',
         'jaclang.compiler.passes.graphmend.trap_lowering_pass',
         'jaclang.compiler.passes.graphmend.predicate_ctrl_flow_pass',
         'jaclang.compiler.passes.graphmend.defer_side_effect_pass'
     ];

glob PRODUCTS: dict[CompilationProduct, ProductSpec] = {
         CompilationProduct.SYMBOLS: ProductSpec(
             passes=symbols_passes,
             bootstrap=symbols_passes,
             loads=['jaclang.compiler.symbol_utils'],
             tier_with=[CompilationProduct.IR],
             tiered=True,
             on_import_error=ImportFallback.BOOTSTRAP
         ),
         CompilationProduct.IR: ProductSpec(
             passes=ir_passes,
             bootstrap=bootstrap_ir_passes,
             loads=IR_LOADS,
             tiered=True,
             on_import_error=ImportFallback.BOOTSTRAP_INTERNAL
         ),
         CompilationProduct.FLOW: ProductSpec(passes=flow_passes, cached=True),
         CompilationProduct.PLACEMENT: ProductSpec(action=place_module, acts=True),
         CompilationProduct.ANALYSIS: ProductSpec(
             needs=[CompilationProduct.FLOW],
             passes=analysis_passes,
             precheck=require_typeshed_stubs,
             loads=ANALYSIS_LOADS,
             tiered=True,
             cached=True
         ),
         CompilationProduct.BOUNDARIES: ProductSpec(passes=boundary_passes),
         CompilationProduct.INTERFACE: ProductSpec(
             action=prepare_interface, acts=True, cached=True
         ),
         CompilationProduct.CLIENT: ProductSpec(
             needs=[CompilationProduct.ANALYSIS],
             passes=client_passes,
             drop=drop_client,
             cached=True
         ),
         CompilationProduct.LAYOUT: ProductSpec(passes=layout_passes, cached=True),
         CompilationProduct.CODEGEN: ProductSpec(
             passes=codegen_passes,
             bootstrap=empty_schedule,
             loads=CODEGEN_LOADS,
             tier_with=[CompilationProduct.IR, CompilationProduct.NATIVE_LOWER],
             tiered=True,
             on_import_error=ImportFallback.REPORT
         ),
         CompilationProduct.PY_IR: ProductSpec(passes=py_ir_passes),
         CompilationProduct.FROZEN: ProductSpec(
             passes=frozen_passes,
             bootstrap=empty_schedule,
             tier_with=[CompilationProduct.CODEGEN],
             tiered=True,
             on_import_error=ImportFallback.REPORT
         ),
         CompilationProduct.BYTECODE: ProductSpec(
             needs=[CompilationProduct.PY_IR], passes=bytecode_passes
         ),
         CompilationProduct.NATIVE_IR: ProductSpec(
             needs=[CompilationProduct.FLOW, CompilationProduct.ANALYSIS],
             passes=native_ir_passes,
             loads=NATIVE_LOADS,
             cached=True
         ),
         CompilationProduct.NATIVE_LOWER: ProductSpec(
             needs=[CompilationProduct.ANALYSIS],
             passes=native_lower_passes,
             drop=drop_native_ir,
             loads=NATIVE_LOADS
         ),
         CompilationProduct.NATIVE_OBJECT: ProductSpec(
             needs=[CompilationProduct.NATIVE_LOWER],
             passes=native_object_passes,
             drop=drop_native_object
         ),
         CompilationProduct.GRAPHMEND: ProductSpec(
             passes=graphmend_passes,
             loads=GRAPHMEND_LOADS,
             on_import_error=ImportFallback.REPORT
         ),
         CompilationProduct.FORMAT: ProductSpec(passes=format_passes),
         CompilationProduct.FORMAT_LINTFIX: ProductSpec(passes=format_lintfix_passes),
         CompilationProduct.LINT: ProductSpec(passes=lint_passes),
         CompilationProduct.PYTHON_AST: ProductSpec(
             passes=python_ast_passes, tool=True
         ),
         CompilationProduct.PYTHON_SYMBOLS: ProductSpec(
             passes=python_symbols_passes, tool=True
         ),
         CompilationProduct.GRAMMAR: ProductSpec(passes=grammar_passes, tool=True),
         CompilationProduct.CFG_DOT: ProductSpec(passes=cfg_dot_passes, tool=True),
         CompilationProduct.NORMALIZE: ProductSpec(passes=normalize_passes, tool=True),
         CompilationProduct.UNPARSE: ProductSpec(passes=unparse_passes, tool=True),
         CompilationProduct.DOC: ProductSpec(passes=doc_passes, tool=True),
         CompilationProduct.FORMAT_TEXT: ProductSpec(
             passes=format_text_passes, tool=True
         )
     },
     _LOADING: ContextVar[list[CompilationProduct]] = ContextVar(
         'jac_schedule_loading', `default=[]
     );

def contract_of(p: type[CompilerPass]) -> PassContract {
    contract = p.contract;
    if contract is None {
        raise RuntimeError(
            f"scheduling error: pass {p.__name__} declares no contract; every "
            "scheduled pass states the analysis facts it requires and provides"
        );
    }
    return contract;
}

def validate_schedule(
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

def providers_of(passes: PassSchedule) -> set[AnalysisFact] {
    out: set[AnalysisFact] = set();
    for p in passes {
        for tag in contract_of(p).provides {
            out.add(tag);
        }
    }
    return out;
}

def schedule_loading -> bool {
    return bool(_LOADING.get());
}

def tier_reason(product: CompilationProduct) -> str {
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

def resolve(
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

def schedule_for(
    product: CompilationProduct,
    request: (ProductRequest | None) = None,
    internal: bool = False
) -> (PassSchedule | None) {
    return resolve(product, request, internal)[0];
}

def unavailable(product: CompilationProduct) -> str {
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

def product_passes(
    product: CompilationProduct, request: (ProductRequest | None) = None
) -> PassSchedule {
    return PRODUCTS[product].passes(
        request if request is not None else ProductRequest()
    );
}

def product_facts(product: CompilationProduct) -> set[AnalysisFact] {
    return providers_of(product_passes(product));
}

def early_passes -> PassSchedule {
    return [
        p
        for p in product_passes(CompilationProduct.IR)
        if contract_of(p).kernel_safe
    ];
}

def dependents(product: CompilationProduct) -> list[CompilationProduct] {
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

def product_ready(
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

def cancelled(cancel_token: (CancelToken | None)) -> bool {
    return cancel_token is not None and cancel_token.is_set();
}

def produce(
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

def require(
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

def invalidate(program: JacProgram, module: Module, product: CompilationProduct) {
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

def execute_passes(
    program: JacProgram,
    module: Module,
    passes: PassSchedule,
    cancel_token: (CancelToken | None) = None
) -> Module {
    import from jaclang.compiler.driver.pass_driver {
        run_pass,
        build_diagnostic_policy
    }
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

def run_utility(
    product: CompilationProduct,
    ir: any,
    program: JacProgram,
    cancel_token: (CancelToken | None) = None
) -> any {
    import from jaclang.compiler.driver.pass_driver { run_pass }
    if not PRODUCTS[product].tool {
        raise ValueError(f"{product.value} is not a utility product");
    }
    step = product_passes(product)[0];
    contract_of(step);
    return run_pass(step, ir, program, cancel_token=cancel_token);
}
