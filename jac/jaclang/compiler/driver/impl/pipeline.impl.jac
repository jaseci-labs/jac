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

impl no_blocker -> str {
    return '';
}

impl front_passes -> PassSchedule {
    return [
        PassKind.APP_CONTEXT,
        PassKind.GRAPH_LOWERING,
        PassKind.AST_VALIDATION,
        PassKind.ABSORB_IMPORTS,
        PassKind.SYM_TAB_BUILD
    ];
}

impl symbols_passes(request: ProductRequest) -> PassSchedule {
    return front_passes() + [PassKind.DECL_IMPL_MATCH, PassKind.PLACEMENT_APPLY];
}

impl bootstrap_ir_passes(request: ProductRequest) -> (PassSchedule | None) {
    return front_passes() + [PassKind.DECL_IMPL_MATCH, PassKind.SEMANTIC_ANALYSIS];
}

impl ir_passes(request: ProductRequest) -> PassSchedule {
    passes = front_passes()
        + [
            PassKind.IMPORT_WIRING,
            PassKind.PACKAGE_BOUNDARY,
            PassKind.DECL_IMPL_MATCH,
            PassKind.SEMANTIC_ANALYSIS,
            PassKind.SEM_DEF_MATCH,
            PassKind.CFG_BUILD
        ];
    if request.gen_mtir {
        passes.append(PassKind.MTIR_GEN);
    }
    passes.append(PassKind.JSX_INTRINSIC_GUARD);
    passes.append(PassKind.PLACEMENT_APPLY);
    passes.append(PassKind.COMPTIME_RESOLVE);
    return passes;
}

impl flow_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.CFG_BUILD];
}

impl analysis_passes(request: ProductRequest) -> PassSchedule {
    return [
        PassKind.REGION_INFER,
        PassKind.VARIANT_AGREEMENT,
        PassKind.TYPE_CHECK,
        PassKind.STATIC_ANALYSIS,
        PassKind.ACCESS_CHECK,
        PassKind.OWNERSHIP_CHECK,
        PassKind.PLACEMENT,
        PassKind.PORTABILITY_WARN,
        PassKind.JAC_LINT_CHECK
    ];
}

impl declaration_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.DECLARATION_TYPE];
}

impl boundary_passes(request: ProductRequest) -> PassSchedule {
    if not request.endpoint_effects {
        return [PassKind.BOUNDARY_FACTS, PassKind.BOUNDARY_ANALYSIS];
    }
    return [
        PassKind.BOUNDARY_FACTS,
        PassKind.BOUNDARY_ANALYSIS,
        PassKind.ENDPOINT_EFFECT
    ];
}

impl client_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.ESAST_GEN];
}

impl layout_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.LAYOUT];
}

impl codegen_passes(request: ProductRequest) -> PassSchedule {
    passes: PassSchedule = [PassKind.RC_FACTS, PassKind.ESAST_GEN];
    if request.native and not unavailable(CompilationProduct.NATIVE_LOWER) {
        passes.append(PassKind.NA_IR_GEN);
    }
    return passes;
}

impl py_ir_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.NATIVE_IMPORT_FACTS, PassKind.JCIR_GEN];
}

impl frozen_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.FREEZE_STRUCTURE];
}

impl bytecode_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.JCIR_BYTECODE_GEN];
}

impl native_ir_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.NATIVE_IMPORT_FACTS, PassKind.RC_FACTS, PassKind.NA_IR_GEN];
}

impl native_lower_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.RC_FACTS, PassKind.NA_IR_GEN];
}

impl native_toolchain_blocker -> str {
    (available, why) = active_host().native_pipeline_available();
    return '' if available else why;
}

impl native_object_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.NATIVE_COMPILE];
}

impl format_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.COMMENT_ATTACH, PassKind.DOC_IR_GEN, PassKind.JAC_FORMAT];
}

impl format_lintfix_passes(request: ProductRequest) -> PassSchedule {
    return [
        PassKind.COMMENT_ATTACH,
        PassKind.JAC_AUTO_LINT,
        PassKind.DOC_IR_GEN,
        PassKind.JAC_FORMAT
    ];
}

impl lint_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.JAC_LINT_CHECK];
}

impl python_ast_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.PYAST_BUILD];
}

impl python_symbols_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.SYM_TAB_BUILD];
}

impl grammar_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.GRAMMAR_EXTRACT];
}

