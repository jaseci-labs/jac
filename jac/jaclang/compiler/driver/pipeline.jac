import os;
import time;
import type from threading { Event }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.pipeline_runner { ModuleCompilation }
import type from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.driver.context_passes {
    AppContextPass,
    AbsorbImportsPass,
    BoundaryFactsPass,
    NativeImportFactsPass
}
import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.graph_lowering_pass { GraphLoweringPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.endpoint_effect_pass { EndpointEffectPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.placement.placement_solver { PlacementApplyPass }
import from jaclang.compiler.driver.pipeline_types {
    UtilityProduct,
    AnalysisFact,
    PassContract,
    CompilationProduct,
    ProductTask,
    TaskState
}
import from jaclang.compiler.driver.client_graph { collect_client_graph }

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
     };

def product_pipeline(product: CompilationProduct) -> list[type[Transform]] {
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
    if product == CompilationProduct.CLIENT {
        import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
        return [EsastGenPass];
    }
    if product == CompilationProduct.LAYOUT {
        import from jaclang.compiler.passes.layout_pass { LayoutPass }
        return [LayoutPass];
    }
    if product == CompilationProduct.NATIVE_IR {
        import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
        import from jaclang.compiler.backends.native { NaIRGenPass }
        return [NativeImportFactsPass, RcFactsPass, NaIRGenPass];
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
    import from jaclang.compiler.driver.compilation_context { cache_scope }
    import from jaclang.compiler.driver.jir { get_module_cache_path }
    identity = program.context_key;
    with cache_scope(identity, program.options) {
        try {
            get_module_cache_path(path).unlink(missing_ok=True);
        } except OSError {}
    }
}


def require_product(
    program: JacProgram, module: Module, product: CompilationProduct
) -> bool {
    program.analysis.retain_tasks(module);
    tasks = program.analysis.product_tasks.setdefault(id(module), {});
    task = tasks.get(product);
    if task is not None {
        if task.state == TaskState.RUNNING {
            raise RuntimeError(
                f"Compilation dependency cycle: {product.value} of {module.loc.mod_path}"
            );
        }
        return task.state == TaskState.SUCCEEDED;
    }
    task = ProductTask(product, TaskState.RUNNING);
    tasks[product] = task;
    start = time.perf_counter();
    before = len(program.errors_had);
    try {
        if product in (CompilationProduct.ANALYSIS, CompilationProduct.NATIVE_IR)
            and not program.analysis.analyses_run.provides(
                module, AnalysisFact.CFG_SUCC
            ) {
            if not require_product(program, module, CompilationProduct.FLOW) {
                task.state = TaskState.FAILED;
                return False;
            }
        }
        if product in (CompilationProduct.CLIENT, CompilationProduct.NATIVE_IR)
            and not program.analysis.analyses_run.provides(
                module, AnalysisFact.TYPE_OF
            ) {
            if not require_product(program, module, CompilationProduct.ANALYSIS) {
                task.state = TaskState.FAILED;
                return False;
            }
        }
        if product == CompilationProduct.INTERFACE {
            if not program.iface_registry().prepare_interface(
                os.path.realpath(module.loc.mod_path), module
            ) {
                task.state = TaskState.FAILED;
                return False;
            }
        } else {
            program.run_schedule(module, product_pipeline(product));
        }
        task.state = TaskState.CANCELLED
            if program.options.cancel_token is not None
                and program.options.cancel_token.is_set()
            else (
                TaskState.SUCCEEDED
                    if len(program.errors_had) == before
                    else TaskState.FAILED
            );
        return task.state == TaskState.SUCCEEDED;
    } except Exception {
        task.state = TaskState.FAILED;
        raise;
    } finally {
        task.elapsed = time.perf_counter() - start;
    }
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
    import from jaclang.compiler.driver.pipeline_runner { ModuleCompilation }
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

def compile_module(
    compiler: JacCompiler,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> Module {
    import from jaclang.compiler.driver.pipeline_runner { ModuleCompilation }
    task = ModuleCompilation(compiler, program, path, options, source);
    for step in module_pipeline() {
        if options.cancel_token is not None and options.cancel_token.is_set() {
            break;
        }
        started = time.perf_counter();
        try {
            step.execute(task);
        } finally {
            name = step.phase.name;
            program.analysis.phase_time[name] = (
                program.analysis.phase_time.get(name, 0.0) + time.perf_counter()
                - started
            );
        }
    }
    return task.module;
}

def get_symtab_ir_sched -> list[type[Transform]] {
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

def pass_requires(p: type[Transform]) -> tuple[AnalysisFact, ...] {
    return PASS_CONTRACTS.get(p.__name__, PassContract()).requires;
}

def pass_provides(p: type[Transform]) -> tuple[AnalysisFact, ...] {
    return PASS_CONTRACTS.get(p.__name__, PassContract()).provides;
}

def validate_schedule(
    passes: list[type[Transform]],
    preprovided: (set[AnalysisFact] | None) = None,
    origin: str = 'schedule'
) -> list[type[Transform]] {
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

def get_boundary_analysis_sched -> list[type[Transform]] {
    return validate_schedule(
        [BoundaryFactsPass, BoundaryAnalysisPass, EndpointEffectPass],
        origin='boundary-analysis schedule'
    );
}

def get_ir_gen_sched(gen_mtir: bool = True) -> list[type[Transform]] {
    import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
    import from jaclang.compiler.passes.sem_def_match_pass { SemDefMatchPass }
    import from jaclang.compiler.passes.jsx_intrinsic_guard_pass {
        JsxIntrinsicGuardPass
    }

    passes: list[type[Transform]] = [
        AppContextPass,
        GraphLoweringPass,
        ASTValidationPass,
        AbsorbImportsPass,
        SymTabBuildPass,
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
    import from jaclang.compiler.passes.comptime_resolve_pass { ComptimeResolvePass }
    passes.append(ComptimeResolvePass);
    return validate_schedule(passes, origin='ir-gen schedule');
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
    import from jaclang.compiler.types.stubcat.state { active }
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

def get_analysis_sched -> list[type[Transform]] {
    require_typeshed_stubs();
    import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
    import from jaclang.compiler.passes.static_analysis_pass { StaticAnalysisPass }
    import from jaclang.compiler.passes.access_check_pass { AccessCheckPass }
    import from jaclang.compiler.passes.variant_agreement_pass { VariantAgreementPass }
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
        preprovided={AnalysisFact.CFG_SUCC},
        origin='analysis schedule'
    );
}

glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    reason = '';
    try {
        import from jaclang.compiler.backends.native.llvm { _find_shim }
        _find_shim();
    } except OSError as error {
        reason = f"native pipeline unavailable: {error}";
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}

def _py_codegen_tail -> list[type[Transform]] {
    return [NativeImportFactsPass, JcirGenPass, JcirBytecodeGenPass];
}

def get_py_code_gen(
    native: bool = True, provided: (set[AnalysisFact] | None) = None
) -> list[type[Transform]] {
    import from jaclang.compiler.backends.es { EsastGenPass }
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }

    passes: list[type[Transform]] = [RcFactsPass, EsastGenPass];
    if native {
        import from jaclang.compiler.backends.native { NaIRGenPass, NativeCompilePass }
        passes.extend([NaIRGenPass, NativeCompilePass]);
    }
    passes.extend(_py_codegen_tail());
    import from jaclang.compiler.passes.freeze_structure_pass { FreezeStructurePass }
    passes.append(FreezeStructurePass);
    return validate_schedule(
        passes,
        preprovided={AnalysisFact.CFG_SUCC} if provided is None else provided,
        origin='codegen schedule'
    );
}

def providers_of(passes: list[type[Transform]]) -> set[AnalysisFact] {
    out: set[AnalysisFact] = set();
    for p in passes {
        for tag in pass_provides(p) {
            out.add(tag);
        }
    }
    return out;
}

def get_format_sched(auto_lint: bool = False) -> list[type[Transform]] {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return validate_schedule(
            [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass],
            origin='format schedule'
        );
    }
    return validate_schedule(
        [CommentAttachPass, DocIRGenPass, JacFormatPass], origin='format schedule'
    );
}

def get_lint_sched -> list[type[Transform]] {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
}

def build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes {
    import from jaclang.compiler.driver.pipeline_runner { wasm_artifact }
    return wasm_artifact(program, path, exports);
}


def execute_passes(
    program: JacProgram,
    module: Module,
    passes: list[type[Transform]],
    cancel_token: Event | None = None
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
            break;
        }
        module = run_pass(
            step, module, program, cancel_token=cancel_token, policy=policy
        ).ir_out;
        provided.update(pass_provides(step));
        if cancel_token is None or not cancel_token.is_set() {
            completed.add(step.__name__);
        }
    }
    return module;
}


def run_utility(
    product: UtilityProduct,
    ir: any,
    program: JacProgram,
    cancel_token: Event | None = None
) -> Transform {
    import from jaclang.compiler.driver.pass_driver { run_pass }
    step: type[Transform];
    if product == UtilityProduct.PYTHON_AST {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
        step = PyastBuildPass;
    } elif product == UtilityProduct.PYTHON_SYMBOLS {
        step = SymTabBuildPass;
    } elif product == UtilityProduct.GRAMMAR {
        import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
        step = GrammarExtractPass;
    } elif product == UtilityProduct.CFG_DOT {
        import from jaclang.compiler.passes.cfg_build_pass { CoalesceBBPass }
        step = CoalesceBBPass;
    } elif product == UtilityProduct.NORMALIZE {
        import from jaclang.compiler.tools.normalize_pass { NormalizePass }
        step = NormalizePass;
    } elif product == UtilityProduct.UNPARSE {
        import from jaclang.compiler.tools.unparse_pass { UnparsePass }
        step = UnparsePass;
    } elif product == UtilityProduct.DOC {
        import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
        step = DocIRGenPass;
    } elif product == UtilityProduct.FORMAT {
        import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
        step = JacFormatPass;
    } else {
        raise ValueError(f"Unknown utility product: {product}");
    }
    return run_pass(step, ir, program, cancel_token=cancel_token);
}

def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
    artifact = program.get_client_artifact(os.path.realpath(path));
    if artifact is None {
        return (None, None);
    }
    return (artifact.manifest.page_export, artifact.manifest.layout_export);
}


def compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> Module {
    import copy;
    import from pathlib { Path }
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    import from jaclang.compiler.frontend.unitree { Import, ModulePath }
    import from jaclang.compiler.backends.py.artifact_imports { package_sources }
    import from jaclang.extensions { is_annex }
    import from jaclang.project.app_kinds { kind_has_client }
    entry_path = os.path.realpath(entry_path);
    project_root = os.path.realpath(
        options.project_root or os.path.dirname(entry_path)
    );
    selected = context_program(program, bind_options(entry_path, program, options));
    pending: list[tuple[JacProgram, str]] = [(selected, entry_path)];
    if kind_has_client(options.app_kind) {
        pages = Path(entry_path).parent / 'pages';
        if pages.is_dir() {
            pending.extend(
                (selected, str(p))
                for p in sorted(pages.rglob('*.jac'))
                if not is_annex(str(p))
            );
        }
    }
    seen: set[tuple[str, str]] = set();
    entry_module: Module | None = None;
    while pending {
        (context, path) = pending.pop(0);
        if options.cancel_token is not None and options.cancel_token.is_set() {
            break;
        }
        bound = bind_options(path, context, copy.copy(context.options));
        bound.no_cgen = options.no_cgen;
        bound.native_parity = options.native_parity;
        bound.cancel_token = options.cancel_token;
        context = context_program(context, bound);
        identity = (context.context_key, path);
        if identity in seen {
            continue;
        }
        seen.add(identity);
        module = program.compile(path, options=bound);
        if path == entry_path and entry_module is None {
            entry_module = module;
        }
        dependencies = package_sources(path, project_root);
        dependencies.update(context.iface_registry().direct_deps.get(path, {}));
        dependencies.update(
            dependency
            for (dependency, importers) in context.deps.dependents.items()
            if path in importers
        );
        for statement in module.get_all_sub_nodes(Import) {
            if not statement.is_jac or statement.is_virtual_jac {
                continue;
            }
            imports = [statement.from_loc]
                if statement.from_loc is not None
                else [
                    item
                    for item in statement.items
                    if isinstance(item, ModulePath)
                ];
            for imported in imports {
                dependency = imported.resolve_relative_path();
                if isinstance(dependency, str) and dependency.endswith('.jac') {
                    dependencies.add(os.path.realpath(dependency));
                }
            }
        }
        pending.extend(
            (context, dependency)
            for dependency in sorted(dependencies)
            if dependency.startswith(project_root + os.sep)
                and os.path.isfile(dependency)
                and not any(
                    part in ('.jac', 'node_modules', 'venv')
                    for part in os.path.relpath(dependency, project_root).split(os.sep)
                )
        );
    }
    if entry_module is None {
        raise RuntimeError(
            f'Application compilation cancelled before parsing {entry_path}'
        );
    }
    return entry_module;
}
