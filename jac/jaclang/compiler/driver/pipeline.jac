import from jaclang.compiler.passes.context { PassSchedule }
import os;
import time;
import from collections.abc { Callable }
import type from jaclang.compiler.driver.compile_options { CancelToken }
import from contextvars { ContextVar }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.context_passes {
    AppContextPass,
    AbsorbImportsPass,
    BoundaryFactsPass
}
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.import_wiring_pass { ImportWiringPass }

import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.driver.pipeline_types {
    UtilityProduct,
    AnalysisFact,
    PassContract,
    CompilationProduct,
    ProductTask,
    TaskState
}

glob PASS_CONTRACTS: dict[str, PassContract] = {
         'AccessCheckPass': PassContract((), (AnalysisFact.ACCESS_CHECKS, )),
         'CFGBuildPass': PassContract(
             (),
             (AnalysisFact.CFG_SUCC, AnalysisFact.CFG_TRUE, AnalysisFact.CFG_FALSE, )
         ),
         'ClientCapabilityCheckPass': PassContract(
             (), (AnalysisFact.CLIENT_CAPABILITY, )
         ),
         'ComptimeResolvePass': PassContract((), (AnalysisFact.COMPTIME, )),
         'DeclImplMatchPass': PassContract(
             (AnalysisFact.SYM_OF, ), (AnalysisFact.IMPL_OF, )
         ),
         'FreezeStructurePass': PassContract((), (AnalysisFact.FROZEN, )),
         'ImportWiringPass': PassContract((AnalysisFact.SYM_OF, ), ()),
         'NaIRGenPass': PassContract(
             (
                 AnalysisFact.TYPE_OF,
                 AnalysisFact.CFG_SUCC,
                 AnalysisFact.OWNERSHIP,
                 AnalysisFact.CAPABILITY,
                 AnalysisFact.RC_FACTS,

             ),
             ()
         ),
         'NativeCapabilityCheckPass': PassContract((), (AnalysisFact.CAPABILITY, )),
         'OwnershipCheckPass': PassContract(
             (AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF, ), (AnalysisFact.OWNERSHIP, )
         ),
         'PlacementApplyPass': PassContract(
             (AnalysisFact.SYM_OF, ),
             (
                 AnalysisFact.PLACED_IN,
                 AnalysisFact.DECIDED_CODESPACE,
                 AnalysisFact.CODESPACE_PULL,

             )
         ),
         'PortabilityWarnPass': PassContract((), (AnalysisFact.PORTABILITY, )),
         'RcFactsPass': PassContract(
             (AnalysisFact.CFG_SUCC, ), (AnalysisFact.RC_FACTS, )
         ),
         'RegionInferPass': PassContract((), (AnalysisFact.REGION_INFER, )),
         'StaticAnalysisPass': PassContract((), (AnalysisFact.STATIC_CHECKS, )),
         'SymTabBuildPass': PassContract(
             (),
             (
                 AnalysisFact.SYM_OF,
                 AnalysisFact.DEFINES,
                 AnalysisFact.IN_SCOPE,
                 AnalysisFact.SCOPE_CHILD,

             )
         ),
         'TypeCheckPass': PassContract((), (AnalysisFact.TYPE_OF, )),
         'VariantAgreementPass': PassContract((), (AnalysisFact.VARIANT_AGREEMENT, ))
     },
     _PRODUCT_SCHEDULES: dict[CompilationProduct, Callable[[], PassSchedule]] = {};

def register_product_schedule(
    product: CompilationProduct, schedule: Callable[[], PassSchedule]
) {
    _PRODUCT_SCHEDULES[product] = schedule;
}

