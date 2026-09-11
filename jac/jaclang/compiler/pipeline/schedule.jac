import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.pipeline.contracts {
    PassSpec,
    ErrorRecovery,
    PassContext,
    PassScope,
    AnalysisContract
}
import from jaclang.compiler.ir.identity { RelationFamily }
import from jaclang.compiler.pipeline.contracts { UtilityProduct }
import type from jaclang.compiler.pipeline.contracts {
    QuerySpec,
    QueryContext,
    NativeClosureRequest
}
import type from jaclang.compiler.pipeline.program_pass { QueryTransform }
import type from jaclang.compiler.analysis.placement.products { NativeEligibility }
import type from jaclang.compiler.ir.schema { Expr, Symbol }
import type from jaclang.compiler.ir.types.nodes { TypeBase }
import type from jaclang.compiler.session.session { JacProgram }
import type from jaclang.compiler.ir.schema { Module }
import os;
import from collections.abc { Callable }
import from contextvars { ContextVar }
import type from jaclang.compiler.pipeline.request { ModuleCompilation }
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.bootstrap.source_failures { fail_loud_on_compiler_source }
import from jaclang.compiler.pipeline.contracts {
    PassIdentity,
    AnalysisFact,
    AnalysisContract,
    CompilationProduct
}

glob PRODUCT_REQUIREMENTS:
         dict[
             CompilationProduct,
             list[tuple[CompilationProduct, AnalysisFact | None]]
         ] = {
         CompilationProduct.ANALYSIS: [
             (CompilationProduct.FLOW, AnalysisFact.CFG_SUCC)
         ],
         CompilationProduct.CLIENT: [
             (CompilationProduct.ANALYSIS, AnalysisFact.TYPE_OF)
         ],
         CompilationProduct.NATIVE_IR: [
             (CompilationProduct.ANALYSIS, AnalysisFact.TYPE_OF)
         ],
         CompilationProduct.SERVING: [(CompilationProduct.BOUNDARIES, None)],
         CompilationProduct.INTERFACE: [
             (CompilationProduct.FLOW, AnalysisFact.CFG_SUCC)
         ]
     };

def product_pipeline(product: CompilationProduct) -> list[PassIdentity] {
    if product == CompilationProduct.SPACES {
        return [PassIdentity.PlacementSpacesPass];
    }
    if product == CompilationProduct.IMPORTS {
        return [PassIdentity.DependencyFactsPass];
    }
    if product == CompilationProduct.PLACEMENT_SUMMARY {
        return [PassIdentity.PlacementSummaryPass];
    }
    if product == CompilationProduct.PLACEMENT {
        return [PassIdentity.ProgramPlacementPass, PassIdentity.DependencyFactsPass];
    }
    if product == CompilationProduct.CLIENT_DEPENDENCIES {
        return [PassIdentity.ClientDependenciesPass];
    }
    if product == CompilationProduct.SERVING {
        return [PassIdentity.ServingFactsPass];
    }
    if product == CompilationProduct.INTERFACE {
        return [PassIdentity.InterfaceFactsPass];
    }
    if product == CompilationProduct.SYMBOLS {
        return get_symtab_ir_sched();
    }
    if product == CompilationProduct.FLOW {
        return [PassIdentity.CFGBuildPass];
    }
    if product == CompilationProduct.ANALYSIS {
        return get_analysis_sched();
    }
    if product == CompilationProduct.BOUNDARIES {
        return get_boundary_analysis_sched();
    }
    if product == CompilationProduct.CLIENT {
        return [PassIdentity.EsastGenPass];
    }
    if product == CompilationProduct.LAYOUT {
        return [PassIdentity.LayoutPass];
    }
    if product == CompilationProduct.NATIVE_IR {
        return [
            PassIdentity.NativeImportFactsPass,
            PassIdentity.RcFactsPass,
            PassIdentity.NaIRGenPass
        ];
    }
    if product
        in (
            CompilationProduct.NATIVE_ELIGIBILITY,
            CompilationProduct.NATIVE_CLOSURE,
            CompilationProduct.TYPE_QUERY,
            CompilationProduct.PLACEMENT_REPORT,
            CompilationProduct.NATIVE_DEMOTION,
            CompilationProduct.CATALOG,
            CompilationProduct.CLIENT_LINK
        ) {
        return [];
    }
    raise ValueError(f"Product {product.value} requires an entry compilation");
}

enum CompilationPhase {
    PARSE = "parse",
    IR = "ir",
    PLACEMENT = "placement",
    ANALYSIS = "analysis",
    BOUNDARIES = "boundaries",
    NATIVE_CHECKS = "native_checks",
    CLIENT_DEPENDENCIES = "client_dependencies",
    INTERFACE = "interface",
    CODEGEN = "codegen"
}

obj CompilationStep {
    has phase: CompilationPhase,
        execute: Callable[[ModuleCompilation], None];
}

def module_pipeline -> list[CompilationStep] {
    import from jaclang.compiler.pipeline.request { ModuleCompilation }
    return [
        CompilationStep(CompilationPhase.PARSE, ModuleCompilation.parse),
        CompilationStep(CompilationPhase.IR, ModuleCompilation.ir),
        CompilationStep(CompilationPhase.PLACEMENT, ModuleCompilation.placement),
        CompilationStep(CompilationPhase.ANALYSIS, ModuleCompilation.analysis),
        CompilationStep(CompilationPhase.BOUNDARIES, ModuleCompilation.boundaries),
        CompilationStep(
            CompilationPhase.NATIVE_CHECKS, ModuleCompilation.native_checks
        ),
        CompilationStep(
            CompilationPhase.CLIENT_DEPENDENCIES, ModuleCompilation.client_dependencies
        ),
        CompilationStep(CompilationPhase.INTERFACE, ModuleCompilation.interface),
        CompilationStep(CompilationPhase.CODEGEN, ModuleCompilation.codegen)
    ];
}