impl cfg_dot_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.COALESCE_BB];
}

impl normalize_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.NORMALIZE];
}

impl unparse_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.UNPARSE];
}

impl doc_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.DOC_IR_GEN];
}

impl format_text_passes(request: ProductRequest) -> PassSchedule {
    return [PassKind.JAC_FORMAT];
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

impl contract_of(pass_kind: PassKind) -> PassContract {
    contract = PassContract();
    if pass_kind == PassKind.GRAPH_LOWERING
        or pass_kind == PassKind.AST_VALIDATION
        or pass_kind == PassKind.SEMANTIC_ANALYSIS
        or pass_kind == PassKind.SEM_DEF_MATCH
        or pass_kind == PassKind.JSX_INTRINSIC_GUARD {
        contract = PassContract(kernel_safe=True);
    } elif pass_kind == PassKind.SYM_TAB_BUILD {
        contract = PassContract(
            provides=(
                AnalysisFact.SYM_OF,
                AnalysisFact.DEFINES,
                AnalysisFact.IN_SCOPE,
                AnalysisFact.SCOPE_CHILD
            ),
            kernel_safe=True
        );
    } elif pass_kind == PassKind.DECL_IMPL_MATCH {
        contract = PassContract(
            requires=(AnalysisFact.SYM_OF, ),
            provides=(AnalysisFact.IMPL_OF, ),
            kernel_safe=True
        );
    } elif pass_kind == PassKind.CFG_BUILD {
        contract = PassContract(
            provides=(
                AnalysisFact.CFG_CATCH,
                AnalysisFact.CFG_SUCC,
                AnalysisFact.CFG_TRUE,
                AnalysisFact.CFG_FALSE
            ),
            kernel_safe=True
        );
    } elif pass_kind == PassKind.IMPORT_WIRING
        or pass_kind == PassKind.PACKAGE_BOUNDARY {
        contract = PassContract(requires=(AnalysisFact.SYM_OF, ));
    } elif pass_kind == PassKind.COMPTIME_RESOLVE {
        contract = PassContract(provides=(AnalysisFact.COMPTIME, ));
    } elif pass_kind == PassKind.REGION_INFER {
        contract = PassContract(provides=(AnalysisFact.REGION_INFER, ));
    } elif pass_kind == PassKind.VARIANT_AGREEMENT {
        contract = PassContract(provides=(AnalysisFact.VARIANT_AGREEMENT, ));
    } elif pass_kind == PassKind.TYPE_CHECK {
        contract = PassContract(provides=(AnalysisFact.TYPE_OF, ));
    } elif pass_kind == PassKind.STATIC_ANALYSIS {
        contract = PassContract(provides=(AnalysisFact.STATIC_CHECKS, ));
    } elif pass_kind == PassKind.ACCESS_CHECK {
        contract = PassContract(provides=(AnalysisFact.ACCESS_CHECKS, ));
    } elif pass_kind == PassKind.OWNERSHIP_CHECK {
        contract = PassContract(
            requires=(AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF),
            provides=(AnalysisFact.OWNERSHIP, )
        );
    } elif pass_kind == PassKind.PLACEMENT {
        contract = PassContract(
            requires=(AnalysisFact.TYPE_OF, ),
            provides=(AnalysisFact.CAPABILITY, AnalysisFact.CLIENT_CAPABILITY)
        );
    } elif pass_kind == PassKind.PORTABILITY_WARN {
        contract = PassContract(provides=(AnalysisFact.PORTABILITY, ));
    } elif pass_kind == PassKind.DECLARATION_TYPE {
        contract = PassContract(provides=(AnalysisFact.DECL_TYPES, ));
    } elif pass_kind == PassKind.PLACEMENT_APPLY {
        contract = PassContract(
            requires=(AnalysisFact.SYM_OF, ),
            provides=(
                AnalysisFact.PLACED_IN,
                AnalysisFact.DECIDED_CODESPACE,
                AnalysisFact.CODESPACE_PULL
            )
        );
    } elif pass_kind == PassKind.RC_FACTS {
        contract = PassContract(
            requires=(AnalysisFact.CFG_SUCC, ), provides=(AnalysisFact.RC_FACTS, )
        );
    } elif pass_kind == PassKind.FREEZE_STRUCTURE {
        contract = PassContract(provides=(AnalysisFact.FROZEN, ));
    } elif pass_kind == PassKind.NA_IR_GEN {
        contract = PassContract(
            requires=(
                AnalysisFact.TYPE_OF,
                AnalysisFact.CFG_SUCC,
                AnalysisFact.OWNERSHIP,
                AnalysisFact.CAPABILITY,
                AnalysisFact.RC_FACTS
            )
        );
    }
    return contract;
}

impl pass_class_of(pass_kind: PassKind) -> type[CompilerPass] {
    if pass_kind == PassKind.APP_CONTEXT {
        import from jaclang.compiler.driver.context_passes { AppContextPass }
        return AppContextPass;
    } elif pass_kind == PassKind.GRAPH_LOWERING {
        import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
        return GraphLoweringPass;
    } elif pass_kind == PassKind.AST_VALIDATION {
        import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
        return ASTValidationPass;
    } elif pass_kind == PassKind.ABSORB_IMPORTS {
        import from jaclang.compiler.driver.context_passes { AbsorbImportsPass }
        return AbsorbImportsPass;
    } elif pass_kind == PassKind.SYM_TAB_BUILD {
        import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
        return SymTabBuildPass;
    } elif pass_kind == PassKind.DECL_IMPL_MATCH {
        import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
        return DeclImplMatchPass;
    } elif pass_kind == PassKind.PLACEMENT_APPLY {
        import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
        return PlacementApplyPass;
    } elif pass_kind == PassKind.SEMANTIC_ANALYSIS {
        import from jaclang.compiler.passes.semantic_analysis_pass {
            SemanticAnalysisPass
        }
        return SemanticAnalysisPass;
    } elif pass_kind == PassKind.IMPORT_WIRING {
        import from jaclang.compiler.passes.import_wiring_pass { ImportWiringPass }
        return ImportWiringPass;
    } elif pass_kind == PassKind.PACKAGE_BOUNDARY {
        import from jaclang.compiler.passes.package_boundary_pass {
            PackageBoundaryPass
        }
        return PackageBoundaryPass;
    } elif pass_kind == PassKind.SEM_DEF_MATCH {
        import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
        return SemDefMatchPass;
    } elif pass_kind == PassKind.CFG_BUILD {
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        return CFGBuildPass;
    } elif pass_kind == PassKind.MTIR_GEN {
        import from jaclang.compiler.passes.mtir_gen_pass { MTIRGenPass }
        return MTIRGenPass;
    } elif pass_kind == PassKind.JSX_INTRINSIC_GUARD {
        import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }
        return JsxIntrinsicGuardPass;
    } elif pass_kind == PassKind.COMPTIME_RESOLVE {
        import from jaclang.compiler.passes.comptime_resolve_pass {
            ComptimeResolvePass
        }
        return ComptimeResolvePass;
    } elif pass_kind == PassKind.REGION_INFER {
        import from jaclang.compiler.passes.region_infer_pass { RegionInferPass }
        return RegionInferPass;
    } elif pass_kind == PassKind.VARIANT_AGREEMENT {
        import from jaclang.compiler.passes.variant_agreement_pass {
            VariantAgreementPass
        }
        return VariantAgreementPass;
    } elif pass_kind == PassKind.TYPE_CHECK {
        import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
        return TypeCheckPass;
    } elif pass_kind == PassKind.STATIC_ANALYSIS {
        import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
        return StaticAnalysisPass;
    } elif pass_kind == PassKind.ACCESS_CHECK {
        import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
        return AccessCheckPass;
    } elif pass_kind == PassKind.OWNERSHIP_CHECK {
        import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
        return OwnershipCheckPass;
    } elif pass_kind == PassKind.PLACEMENT {
        import from jaclang.compiler.passes.placement_pass { PlacementPass }
        return PlacementPass;
    } elif pass_kind == PassKind.PORTABILITY_WARN {
        import from jaclang.compiler.passes.capability_check_pass {
            PortabilityWarnPass
        }
        return PortabilityWarnPass;
    } elif pass_kind == PassKind.JAC_LINT_CHECK {
        import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
        return JacLintCheckPass;
    } elif pass_kind == PassKind.DECLARATION_TYPE {
        import from jaclang.compiler.passes.declaration_type_pass {
            DeclarationTypePass
        }
        return DeclarationTypePass;
    } elif pass_kind == PassKind.BOUNDARY_FACTS {
        import from jaclang.compiler.driver.context_passes { BoundaryFactsPass }
        return BoundaryFactsPass;
    } elif pass_kind == PassKind.BOUNDARY_ANALYSIS {
        import from jaclang.compiler.passes.boundary_analysis_pass {
            BoundaryAnalysisPass
        }
        return BoundaryAnalysisPass;
    } elif pass_kind == PassKind.ENDPOINT_EFFECT {
        import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
        return EndpointEffectPass;
    } elif pass_kind == PassKind.ESAST_GEN {
        import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
        return EsastGenPass;
    } elif pass_kind == PassKind.LAYOUT {
        import from jaclang.compiler.passes.layout_pass { LayoutPass }
        return LayoutPass;
    } elif pass_kind == PassKind.RC_FACTS {
        import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
        return RcFactsPass;
    } elif pass_kind == PassKind.NA_IR_GEN {
        import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
        return NaIRGenPass;
    } elif pass_kind == PassKind.NATIVE_IMPORT_FACTS {
        import from jaclang.compiler.driver.context_passes { NativeImportFactsPass }
        return NativeImportFactsPass;
    } elif pass_kind == PassKind.JCIR_GEN {
        import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
        return JcirGenPass;
    } elif pass_kind == PassKind.FREEZE_STRUCTURE {
        import from jaclang.compiler.passes.freeze_structure_pass {
            FreezeStructurePass
        }
        return FreezeStructurePass;
    } elif pass_kind == PassKind.JCIR_BYTECODE_GEN {
        import from jaclang.compiler.backends.py.jcir_bc_gen_pass {
            JcirBytecodeGenPass
        }
        return JcirBytecodeGenPass;
    } elif pass_kind == PassKind.NATIVE_COMPILE {
        import from jaclang.compiler.backends.native.na_compile_pass {
            NativeCompilePass
        }
        return NativeCompilePass;
    } elif pass_kind == PassKind.COMMENT_ATTACH {
        import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
        return CommentAttachPass;
    } elif pass_kind == PassKind.DOC_IR_GEN {
        import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
        return DocIRGenPass;
    } elif pass_kind == PassKind.JAC_FORMAT {
        import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
        return JacFormatPass;
    } elif pass_kind == PassKind.JAC_AUTO_LINT {
        import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
        return JacAutoLintPass;
    } elif pass_kind == PassKind.PYAST_BUILD {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
        return PyastBuildPass;
    } elif pass_kind == PassKind.GRAMMAR_EXTRACT {
        import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
        return GrammarExtractPass;
    } elif pass_kind == PassKind.COALESCE_BB {
        import from jaclang.compiler.tools.cfg_dot { CoalesceBBPass }
        return CoalesceBBPass;
    } elif pass_kind == PassKind.NORMALIZE {
        import from jaclang.compiler.tools.normalize_pass { NormalizePass }
        return NormalizePass;
    } elif pass_kind == PassKind.UNPARSE {
        import from jaclang.compiler.tools.unparse_pass { UnparsePass }
        return UnparsePass;
    }
    raise ValueError(f"unknown compiler pass: {pass_kind.value}");
}