def product_pipeline(product: CompilationProduct) -> PassSchedule {
    if product == CompilationProduct.SYMBOLS {
        return get_symtab_ir_sched();
    }
    if product == CompilationProduct.FLOW {
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        return [CFGBuildPass];
    }
    if product == CompilationProduct.ANALYSIS {
        return get_analysis_sched();
    }
    if product == CompilationProduct.BOUNDARIES {
        return get_boundary_analysis_sched();
    }
    if product == CompilationProduct.LAYOUT {
        import from jaclang.compiler.passes.layout_pass { LayoutPass }
        return [LayoutPass];
    }
    registered = _PRODUCT_SCHEDULES.get(product);
    if registered is not None {
        return registered();
    }
    raise ValueError(f"Product {product.value} requires an entry compilation");
}

def invalidate_client_product(program: JacProgram, module: Module) {
    module.gen.js = '';
    module.gen.es_ast = None;
    tasks = program.analysis.product_tasks.get(id(module));
    if tasks is not None {
        tasks.pop(CompilationProduct.CLIENT, None);
    }
    completed = program.analysis.completed_passes.get(id(module));
    if completed is not None {
        for step in product_pipeline(CompilationProduct.CLIENT) {
            completed.discard(step.__name__);
        }
    }
    path = os.path.realpath(module.loc.mod_path);
    program.hub.client_artifacts.pop(path, None);
    active_host().drop_python_lane_products(path, program);
}

glob PRODUCT_READY_FACTS: dict[CompilationProduct, tuple[AnalysisFact, ...]] = {
         CompilationProduct.FLOW: (AnalysisFact.CFG_SUCC, ),
         CompilationProduct.ANALYSIS: (AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF, ),
         CompilationProduct.CLIENT: (AnalysisFact.TYPE_OF, ),
         CompilationProduct.NATIVE_IR: (AnalysisFact.CFG_SUCC, AnalysisFact.TYPE_OF, ),

     },
     PRODUCT_PREREQUISITES: dict[CompilationProduct, tuple[CompilationProduct, ...]] = {
         CompilationProduct.ANALYSIS: (CompilationProduct.FLOW, ),
         CompilationProduct.CLIENT: (CompilationProduct.ANALYSIS, ),
         CompilationProduct.NATIVE_IR: (
             CompilationProduct.FLOW,
             CompilationProduct.ANALYSIS,

         )
     };

def product_ready(
    program: JacProgram, module: Module, product: CompilationProduct
) -> bool {
    for fact in PRODUCT_READY_FACTS.get(product, ()) {
        if not program.analysis.analyses_run.provides(module, fact) {
            return False;
        }
    }
    tasks = program.analysis.product_tasks.get(id(module));
    task = tasks.get(product) if tasks is not None else None;
    return task is None or task.state == TaskState.SUCCEEDED;
}

def providers_of_product(
    product: CompilationProduct, visiting: (set[CompilationProduct] | None) = None
) -> set[AnalysisFact] {
    if visiting is None {
        visiting = set();
    }
    if product in visiting {
        raise RuntimeError(f"product prerequisite cycle through {product.value}");
    }
    visiting.add(product);
    facts = set(providers_of(product_pipeline(product)));
    for prereq in PRODUCT_PREREQUISITES.get(product, ()) {
        facts |= providers_of_product(prereq, visiting);
    }
    visiting.discard(product);
    return facts;
}

def prereq_provides(product: CompilationProduct) -> set[AnalysisFact] {
    facts: set[AnalysisFact] = set();
    for prereq in PRODUCT_PREREQUISITES.get(product, ()) {
        facts |= providers_of_product(prereq);
    }
    return facts;
}

def validate_product_specs {
    for product in PRODUCT_READY_FACTS {
        available = providers_of_product(product);
        for fact in PRODUCT_READY_FACTS[product] {
            if fact not in available {
                raise RuntimeError(
                    f"product {product.value} declares readiness fact "
                    f"'{fact.value}' that neither its pipeline nor its "
                    f"prerequisites provide"
                );
            }
        }
    }
}