def get_symtab_ir_sched -> list[PassIdentity] {
    if not schedule_tier_reason() {
        _tok = _ir_sched_loading.set(True);
        try {
            _import_all(SYMTAB_SCHED_DEPS);
        } except ImportError as e {
            fail_loud_on_compiler_source(e);
        } finally {
            _ir_sched_loading.reset(_tok);
        }
    }
    return validate_schedule(
        [
            PassIdentity.AppContextPass,
            PassIdentity.ModuleContextPass,
            PassIdentity.GraphLoweringPass,
            PassIdentity.ASTValidationPass,
            PassIdentity.DependencyFactsPass,
            PassIdentity.ComptimeImportsPass,
            PassIdentity.AbsorbImportsPass,
            PassIdentity.SymTabBuildPass,
            PassIdentity.DeclImplMatchPass,
            PassIdentity.BindingFactsPass,
            PassIdentity.PlacementApplyPass,
            PassIdentity.DependencyFactsPass
        ],
        origin='symtab-ir schedule'
    );
}

glob _ir_sched_loading = ContextVar('jac_ir_sched_loading', `default=False),
     _codegen_sched_loading = ContextVar('jac_codegen_sched_loading', `default=False),
     _analysis_sched_loading = ContextVar('jac_analysis_sched_loading', `default=False);

glob SYMTAB_SCHED_DEPS: tuple = (
         'jaclang.compiler.analysis.binding.symbol_utils',

     ),
     IR_SCHED_DEPS: tuple = (
         'jaclang.compiler.analysis.binding.symbol_utils',
         'jaclang.compiler.analysis.types.expr_keys',
         'jaclang.compiler.analysis.types.type_registry',
         'jaclang.compiler.analysis.types.field_semantics',
         'jaclang.compiler.analysis.types.intrinsic_registry',
         'jaclang.compiler.analysis.types.type_evaluator',
         'jaclang.compiler.session.cache.interface_codec',
         'jaclang.compiler.frontend.pyast_load_pass',
         'jaclang.compiler.lowering.layout_pass',
         'jaclang.compiler.analysis.flow.cfg_build_pass',
         'jaclang.compiler.analysis.binding.sem_def_match_pass',
         'jaclang.compiler.analysis.binding.jsx_intrinsic_guard_pass',
         'jaclang.compiler.lowering.mtir_gen_pass',
         'jaclang.compiler.analysis.comptime.comptime_resolve_pass',
         'jaclang.project.mobui_scope'
     ),
     ANALYSIS_SCHED_DEPS: tuple = (
         'jaclang.compiler.analysis.types.field_semantics',
         'jaclang.compiler.analysis.types.type_checker_pass',
         'jaclang.compiler.analysis.types.type_evaluator',
         'jaclang.compiler.frontend.pyast_load_pass',
         'jaclang.compiler.analysis.ownership.rc_facts_pass',
         'jaclang.compiler.analysis.types.type_utils',
         'jaclang.compiler.analysis.types.ts_decl_parser',
         'jaclang.compiler.analysis.binding.symbol_utils',
         'jaclang.compiler.analysis.types.expr_keys',
         'jaclang.compiler.analysis.types.type_registry',
         'jaclang.compiler.session.cache.annexes',
         'jaclang.compiler.backends.common.artifacts',
         'jaclang.compiler.frontend.diagnostic_utils',
         'jaclang.compiler.session.resolver',
         'jaclang.project.tomlio',
         'jaclang.project.mobui_scope',
         'jaclang.project.config',
         'jaclang.compiler.analysis.types.static_analysis_pass',
         'jaclang.compiler.analysis.binding.access_check_pass',
         'jaclang.compiler.analysis.types.variant_agreement_pass',
         'jaclang.compiler.analysis.capabilities.capability_check_pass',
         'jaclang.compiler.analysis.ownership.ownership_check_pass',
         'jaclang.compiler.analysis.ownership.region_infer_pass',
         'jaclang.compiler.tools.jac_auto_lint_pass'
     ),
     CODEGEN_SCHED_DEPS: tuple = (
         'jaclang.compiler.analysis.ownership.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.lowering.freeze_structure_pass'
     ),
     NATIVE_CODEGEN_DEPS: tuple = ('jaclang.compiler.backends.native', );

def module_in_flight(names: tuple) -> str {
    import sys;
    for name in names {
        spec = sys.modules.get(name)?.__spec__;
        if spec is not None and getattr(spec, '_initializing', False) {
            return name;
        }
    }
    return '';
}

def _import_all(names: tuple) {
    import importlib;
    for name in names {
        importlib.import_module(name);
    }
}

def schedule_tier_reason -> str {
    if _ir_sched_loading.get() {
        return 'the ir-gen schedule was still loading';
    }
    dep = module_in_flight(IR_SCHED_DEPS);
    if dep {
        return f"'{dep}', a dependency of the ir-gen schedule, was mid-import";
    }
    return '';
}

def _codegen_tier_reason -> str {
    if _codegen_sched_loading.get() {
        return 'the codegen schedule was still loading';
    }
    dep = module_in_flight(CODEGEN_SCHED_DEPS + NATIVE_CODEGEN_DEPS);
    if dep {
        return f"'{dep}', a dependency of the codegen schedule, was mid-import";
    }
    return schedule_tier_reason();
}

def pass_requires(p: PassIdentity) -> tuple[AnalysisFact, ...] {
    return PASS_REGISTRY[p].analysis.requires;
}

def pass_provides(p: PassIdentity) -> tuple[AnalysisFact, ...] {
    return PASS_REGISTRY[p].analysis.provides;
}

def validate_schedule(
    passes: list[PassIdentity],
    preprovided: (set[AnalysisFact] | None) = None,
    origin: str = 'schedule'
) -> list[PassIdentity] {
    provided: set[AnalysisFact] = set(preprovided)
        if preprovided is not None
        else set();
    for p in passes {
        for tag in pass_requires(p) {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.value} requires analysis "
                    f"'{tag}' which is neither provided by an earlier pass in "
                    f"the {origin} nor already available -- the schedule was "
                    f"constructed missing a declared dependency."
                );
            }
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
    return passes;
}

class TypeshedUnavailableError(RuntimeError) {}

glob _native_sched_failure: dict[str, str] = {};

def _note_native_schedule_failure(err: (BaseException | None)) {
    if err is None {
        _native_sched_failure.pop('reason', None);
    } else {
        _native_sched_failure['reason'] = f"{type(err).__name__}: {err}";
    }
}

def native_schedule_failure -> str {
    return _native_sched_failure.get('reason', '');
}

def get_boundary_analysis_sched -> list[PassIdentity] {
    return validate_schedule(
        [
            PassIdentity.BoundaryFactsPass,
            PassIdentity.BoundaryAnalysisPass,
            PassIdentity.EndpointEffectPass
        ],
        origin='boundary-analysis schedule'
    );
}

def get_bootstrap_ir_sched -> list[PassIdentity] {
    return validate_schedule(
        [
            PassIdentity.AppContextPass,
            PassIdentity.ModuleContextPass,
            PassIdentity.GraphLoweringPass,
            PassIdentity.ASTValidationPass,
            PassIdentity.DependencyFactsPass,
            PassIdentity.ComptimeImportsPass,
            PassIdentity.AbsorbImportsPass,
            PassIdentity.SymTabBuildPass,
            PassIdentity.DeclImplMatchPass,
            PassIdentity.SemanticAnalysisPass,
            PassIdentity.BindingFactsPass
        ],
        origin='bootstrap-ir schedule'
    );
}

def get_ir_gen_sched(
    is_internal: bool = False, gen_mtir: bool = True
) -> list[PassIdentity] {
    if schedule_tier_reason() {
        return get_bootstrap_ir_sched();
    }
    _tok = _ir_sched_loading.set(True);
    try {
        _import_all(IR_SCHED_DEPS);
        passes: list[PassIdentity] = [
            PassIdentity.AppContextPass,
            PassIdentity.ModuleContextPass,
            PassIdentity.GraphLoweringPass,
            PassIdentity.ASTValidationPass,
            PassIdentity.DependencyFactsPass,
            PassIdentity.ComptimeImportsPass,
            PassIdentity.AbsorbImportsPass,
            PassIdentity.SymTabBuildPass,
            PassIdentity.DeclImplMatchPass,
            PassIdentity.SemanticAnalysisPass,
            PassIdentity.SemDefMatchPass,
            PassIdentity.JsxIntrinsicGuardPass,
            PassIdentity.BindingFactsPass,
            PassIdentity.CFGBuildPass
        ];
        if gen_mtir {
            passes.append(PassIdentity.MTIRGenPass);
        }
        passes.append(PassIdentity.PlacementApplyPass);
        passes.append(PassIdentity.ComptimeResolvePass);
        return validate_schedule(passes, origin='ir-gen schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def typeshed_stubs_available -> bool {
    import jaclang;
    return os.path.exists(
        os.path.join(
            os.path.dirname(str(jaclang.__file__)),
            'vendor',
            'typeshed',
            'stdlib',
            'builtins.pyi'
        )
    );
}

def require_typeshed_stubs -> None {
    import from jaclang.jac0core.stubcat_hook { active }
    if active() is not None or typeshed_stubs_available() {
        return;
    }
    raise TypeshedUnavailableError(
        "type inference is on the critical path of every compilation, but this "
        "environment has neither a stub catalog nor the vendored typeshed stdlib "
        "stubs, so no module can be compiled. In a source checkout run "
        "'zig build fetch-typeshed'; in an installed environment reinstall the "
        "jac distribution, whose payload carries the catalog."
    );
}

def get_analysis_sched -> list[PassIdentity] {
    if _analysis_sched_loading.get() or module_in_flight(ANALYSIS_SCHED_DEPS) {
        return [];
    }
    require_typeshed_stubs();
    _tok = _analysis_sched_loading.set(True);
    try {
        _import_all(ANALYSIS_SCHED_DEPS);
        return validate_schedule(
            [
                PassIdentity.RegionInferPass,
                PassIdentity.VariantAgreementPass,
                PassIdentity.TypeCheckPass,
                PassIdentity.StaticAnalysisPass,
                PassIdentity.AccessCheckPass,
                PassIdentity.OwnershipCheckPass,
                PassIdentity.NativeCapabilityCheckPass,
                PassIdentity.ClientCapabilityCheckPass,
                PassIdentity.PortabilityWarnPass,
                PassIdentity.JacLintCheckPass
            ],
            preprovided={AnalysisFact.CFG_SUCC},
            origin='analysis schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        raise;
    } finally {
        _analysis_sched_loading.reset(_tok);
    }
}

glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if (
        _analysis_sched_loading.get()
        or _ir_sched_loading.get()
        or _codegen_sched_loading.get()
    ) {
        return (True, '');
    }
    reason = '';
    try {
        import from jaclang.compiler.backends.native.llvm.binding.ffi { _find_shim }
        _find_shim();
    } except ModuleNotFoundError {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return (False, 'native pipeline undecided: the compiler is still initializing');
    } except Exception {
        reason = (
            'native pipeline unavailable: LLVM shim (libjacllvm) '
            + 'not found in this environment'
        );
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}

def _py_codegen_tail -> list[PassIdentity] {
    return [
        PassIdentity.NativeImportFactsPass,
        PassIdentity.JcirGenPass,
        PassIdentity.JcirBytecodeGenPass
    ];
}

def get_py_code_gen(
    native: bool = True, provided: (set[AnalysisFact] | None) = None
) -> list[PassIdentity] {
    if _codegen_tier_reason() {
        return _py_codegen_tail();
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        _import_all(CODEGEN_SCHED_DEPS);
        passes: list[PassIdentity] = [
            PassIdentity.RcFactsPass,
            PassIdentity.EsastGenPass
        ];
        if native {
            _import_all(NATIVE_CODEGEN_DEPS);
            passes.extend([PassIdentity.NaIRGenPass, PassIdentity.NativeCompilePass]);
            _note_native_schedule_failure(None);
        }
        passes.extend(_py_codegen_tail());
        passes.append(PassIdentity.FreezeStructurePass);
        return validate_schedule(
            passes,
            preprovided={AnalysisFact.CFG_SUCC} if provided is None else provided,
            origin='codegen schedule'
        );
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if native {
            _note_native_schedule_failure(e);
        }
        return _py_codegen_tail();
    } finally {
        _codegen_sched_loading.reset(_tok);
    }
}

def providers_of(passes: list[PassIdentity]) -> set[AnalysisFact] {
    out: set[AnalysisFact] = set();
    for p in passes {
        for tag in pass_provides(p) {
            out.add(tag);
        }
    }
    return out;
}

def get_format_sched(auto_lint: bool = False) -> list[PassIdentity] {
    if auto_lint {
        return validate_schedule(
            [
                PassIdentity.CommentAttachPass,
                PassIdentity.JacAutoLintPass,
                PassIdentity.DocIRGenPass,
                PassIdentity.JacFormatPass
            ],
            origin='format schedule'
        );
    }
    return validate_schedule(
        [
            PassIdentity.CommentAttachPass,
            PassIdentity.DocIRGenPass,
            PassIdentity.JacFormatPass
        ],
        origin='format schedule'
    );
}

def get_unparse_sched(requires_format: bool = True) -> list[PassIdentity] {
    return validate_schedule(
        [PassIdentity.NormalizePass]
            + (get_format_sched() if requires_format else [PassIdentity.UnparsePass]),
        origin='unparse schedule'
    );
}

def get_lint_sched -> list[PassIdentity] {
    return validate_schedule([PassIdentity.JacLintCheckPass], origin='lint schedule');
}

def early_pipeline -> list[tuple[int, PassIdentity]] {
    return [
        (spec.native_early_bit, identity)
        for (identity, spec) in PASS_REGISTRY.items()
        if spec.native_early_bit
    ];
}


def utility_pipeline(product: UtilityProduct) -> list[PassIdentity] {
    if product == UtilityProduct.PYTHON_AST {
        return [PassIdentity.PyastBuildPass];
    } elif product == UtilityProduct.SYNTAX_DIAGNOSTICS {
        return [PassIdentity.ASTValidationPass];
    } elif product == UtilityProduct.INTERFACE_CONTEXT {
        return [PassIdentity.AppContextPass, PassIdentity.InterfaceReferenceTypesPass];
    } elif product == UtilityProduct.PYTHON_SYMBOLS {
        return [PassIdentity.AbsorbImportsPass, PassIdentity.SymTabBuildPass];
    } elif product == UtilityProduct.GRAMMAR {
        return [PassIdentity.GrammarExtractPass];
    } elif product == UtilityProduct.CFG_DOT {
        return [PassIdentity.CoalesceBBPass];
    } elif product == UtilityProduct.NORMALIZE {
        return [PassIdentity.NormalizePass];
    } elif product == UtilityProduct.UNPARSE {
        return [PassIdentity.UnparsePass];
    } elif product == UtilityProduct.DOC {
        return [PassIdentity.DocIRGenPass];
    } elif product == UtilityProduct.FORMAT {
        return [PassIdentity.JacFormatPass];
    }
    raise ValueError(f"Unsupported utility product: {product}");
}

def product_has_result(
    program: AnalysisServices, module: Module, product: CompilationProduct
) -> bool {
    import from jaclang.compiler.pipeline.keys {
        SPACES,
        SERVING,
        PLACEMENT_SUMMARY,
        INTERFACE
    }
    if product == CompilationProduct.INTERFACE {
        return program.analysis.lookup(module.loc.mod_path, INTERFACE) is not None;
    } elif product == CompilationProduct.SPACES {
        return program.analysis.lookup(module.loc.mod_path, SPACES) is not None;
    } elif product == CompilationProduct.SERVING {
        return program.analysis.lookup(module.loc.mod_path, SERVING) is not None;
    } elif product == CompilationProduct.PLACEMENT_SUMMARY {
        key = module.loc.mod_path or f'@{id(module)}';
        return program.analysis.lookup(key, PLACEMENT_SUMMARY) is not None;
    }
    expected = product_pipeline(product);
    return bool(expected)
        and all(step in program.analysis.module(module).completed for step in expected);
}

def native_eligibility_query -> QuerySpec[bool, NativeEligibility] {
    import from jaclang.compiler.analysis.placement.products { NativeEligibility }
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(
        context: QueryContext, request: bool
    ) -> QueryTransform[NativeEligibility] {
        import from jaclang.compiler.analysis.placement.passes { NativeEligibilityPass }
        return NativeEligibilityPass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            hold_exempt=request
        );
    }
    return QuerySpec[bool, NativeEligibility](
        PassIdentity.NativeEligibilityPass,
        CompilationProduct.NATIVE_ELIGIBILITY,
        create,
        writes=frozenset(
            {RelationFamily.STRUCTURE, RelationFamily.BINDING, RelationFamily.PLACEMENT}
        ),
        clone_syntax=True
    );
}

def native_closure_query -> QuerySpec[NativeClosureRequest, bool] {
    import from jaclang.compiler.pipeline.contracts { NativeClosureRequest }
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(
        context: QueryContext, request: NativeClosureRequest
    ) -> QueryTransform[bool] {
        import from jaclang.compiler.analysis.placement.passes { NativeClosurePass }
        return NativeClosurePass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            dependencies=request.dependencies,
            hold_exempt=request.hold_exempt
        );
    }
    return QuerySpec[NativeClosureRequest, bool](
        PassIdentity.NativeClosurePass,
        CompilationProduct.NATIVE_CLOSURE,
        create,
        writes=frozenset({RelationFamily.BINDING, RelationFamily.PLACEMENT}),
        clone_syntax=False
    );
}

def type_query -> QuerySpec[Expr | Symbol, TypeBase | None] {
    import from jaclang.compiler.ir.schema { Expr, Symbol }
    import from jaclang.compiler.ir.types.nodes { TypeBase }
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(
        context: QueryContext, request: Expr | Symbol
    ) -> QueryTransform[TypeBase | None] {
        import from jaclang.compiler.analysis.types.query_pass { TypeQueryPass }
        return TypeQueryPass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            query=request
        );
    }
    return QuerySpec[Expr | Symbol, TypeBase | None](
        PassIdentity.TypeQueryPass,
        CompilationProduct.TYPE_QUERY,
        create,
        recipe=lambda (query: Expr | Symbol) -> str { return str(id(query)); },
        writes=frozenset(
            {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
        ),
        clone_syntax=False
    );
}

def placement_report_query -> QuerySpec[None, dict] {
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(context: QueryContext, request: None) -> QueryTransform[dict] {
        import from jaclang.compiler.analysis.placement.passes { PlacementReportPass }
        return PlacementReportPass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token
        );
    }
    return QuerySpec[None, dict](
        PassIdentity.PlacementReportPass,
        CompilationProduct.PLACEMENT_REPORT,
        create,
        writes=frozenset(),
        clone_syntax=False
    );
}

def native_demotion_query -> QuerySpec[str, bool] {
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(context: QueryContext, request: str) -> QueryTransform[bool] {
        import from jaclang.compiler.analysis.placement.passes { NativeDemotionPass }
        return NativeDemotionPass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            path=request
        );
    }
    return QuerySpec[str, bool](
        PassIdentity.NativeDemotionPass,
        CompilationProduct.NATIVE_DEMOTION,
        create,
        writes=frozenset({RelationFamily.BINDING, RelationFamily.PLACEMENT}),
        clone_syntax=False
    );
}

def _create_ASTValidationPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.ast_validation_pass {
        ASTValidationPass
    }
    return ASTValidationPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_AbsorbImportsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.absorb_pass { AbsorbImportsPass }
    return AbsorbImportsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_AccessCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.access_check_pass { AccessCheckPass }
    return AccessCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_AppContextPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.context_pass { AppContextPass }
    return AppContextPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_BoundaryAnalysisPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.boundaries.boundary_analysis_pass {
        BoundaryAnalysisPass
    }
    return BoundaryAnalysisPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_BoundaryFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.boundaries.facts_pass { BoundaryFactsPass }
    return BoundaryFactsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_CFGBuildPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.flow.cfg_build_pass { CFGBuildPass }
    return CFGBuildPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ClientCapabilityCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.capabilities.capability_check_pass {
        ClientCapabilityCheckPass
    }
    return ClientCapabilityCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ClientDependenciesPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.client_dependencies_pass {
        ClientDependenciesPass
    }
    return ClientDependenciesPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_CoalesceBBPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.flow.cfg_build_pass { CoalesceBBPass }
    return CoalesceBBPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_CommentAttachPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    return CommentAttachPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ComptimeImportsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.comptime.imports_pass { ComptimeImportsPass }
    return ComptimeImportsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_ComptimeResolvePass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.comptime.comptime_resolve_pass {
        ComptimeResolvePass
    }
    return ComptimeResolvePass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_DeclImplMatchPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.decl_impl_match_pass {
        DeclImplMatchPass
    }
    return DeclImplMatchPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_DependencyFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.imports_pass { DependencyFactsPass }
    return DependencyFactsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_DocIRGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    return DocIRGenPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_EndpointEffectPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.boundaries.endpoint_effect_pass {
        EndpointEffectPass
    }
    return EndpointEffectPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_EsastGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    return EsastGenPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program,
        backend=context.client_backend
    );
}

def _create_FreezeStructurePass(context: PassContext) -> Transform {
    import from jaclang.compiler.lowering.freeze_structure_pass { FreezeStructurePass }
    return FreezeStructurePass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_GrammarExtractPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
    return GrammarExtractPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_GraphLoweringPass(context: PassContext) -> Transform {
    import from jaclang.compiler.lowering.graph_lowering_pass { GraphLoweringPass }
    return GraphLoweringPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_InterfaceFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.interfaces.interface_pass {
        InterfaceFactsPass
    }
    return InterfaceFactsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_InterfaceReferenceTypesPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.interfaces.reference_types_pass {
        InterfaceReferenceTypesPass
    }
    return InterfaceReferenceTypesPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_JacAutoLintPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    return JacAutoLintPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_JacFormatPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    return JacFormatPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_JacLintCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return JacLintCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_JcirBytecodeGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
    return JcirBytecodeGenPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_JcirGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
    return JcirGenPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_JsxIntrinsicGuardPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.jsx_intrinsic_guard_pass {
        JsxIntrinsicGuardPass
    }
    return JsxIntrinsicGuardPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_LayoutPass(context: PassContext) -> Transform {
    import from jaclang.compiler.lowering.layout_pass { LayoutPass }
    return LayoutPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_MTIRGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.lowering.mtir_gen_pass { MTIRGenPass }
    return MTIRGenPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ModuleContextPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.placement.module_context_pass {
        ModuleContextPass
    }
    return ModuleContextPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_NaIRGenPass(context: PassContext) -> Transform {
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    return NaIRGenPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_NativeCapabilityCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.capabilities.capability_check_pass {
        NativeCapabilityCheckPass
    }
    return NativeCapabilityCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_NativeCompilePass(context: PassContext) -> Transform {
    import from jaclang.compiler.backends.native.na_compile_pass { NativeCompilePass }
    return NativeCompilePass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_NativeImportFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.boundaries.native_import_pass {
        NativeImportFactsPass
    }
    return NativeImportFactsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_NormalizePass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.normalize_pass { NormalizePass }
    return NormalizePass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_OwnershipCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.ownership.ownership_check_pass {
        OwnershipCheckPass
    }
    return OwnershipCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_PlacementApplyPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.placement.solver { PlacementApplyPass }
    return PlacementApplyPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_PlacementSpacesPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.placement.passes { PlacementSpacesPass }
    return PlacementSpacesPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_PlacementSummaryPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.placement.passes { PlacementSummaryPass }
    return PlacementSummaryPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_PortabilityWarnPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.capabilities.capability_check_pass {
        PortabilityWarnPass
    }
    return PortabilityWarnPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ProgramPlacementPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.placement.passes { ProgramPlacementPass }
    return ProgramPlacementPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_PyastBuildPass(context: PassContext) -> Transform {
    import from jaclang.compiler.frontend.pyast_load_pass { PyastBuildPass }
    return PyastBuildPass(
        ir_in=context.python_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_RcFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.ownership.rc_facts_pass { RcFactsPass }
    return RcFactsPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_RegionInferPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.ownership.region_infer_pass {
        RegionInferPass
    }
    return RegionInferPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_SemDefMatchPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.sem_def_match_pass { SemDefMatchPass }
    return SemDefMatchPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_SemanticAnalysisPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.semantic_analysis_pass {
        SemanticAnalysisPass
    }
    return SemanticAnalysisPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_ServingFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.boundaries.serving_pass { ServingFactsPass }
    return ServingFactsPass(
        ir_in=context.ir,
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_StaticAnalysisPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.types.static_analysis_pass {
        StaticAnalysisPass
    }
    return StaticAnalysisPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_SymTabBuildPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.sym_tab_build_pass { SymTabBuildPass }
    return SymTabBuildPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_TypeCheckPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.types.type_checker_pass { TypeCheckPass }
    return TypeCheckPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_UnparsePass(context: PassContext) -> Transform {
    import from jaclang.compiler.tools.unparse_pass { UnparsePass }
    return UnparsePass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

def _create_VariantAgreementPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.types.variant_agreement_pass {
        VariantAgreementPass
    }
    return VariantAgreementPass(
        ir_in=context.module_ir(),
        cancel_token=context.cancel_token,
        cancel_requested=bool(
            context.cancel_token is not None and context.cancel_token.is_set()
        ),
        policy=context.policy,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed,
        prog=context.program
    );
}

def _create_BindingFactsPass(context: PassContext) -> Transform {
    import from jaclang.compiler.analysis.binding.facts_pass { BindingFactsPass }
    return BindingFactsPass(
        ir_in=context.ir,
        prog=context.program,
        policy=context.policy,
        cancel_token=context.cancel_token,
        errors_had=context.errors,
        warnings_had=context.warnings,
        completed=context.completed
    );
}

glob PASS_REGISTRY: dict[PassIdentity, PassSpec] = {
         PassIdentity.BindingFactsPass: PassSpec(
             PassIdentity.BindingFactsPass,
             _create_BindingFactsPass,
             PassScope.MODULE,
             frozenset({RelationFamily.BINDING}),
             AnalysisContract((AnalysisFact.SYM_OF, ), (AnalysisFact.BINDING_FACTS, ))
         ),
         PassIdentity.ASTValidationPass: PassSpec(
             PassIdentity.ASTValidationPass,
             _create_ASTValidationPass,
             PassScope.SYNTAX,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract(),
             native_early_bit=1,
             error_recovery=ErrorRecovery.NONBLOCKING
         ),
         PassIdentity.AbsorbImportsPass: PassSpec(
             PassIdentity.AbsorbImportsPass,
             _create_AbsorbImportsPass,
             PassScope.CLOSURE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.AccessCheckPass: PassSpec(
             PassIdentity.AccessCheckPass,
             _create_AccessCheckPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract((), (AnalysisFact.ACCESS_CHECKS, )),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.AppContextPass: PassSpec(
             PassIdentity.AppContextPass,
             _create_AppContextPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.BoundaryAnalysisPass: PassSpec(
             PassIdentity.BoundaryAnalysisPass,
             _create_BoundaryAnalysisPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.BoundaryFactsPass: PassSpec(
             PassIdentity.BoundaryFactsPass,
             _create_BoundaryFactsPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.CFGBuildPass: PassSpec(
             PassIdentity.CFGBuildPass,
             _create_CFGBuildPass,
             PassScope.MODULE,
             frozenset({RelationFamily.FLOW, RelationFamily.STRUCTURE}),
             AnalysisContract(
                 (),
                 (
                     AnalysisFact.CFG_SUCC,
                     AnalysisFact.CFG_TRUE,
                     AnalysisFact.CFG_FALSE,

                 )
             )
         ),
         PassIdentity.ClientCapabilityCheckPass: PassSpec(
             PassIdentity.ClientCapabilityCheckPass,
             _create_ClientCapabilityCheckPass,
             PassScope.MODULE,
             frozenset({RelationFamily.TYPES, RelationFamily.PLACEMENT}),
             AnalysisContract((), (AnalysisFact.CLIENT_CAPABILITY, )),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.ClientDependenciesPass: PassSpec(
             PassIdentity.ClientDependenciesPass,
             _create_ClientDependenciesPass,
             PassScope.CLOSURE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.CoalesceBBPass: PassSpec(
             PassIdentity.CoalesceBBPass,
             _create_CoalesceBBPass,
             PassScope.MODULE,
             frozenset({RelationFamily.FLOW}),
             AnalysisContract()
         ),
         PassIdentity.CommentAttachPass: PassSpec(
             PassIdentity.CommentAttachPass,
             _create_CommentAttachPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.ComptimeImportsPass: PassSpec(
             PassIdentity.ComptimeImportsPass,
             _create_ComptimeImportsPass,
             PassScope.CLOSURE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract()
         ),
         PassIdentity.ComptimeResolvePass: PassSpec(
             PassIdentity.ComptimeResolvePass,
             _create_ComptimeResolvePass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract((), (AnalysisFact.COMPTIME, ))
         ),
         PassIdentity.DeclImplMatchPass: PassSpec(
             PassIdentity.DeclImplMatchPass,
             _create_DeclImplMatchPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract((AnalysisFact.SYM_OF, ), (AnalysisFact.IMPL_OF, ))
         ),
         PassIdentity.DependencyFactsPass: PassSpec(
             PassIdentity.DependencyFactsPass,
             _create_DependencyFactsPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.DocIRGenPass: PassSpec(
             PassIdentity.DocIRGenPass,
             _create_DocIRGenPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.EndpointEffectPass: PassSpec(
             PassIdentity.EndpointEffectPass,
             _create_EndpointEffectPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.EsastGenPass: PassSpec(
             PassIdentity.EsastGenPass,
             _create_EsastGenPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.FreezeStructurePass: PassSpec(
             PassIdentity.FreezeStructurePass,
             _create_FreezeStructurePass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract((), (AnalysisFact.FROZEN, ))
         ),
         PassIdentity.GrammarExtractPass: PassSpec(
             PassIdentity.GrammarExtractPass,
             _create_GrammarExtractPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.GraphLoweringPass: PassSpec(
             PassIdentity.GraphLoweringPass,
             _create_GraphLoweringPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.InterfaceFactsPass: PassSpec(
             PassIdentity.InterfaceFactsPass,
             _create_InterfaceFactsPass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract()
         ),
         PassIdentity.InterfaceReferenceTypesPass: PassSpec(
             PassIdentity.InterfaceReferenceTypesPass,
             _create_InterfaceReferenceTypesPass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract()
         ),
         PassIdentity.JacAutoLintPass: PassSpec(
             PassIdentity.JacAutoLintPass,
             _create_JacAutoLintPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.JacFormatPass: PassSpec(
             PassIdentity.JacFormatPass,
             _create_JacFormatPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.JacLintCheckPass: PassSpec(
             PassIdentity.JacLintCheckPass,
             _create_JacLintCheckPass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.JcirBytecodeGenPass: PassSpec(
             PassIdentity.JcirBytecodeGenPass,
             _create_JcirBytecodeGenPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.JcirGenPass: PassSpec(
             PassIdentity.JcirGenPass,
             _create_JcirGenPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.JsxIntrinsicGuardPass: PassSpec(
             PassIdentity.JsxIntrinsicGuardPass,
             _create_JsxIntrinsicGuardPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.LayoutPass: PassSpec(
             PassIdentity.LayoutPass,
             _create_LayoutPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.MTIRGenPass: PassSpec(
             PassIdentity.MTIRGenPass,
             _create_MTIRGenPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.ModuleContextPass: PassSpec(
             PassIdentity.ModuleContextPass,
             _create_ModuleContextPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.NaIRGenPass: PassSpec(
             PassIdentity.NaIRGenPass,
             _create_NaIRGenPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract(
                 (
                     AnalysisFact.TYPE_OF,
                     AnalysisFact.CFG_SUCC,
                     AnalysisFact.OWNERSHIP,
                     AnalysisFact.CAPABILITY,
                     AnalysisFact.RC_FACTS,

                 ),
                 ()
             )
         ),
         PassIdentity.NativeCapabilityCheckPass: PassSpec(
             PassIdentity.NativeCapabilityCheckPass,
             _create_NativeCapabilityCheckPass,
             PassScope.MODULE,
             frozenset({RelationFamily.TYPES, RelationFamily.PLACEMENT}),
             AnalysisContract((), (AnalysisFact.CAPABILITY, )),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.NativeCompilePass: PassSpec(
             PassIdentity.NativeCompilePass,
             _create_NativeCompilePass,
             PassScope.CLOSURE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.NativeImportFactsPass: PassSpec(
             PassIdentity.NativeImportFactsPass,
             _create_NativeImportFactsPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.NormalizePass: PassSpec(
             PassIdentity.NormalizePass,
             _create_NormalizePass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.OwnershipCheckPass: PassSpec(
             PassIdentity.OwnershipCheckPass,
             _create_OwnershipCheckPass,
             PassScope.MODULE,
             frozenset({RelationFamily.TYPES, RelationFamily.FLOW}),
             AnalysisContract(
                 (AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF, ),
                 (AnalysisFact.OWNERSHIP, )
             ),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.PlacementApplyPass: PassSpec(
             PassIdentity.PlacementApplyPass,
             _create_PlacementApplyPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract(
                 (AnalysisFact.SYM_OF, ),
                 (
                     AnalysisFact.PLACED_IN,
                     AnalysisFact.DECIDED_CODESPACE,
                     AnalysisFact.CODESPACE_PULL,

                 )
             )
         ),
         PassIdentity.PlacementSpacesPass: PassSpec(
             PassIdentity.PlacementSpacesPass,
             _create_PlacementSpacesPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.PlacementSummaryPass: PassSpec(
             PassIdentity.PlacementSummaryPass,
             _create_PlacementSummaryPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.PortabilityWarnPass: PassSpec(
             PassIdentity.PortabilityWarnPass,
             _create_PortabilityWarnPass,
             PassScope.MODULE,
             frozenset({RelationFamily.TYPES, RelationFamily.PLACEMENT}),
             AnalysisContract((), (AnalysisFact.PORTABILITY, ))
         ),
         PassIdentity.ProgramPlacementPass: PassSpec(
             PassIdentity.ProgramPlacementPass,
             _create_ProgramPlacementPass,
             PassScope.CLOSURE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.PyastBuildPass: PassSpec(
             PassIdentity.PyastBuildPass,
             _create_PyastBuildPass,
             PassScope.SYNTAX,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.RcFactsPass: PassSpec(
             PassIdentity.RcFactsPass,
             _create_RcFactsPass,
             PassScope.MODULE,
             frozenset({RelationFamily.TYPES, RelationFamily.FLOW}),
             AnalysisContract((AnalysisFact.CFG_SUCC, ), (AnalysisFact.RC_FACTS, ))
         ),
         PassIdentity.RegionInferPass: PassSpec(
             PassIdentity.RegionInferPass,
             _create_RegionInferPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.TYPES,
                     RelationFamily.FLOW
                 }
             ),
             AnalysisContract((), (AnalysisFact.REGION_INFER, ))
         ),
         PassIdentity.SemDefMatchPass: PassSpec(
             PassIdentity.SemDefMatchPass,
             _create_SemDefMatchPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.SemanticAnalysisPass: PassSpec(
             PassIdentity.SemanticAnalysisPass,
             _create_SemanticAnalysisPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.ServingFactsPass: PassSpec(
             PassIdentity.ServingFactsPass,
             _create_ServingFactsPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT,
                     RelationFamily.TYPES
                 }
             ),
             AnalysisContract()
         ),
         PassIdentity.StaticAnalysisPass: PassSpec(
             PassIdentity.StaticAnalysisPass,
             _create_StaticAnalysisPass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract((), (AnalysisFact.STATIC_CHECKS, )),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.SymTabBuildPass: PassSpec(
             PassIdentity.SymTabBuildPass,
             _create_SymTabBuildPass,
             PassScope.MODULE,
             frozenset(
                 {
                     RelationFamily.STRUCTURE,
                     RelationFamily.BINDING,
                     RelationFamily.PLACEMENT
                 }
             ),
             AnalysisContract(
                 (),
                 (
                     AnalysisFact.SYM_OF,
                     AnalysisFact.DEFINES,
                     AnalysisFact.IN_SCOPE,
                     AnalysisFact.SCOPE_CHILD,

                 )
             ),
             native_early_bit=2
         ),
         PassIdentity.TypeCheckPass: PassSpec(
             PassIdentity.TypeCheckPass,
             _create_TypeCheckPass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract((), (AnalysisFact.TYPE_OF, )),
             error_recovery=ErrorRecovery.ALL
         ),
         PassIdentity.UnparsePass: PassSpec(
             PassIdentity.UnparsePass,
             _create_UnparsePass,
             PassScope.SYNTAX,
             frozenset({RelationFamily.STRUCTURE}),
             AnalysisContract()
         ),
         PassIdentity.VariantAgreementPass: PassSpec(
             PassIdentity.VariantAgreementPass,
             _create_VariantAgreementPass,
             PassScope.MODULE,
             frozenset(
                 {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
             ),
             AnalysisContract((), (AnalysisFact.VARIANT_AGREEMENT, )),
             error_recovery=ErrorRecovery.ALL
         )
     };

import type from jaclang.compiler.analysis.interfaces.facts {
    CatalogRequest,
    CatalogProduct
}

def catalog_query -> QuerySpec[CatalogRequest, CatalogProduct] {
    import from jaclang.compiler.analysis.interfaces.facts {
        CatalogRequest,
        CatalogProduct
    }
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(
        context: QueryContext, request: CatalogRequest
    ) -> QueryTransform[CatalogProduct] {
        import from jaclang.compiler.analysis.interfaces.catalog_pass {
            CatalogPreparePass
        }
        return CatalogPreparePass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            request=request
        );
    }
    return QuerySpec[CatalogRequest, CatalogProduct](
        PassIdentity.CatalogPreparePass,
        CompilationProduct.CATALOG,
        create,
        writes=frozenset(
            {RelationFamily.BINDING, RelationFamily.TYPES, RelationFamily.FLOW}
        )
    );
}

import type from jaclang.compiler.backends.es.link_facts {
    ClientLinkRequest,
    ClientGraph
}

def client_link_query -> QuerySpec[ClientLinkRequest, ClientGraph] {
    import from jaclang.compiler.backends.es.link_facts {
        ClientLinkRequest,
        ClientGraph
    }
    import from jaclang.compiler.pipeline.contracts { QuerySpec }
    def create(
        context: QueryContext, request: ClientLinkRequest
    ) -> QueryTransform[ClientGraph] {
        import from jaclang.compiler.backends.es.client_link { ClientLinkPass }
        return ClientLinkPass(
            ir_in=context.module,
            prog=context.program,
            policy=context.policy,
            cancel_token=context.program.options.cancel_token,
            request=request
        );
    }
    return QuerySpec[ClientLinkRequest, ClientGraph](
        PassIdentity.ClientLinkPass,
        CompilationProduct.CLIENT_LINK,
        create,
        writes=frozenset()
    );
}