impl bind_schedule(passes: PassSchedule) -> PassSchedule {
    for pass_kind in passes {
        pass_class_of(pass_kind);
    }
    return passes;
}

impl run_scheduled_pass(
    pass_kind: PassKind,
    module: Module,
    program: JacProgram,
    cancel_token: (CancelToken | None),
    policy: DiagnosticPolicy
) -> Module {
    return run_pass(
        pass_class_of(pass_kind),
        module,
        program,
        cancel_token=cancel_token,
        policy=policy
    ).module;
}

impl run_early_pass(pass_kind: PassKind, module: Module) -> CompileContext {
    if pass_kind
        not in (
            PassKind.APP_CONTEXT,
            PassKind.GRAPH_LOWERING,
            PassKind.AST_VALIDATION,
            PassKind.ABSORB_IMPORTS,
            PassKind.SYM_TAB_BUILD,
            PassKind.DECL_IMPL_MATCH,
            PassKind.SEMANTIC_ANALYSIS,
            PassKind.SEM_DEF_MATCH,
            PassKind.CFG_BUILD,
            PassKind.JSX_INTRINSIC_GUARD
        ) {
        raise ValueError(
            f"pass is not available during early parse: {pass_kind.value}"
        );
    }
    import from jaclang.compiler.passes.execution { run_walker }
    return run_walker(pass_class_of(pass_kind), module=module).ctx;
}