def require_product(
    program: JacProgram,
    module: Module,
    product: CompilationProduct,
    cancel_token: (CancelToken | None) = None
) -> bool {
    active_cancel = cancel_token
        if cancel_token is not None
        else program.options.cancel_token;
    program.analysis.retain_tasks(module);
    tasks = program.analysis.product_tasks.setdefault(id(module), {});
    task = tasks.get(product);
    if task is not None {
        if task.state == TaskState.RUNNING {
            raise RuntimeError(
                f"Compilation dependency cycle: {product.value} of {module.loc.mod_path}"
            );
        }
        if task.state == TaskState.SUCCEEDED {
            if product_ready(program, module, product) {
                return True;
            }
        } elif task.state == TaskState.FAILED
            or (active_cancel is not None and active_cancel.is_set()) {
            return False;
        }
        task.state = TaskState.RUNNING;
    } else {
        task = ProductTask(product, TaskState.RUNNING);
        tasks[product] = task;
    }
    start = time.perf_counter();
    before = len(program.errors_had);
    try {
        for prereq in PRODUCT_PREREQUISITES.get(product, ()) {
            if product_ready(program, module, prereq) {
                continue;
            }
            if not require_product(
                program, module, prereq, cancel_token=active_cancel
            ) {
                task.state = TaskState.CANCELLED
                    if active_cancel is not None and active_cancel.is_set()
                    else TaskState.FAILED;
                return False;
            }
        }
        if product == CompilationProduct.INTERFACE {
            if not active_host().prepare_interface(
                program, os.path.realpath(module.loc.mod_path), module
            ) {
                task.state = TaskState.FAILED;
                return False;
            }
        } else {
            schedule = product_pipeline(product);
            if not schedule {
                task.state = TaskState.PENDING;
                return False;
            }
            module = execute_passes(
                program, module, schedule, cancel_token=active_cancel
            );
        }
        if active_cancel is not None and active_cancel.is_set() {
            task.state = TaskState.CANCELLED;
        } elif len(program.errors_had) != before {
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

def get_symtab_ir_sched -> PassSchedule {
    if not schedule_tier_reason() {
        _tok = _ir_sched_loading.set(True);
        try {
            active_host().load_modules(list(SYMTAB_SCHED_DEPS));
        } except ImportError {} finally {
            _ir_sched_loading.reset(_tok);
        }
    }
    return validate_schedule(
        [
            AppContextPass,
            GraphLoweringPass,
            ASTValidationPass,
            AbsorbImportsPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            PlacementApplyPass
        ],
        origin='symtab-ir schedule'
    );
}

glob _ir_sched_loading: ContextVar[bool] = ContextVar(
         'jac_ir_sched_loading', `default=False
     ),
     _analysis_sched_loading: ContextVar[bool] = ContextVar(
         'jac_analysis_sched_loading', `default=False
     );

glob SYMTAB_SCHED_DEPS: tuple[str, ...] = ('jaclang.compiler.symbol_utils', ),
     IR_SCHED_DEPS: tuple[str, ...] = (
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
     ),
     ANALYSIS_SCHED_DEPS: tuple[str, ...] = (
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
         'jaclang.compiler.passes.ownership_check_pass',
         'jaclang.compiler.passes.region_infer_pass',
         'jaclang.compiler.tools.jac_auto_lint_pass'
     );

def schedule_tier_reason -> str {
    if _ir_sched_loading.get() {
        return 'the ir-gen schedule was still loading';
    }
    dep = active_host().module_in_flight(list(IR_SCHED_DEPS));
    if dep {
        return f"'{dep}', a dependency of the ir-gen schedule, was mid-import";
    }
    return '';
}

def pass_requires(p: type) -> tuple[AnalysisFact, ...] {
    return PASS_CONTRACTS.get(p.__name__, PassContract()).requires;
}

def pass_provides(p: type) -> tuple[AnalysisFact, ...] {
    return PASS_CONTRACTS.get(p.__name__, PassContract()).provides;
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
        for tag in pass_requires(p) {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.__name__} requires analysis "
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

def get_boundary_analysis_sched -> PassSchedule {
    return validate_schedule(
        [BoundaryFactsPass, BoundaryAnalysisPass, EndpointEffectPass],
        origin='boundary-analysis schedule'
    );
}

def get_bootstrap_ir_sched -> PassSchedule {
    return validate_schedule(
        [
            AppContextPass,
            GraphLoweringPass,
            ASTValidationPass,
            AbsorbImportsPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass
        ],
        origin='bootstrap-ir schedule'
    );
}

def get_ir_gen_sched(is_internal: bool = False, gen_mtir: bool = True) -> PassSchedule {
    if schedule_tier_reason() {
        return get_bootstrap_ir_sched();
    }
    _tok = _ir_sched_loading.set(True);
    try {
        active_host().load_modules(list(IR_SCHED_DEPS));
        import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
        import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }

        passes: PassSchedule = [
            AppContextPass,
            GraphLoweringPass,
            ASTValidationPass,
            AbsorbImportsPass,
            SymTabBuildPass,
            ImportWiringPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass
        ];
        if gen_mtir {
            import from jaclang.compiler.passes.mtir_gen_pass { MTIRGenPass }
            passes.append(MTIRGenPass);
        }
        passes.append(JsxIntrinsicGuardPass);
        passes.append(PlacementApplyPass);
        import from jaclang.compiler.passes.comptime_resolve_pass {
            ComptimeResolvePass
        }
        passes.append(ComptimeResolvePass);
        return validate_schedule(passes, origin='ir-gen schedule');
    } except ImportError {
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def typeshed_stubs_available -> bool {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    return os.path.exists(
        os.path.join(jaclang_pkg_root(), 'vendor', 'typeshed', 'stdlib', 'builtins.pyi')
    );
}

def require_typeshed_stubs -> None {
    if active_host().has_active_stub_catalog() or typeshed_stubs_available() {
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

def get_analysis_sched -> PassSchedule {
    if _analysis_sched_loading.get()
        or active_host().module_in_flight(list(ANALYSIS_SCHED_DEPS)) {
        return [];
    }
    require_typeshed_stubs();
    _tok = _analysis_sched_loading.set(True);
    try {
        active_host().load_modules(list(ANALYSIS_SCHED_DEPS));
        import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
        import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
        import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.variant_agreement_pass {
            VariantAgreementPass
        }
        import from jaclang.compiler.passes.capability_check_pass {
            ClientCapabilityCheckPass,
            NativeCapabilityCheckPass,
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.ownership_check_pass { OwnershipCheckPass }
        import from jaclang.compiler.passes.region_infer_pass { RegionInferPass }
        import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
        return validate_schedule(
            [
                RegionInferPass,
                VariantAgreementPass,
                TypeCheckPass,
                StaticAnalysisPass,
                AccessCheckPass,
                OwnershipCheckPass,
                NativeCapabilityCheckPass,
                ClientCapabilityCheckPass,
                PortabilityWarnPass,
                JacLintCheckPass
            ],
            preprovided=prereq_provides(CompilationProduct.ANALYSIS),
            origin='analysis schedule'
        );
    } finally {
        _analysis_sched_loading.reset(_tok);
    }
}

def providers_of(passes: PassSchedule) -> set[AnalysisFact] {
    out: set[AnalysisFact] = set();
    for p in passes {
        for tag in pass_provides(p) {
            out.add(tag);
        }
    }
    return out;
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
    program.analysis.retain_tasks(module);
    provided = program.analysis.analyses_run.provided(module);
    validate_schedule(
        passes,
        preprovided=provided,
        origin=f"schedule for module {module.loc.mod_path}"
    );
    policy = build_diagnostic_policy(program);
    completed = program.analysis.completed_passes.setdefault(id(module), set());
    for step in passes {
        if step.__name__ in completed {
            continue;
        }
        if cancel_token is not None and cancel_token.is_set() {
            return module;
        }
        module = run_pass(
            step, module, program, cancel_token=cancel_token, policy=policy
        ).module;
        provided.update(pass_provides(step));
        if cancel_token is None or not cancel_token.is_set() {
            completed.add(step.__name__);
        } else {
            return module;
        }
    }
    return module;
}