impl native_ir_alert(
    module: Module,
    module_name: str,
    detail: str,
    code: DiagnosticInfo,
    schedule_unavailable: bool
) -> Alert {
    if schedule_unavailable {
        return Alert(
            msg=code.format_message(kind='module', name=module_name),
            loc=module.loc.span(),
            from_pass=JcirGenPass,
            code=code,
            help_text=detail
        );
    }
    return Alert(
        msg=code.format_message(kind='module', name=module_name),
        loc=module.loc.span(),
        from_pass=NaIRGenPass,
        code=code,
        help_text=detail
    );
}

impl validate_schedule(
    passes: PassSchedule,
    preprovided: (set[AnalysisFact] | None) = None,
    origin: str = 'schedule'
) -> PassSchedule {
    provided: set[AnalysisFact] = set(preprovided)
        if preprovided is not None
        else set();
    for pass_kind in passes {
        contract = contract_of(pass_kind);
        for tag in contract.requires {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {pass_kind.value} requires analysis "
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
    for pass_kind in passes {
        for tag in contract_of(pass_kind).provides {
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
    peer_fell_back: bool = False,
    source_path: str = ""
) -> tuple[(PassSchedule | None), bool, bool] {
    spec = PRODUCTS[product];
    req = request if request is not None else ProductRequest();
    if spec.tiered and source_path {
        for load_name in spec.loads {
            parts = load_name.split(".");
            if parts and parts[0] == "jaclang" {
                source_suffix = "jaclang" + os.sep + os.sep.join(parts[1:]) + ".jac";
                if source_path.endswith(source_suffix) {
                    return (spec.bootstrap(req), False, False);
                }
            }
        }
    }
    if spec.tiered and (peer_fell_back or tier_reason(product)) {
        return (spec.bootstrap(req), False, False);
    }
    if spec.blocker() {
        return (spec.bootstrap(req), False, False);
    }
    if req.native and PRODUCTS[CompilationProduct.NATIVE_LOWER].blocker() {
        req = ProductRequest(
            gen_mtir=req.gen_mtir, native=False, endpoint_effects=req.endpoint_effects
        );
    }
    spec.precheck();
    token = _LOADING.set(_LOADING.get() + [product]);
    schedule: PassSchedule = [];
    try {
        if spec.loads {
            active_host().load_modules(list(spec.loads));
        }
        schedule = bind_schedule(spec.passes(req));
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
    blocked = spec.blocker();
    if blocked {
        return blocked;
    }
    try {
        if spec.loads {
            active_host().load_modules(list(spec.loads));
        }
        bind_schedule(spec.passes(ProductRequest()));
    } except ImportError as e {
        active_host().schedule_import_failed(e);
        return f"{type(e).__name__}: {e}";
    }
    return '';
}

impl product_passes(
    product: CompilationProduct, request: (ProductRequest | None) = None
) -> PassSchedule {
    return bind_schedule(
        PRODUCTS[product].passes(request if request is not None else ProductRequest())
    );
}

impl product_facts(product: CompilationProduct) -> set[AnalysisFact] {
    return providers_of(product_passes(product));
}

impl early_passes -> PassSchedule {
    return [
        pass_kind
        for pass_kind in product_passes(CompilationProduct.IR)
        if contract_of(pass_kind).kernel_safe
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
        product,
        request,
        program.internal,
        peer_fell_back,
        module.loc.mod_path or module.source.file_path
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
                for pass_kind in product_passes(current) {
                    if not contract_of(pass_kind).provides {
                        build.done.discard(pass_kind.value);
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
    for pass_kind in passes {
        if pass_kind.value in build.done {
            continue;
        }
        if cancelled(cancel_token) {
            return module;
        }
        module = run_scheduled_pass(pass_kind, module, program, cancel_token, policy);
        build.facts.update(contract_of(pass_kind).provides);
        if cancelled(cancel_token) {
            return module;
        }
        build.done.add(pass_kind.value);
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
    pass_kind = product_passes(product)[0];
    contract_of(pass_kind);
    policy = build_diagnostic_policy(program);
    return run_pass(
        pass_class_of(pass_kind), ir, program, cancel_token=cancel_token, policy=policy
    );
}
