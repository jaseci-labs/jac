import os;
import time;
import from jaclang.compiler.passes.context { PassSchedule }
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    CompilationPhase,
    CompilationProduct
}
import from jaclang.compiler.driver.pipeline {
    _codegen_sched_loading,
    codegen_backend_passes,
    product_ready,
    providers_of_product,
    register_product_schedule,
    require_product,
    schedule_tier_reason,
    validate_schedule
}
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.driver.context_passes { NativeImportFactsPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.session_compile { SessionHooks }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.driver.module_analysis {
    ANALYSIS_PHASES,
    ModuleAnalysis,
    analyze_module,
    cancelled,
    carry_comptime_deps,
    record_phase
}

glob CODEGEN_SCHED_DEPS: tuple[str, ...] = (
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.passes.freeze_structure_pass'
     ),
     NATIVE_CODEGEN_DEPS: tuple[str, ...] = (
         'jaclang.compiler.backends.native.na_ir_gen_pass',

     ),
     _native_sched_failure: list[str] = [];

obj ModuleCompilation {
    has session: SessionHooks,
        analysis: ModuleAnalysis;

    def run_phase(phase: CompilationPhase) {
        if phase == CompilationPhase.NATIVE_CHECKS {
            self.native_checks();
        } elif phase == CompilationPhase.CLIENT_DEPENDENCIES {
            self.client_dependencies();
        } elif phase == CompilationPhase.INTERFACE {
            self.interface();
        } elif phase == CompilationPhase.CODEGEN {
            self.codegen();
        }
    }

    def native_checks {
        analysis = self.analysis;
        options = analysis.options;
        if not (
            options.no_cgen
            and (options.native_parity or options.native_required_for(analysis.path))
            and not options.symtab_ir_only
            and not analysis.parse_failed
            and not analysis.blocked
            and product_ready(
                analysis.program, analysis.module, CompilationProduct.ANALYSIS
            )
        ) {
            return;
        }
        if not (
            analysis.native or ModuleFacts.has_native_context_stmts(analysis.module)
        )
            or native_codegen() is None {
            return;
        }
        lowered = require_product(
            analysis.program,
            analysis.module,
            CompilationProduct.NATIVE_IR,
            cancel_token=options.cancel_token
        );
        if lowered and options.native_required_for(analysis.path) {
            self.session.assemble_native(analysis.program, analysis.module, True);
        }
    }

    def client_dependencies {
        analysis = self.analysis;
        options = analysis.options;
        if analysis.parse_failed
            or analysis.blocked
            or options.symtab_ir_only
            or options.no_cgen {
            return;
        }
        program = analysis.program;
        host = active_host();
        seen: set[str] = set();
        worklist: list[uni.Module | None] = [analysis.module];
        paths: list[str] = [];
        dep_options = CompileOptions(no_cgen=True, cancel_token=options.cancel_token);
        while worklist or paths {
            if worklist {
                current = worklist.pop();
                if current is not None {
                    paths.extend(client_import_paths(current));
                }
                continue;
            }
            dep_path = paths.pop();
            if dep_path in seen {
                continue;
            }
            seen.add(dep_path);
            dep = program.find_module(dep_path);
            has_facts = dep is not None
                and dep.gen
                and dep.gen.interop_manifest
                and bool(dep.gen.interop_manifest.bindings);
            if not has_facts and not program.has_failed_parse(dep_path) {
                served = host.client_boundary_facts(program, dep_path);
                if served is not None {
                    paths.extend(os.path.abspath(edge) for edge in served);
                    continue;
                }
                dep = self.session.compile(dep_path, program, None, dep_options);
            }
            worklist.append(dep);
        }
        program.options = options;
    }

    def interface {
        analysis = self.analysis;
        options = analysis.options;
        closure = self.session.closure_options() or options;
        if analysis.parse_failed or analysis.blocked or analysis.source is not None {
            return;
        }
        wants = (options.no_cgen and not options.symtab_ir_only)
            or (
                closure.no_cgen
                and not closure.symtab_ir_only
                and not (
                    analysis.program.internal
                    and active_host().in_compiler_tree(analysis.path)
                )
            );
        if wants {
            require_product(
                analysis.program,
                analysis.module,
                CompilationProduct.INTERFACE,
                cancel_token=options.cancel_token
            );
        }
    }

    def codegen {
        analysis = self.analysis;
        options = analysis.options;
        if analysis.parse_failed
            or analysis.blocked
            or options.no_cgen
            or options.symtab_ir_only {
            return;
        }
        program = analysis.program;
        module = analysis.module;
        program.options = options;
        if not analysis.full_head {
            program.run_schedule(
                mod=module,
                passes=get_bootstrap_code_gen(),
                cancel_token=options.cancel_token
            );
            self.session.assemble_python(program, module);
            return;
        }
        needs_native = analysis.native or ModuleFacts.has_native_context_stmts(module);
        if needs_native
            and not product_ready(program, module, CompilationProduct.ANALYSIS)
            and not require_product(
                program,
                module,
                CompilationProduct.ANALYSIS,
                cancel_token=options.cancel_token
            ) {
            analysis.blocked = True;
            return;
        }
        program.run_schedule(
            mod=module,
            passes=get_py_code_gen(
                native=needs_native,
                provided=program.analysis.analyses_run.provided(module)
            ),
            cancel_token=options.cancel_token
        );
        if module.gen.has_native_ir() {
            self.session.assemble_native(program, module, False);
        }
        self.session.assemble_python(program, module);
        if module.decided_codespace == 'native' {
            scrubbed = scrub_native_artifacts_on_error(program, module);
            if options.aot_mode and not scrubbed {
                report_missing_native_ir(program, module);
            }
        }
    }
}

def client_import_paths(module: uni.Module) -> list[str] {
    out: list[str] = [];
    for imp in module.get_all_sub_nodes(uni.Import) {
        if not imp.from_loc or imp.is_virtual_jac {
            continue;
        }
        try {
            source = imp.from_loc.resolve_relative_path();
        } except Exception {
            continue;
        }
        if isinstance(source, str)
            and imp.code_context == CodeContext.CLIENT
            and source.endswith('.jac') {
            out.append(os.path.abspath(source));
        }
    }
    return out;
}

def scrub_native_artifacts_on_error(program: JacProgram, mod: uni.Module) -> bool {
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or not program.module_scoped_errors(mod_path) {
        return False;
    }
    gen = mod.gen;
    gen.py_bytecode = None;
    gen.drop_native_ir();
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    return True;
}

def report_missing_native_ir(program: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.driver.pass_driver { deliver_alerts }
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    import from jaclang.compiler.passes.context { Alert }
    if mod?.gen is None or mod.gen.has_native_ir() {
        return;
    }
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or program.count_module_errors(mod_path) > 0 {
        return;
    }
    reason = native_schedule_failure();
    if not reason {
        (available, why) = active_host().native_pipeline_available();
        if not available {
            reason = why;
        }
    }
    if reason {
        detail = f"the native codegen schedule could not be built ({reason})";
    } elif not ModuleFacts.has_native_context_stmts(mod) {
        detail = "the module declares no native code for the backend to lower";
    } else {
        detail = (
            "the native codegen passes ran but emitted neither IR nor a "
            "diagnostic; this is a compiler bug -- please report it"
        );
    }
    from_pass: type = JcirGenPass;
    schedule = native_codegen();
    if schedule is not None {
        for step in schedule {
            from_pass = step;
        }
    }
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.span(),
                from_pass=from_pass,
                code=E5092,
                help_text=detail
            )
        ],
        [],
        program
    );
}

glob CODEGEN_PHASES: list[CompilationPhase] = [
         CompilationPhase.NATIVE_CHECKS,
         CompilationPhase.CLIENT_DEPENDENCIES,
         CompilationPhase.INTERFACE,
         CompilationPhase.CODEGEN
     ];

def module_pipeline -> list[CompilationPhase] {
    phases: list[CompilationPhase] = list(ANALYSIS_PHASES);
    phases.extend(CODEGEN_PHASES);
    return phases;
}

def analyze_for_compile(
    program: JacProgram, path: str, options: CompileOptions, source: str | None
) -> ModuleAnalysis {
    analysis = active_host().native_analyze(program, path, options, source);
    if analysis is None {
        analysis = analyze_module(program, path, options, source);
    }
    return analysis;
}

def run_codegen_phases(
    session: SessionHooks,
    program: JacProgram,
    analysis: ModuleAnalysis,
    options: CompileOptions
) {
    task = ModuleCompilation(session, analysis);
    for phase in CODEGEN_PHASES {
        if cancelled(options) {
            break;
        }
        started = time.perf_counter();
        try {
            task.run_phase(phase);
        } finally {
            record_phase(program, phase, started);
        }
    }
}

def native_refusal(
    program: JacProgram,
    analysis: ModuleAnalysis,
    errors_mark: int,
    analyzed: bool,
    late: bool = False
) -> (tuple[str, str, str] | None) {
    import from jaclang.compiler.placement.placement_facts { native_placement_soft }
    module = analysis.module;
    if analysis.parse_failed
        or module is None
        or not module.gen.placement_mode
        or not native_placement_soft(program, module) {
        return None;
    }
    if analyzed and len(program.errors_had) > errors_mark {
        first = program.errors_had[errors_mark];
        return (
            first.code.code if first.code is not None else "",
            first.pretty_print().split('\n')[0],
            "analysis"
        );
    }
    gen = module.gen;
    if gen is not None and gen.native_refusal {
        return (
            gen.native_refusal_code,
            gen.native_refusal,
            "late" if late else "static"
        );
    }
    return None;
}

def place_on_server(
    program: JacProgram,
    path: str,
    module: uni.Module,
    refusal: tuple[str, str, str],
    errors_mark: int,
    warnings_mark: int
) {
    import from jaclang.compiler.driver.session_compile { drop_native_bindings }
    import from jaclang.compiler.placement.placement_facts { server_plan }
    import from jaclang.compiler.placement.placement_solver { invalidate_importers_es }
    (code, detail, stage) = refusal;
    resolved = os.path.realpath(path);
    host = active_host();
    host.record_native_coverage(resolved, 'demoted', code, f"[{stage}] {detail}");
    host.record_placement_plan(path, server_plan(module));
    del program.errors_had[errors_mark:];
    del program.warnings_had[warnings_mark:];
    program.invalidate_module(resolved);
    for stale in invalidate_importers_es(program, resolved) {
        drop_native_bindings(stale, resolved);
    }
    host.note(
        f"note: {path} preferred native but did not lower; "
        f"compiled in the server codespace ({detail})",
        "dim"
    );
}

def compile_task(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> ModuleAnalysis {
    errors_mark = len(program.errors_had);
    warnings_mark = len(program.warnings_had);
    analysis = analyze_for_compile(program, path, options, source);
    refusal = native_refusal(program, analysis, errors_mark, True);
    if refusal is None {
        run_codegen_phases(session, program, analysis, options);
        refusal = native_refusal(
            program, analysis, errors_mark, analysis.blocked, late=True
        );
    }
    if refusal is not None {
        refused = analysis.module;
        place_on_server(program, path, refused, refusal, errors_mark, warnings_mark);
        try {
            analysis = analyze_for_compile(program, path, options, source);
        } finally {
            active_host().record_placement_plan(path, "");
        }
        carry_comptime_deps(refused, analysis.module);
        run_codegen_phases(session, program, analysis, options);
        again = native_refusal(program, analysis, len(program.errors_had), False);
        if again is not None {
            report_native_refusal(program, analysis.module, again[1]);
        }
    }
    return analysis;
}

def report_native_refusal(program: JacProgram, mod: uni.Module, detail: str) {
    import from jaclang.compiler.driver.pass_driver { deliver_alerts }
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    import from jaclang.compiler.passes.context { Alert }
    mod_path = mod.loc.mod_path if mod?.loc else '';
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.span(),
                from_pass=JcirGenPass,
                code=E5092,
                help_text=f"The module is declared native and cannot run in the "
                f"server codespace, but it did not lower: {detail}"
            )
        ],
        [],
        program
    );
}

def compile_module(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> uni.Module {
    return compile_task(session, program, path, options, source).module;
}

def _codegen_tier_reason -> str {
    if _codegen_sched_loading.get() {
        return 'the codegen schedule was still loading';
    }
    dep = active_host().module_in_flight(
        list(CODEGEN_SCHED_DEPS) + list(NATIVE_CODEGEN_DEPS)
    );
    if dep {
        return f"'{dep}', a dependency of the codegen schedule, was mid-import";
    }
    return schedule_tier_reason();
}

def _note_native_schedule_failure(reason: str) {
    _native_sched_failure.clear();
    if reason {
        _native_sched_failure.append(reason);
    }
}

def native_schedule_failure -> str {
    return _native_sched_failure[0] if _native_sched_failure else "";
}

def native_codegen -> (PassSchedule | None) {
    found = codegen_backend_passes("native");
    if found is not None {
        return found;
    }
    try {
        active_host().load_modules(list(NATIVE_CODEGEN_DEPS));
    } except ImportError as e {
        active_host().schedule_import_failed(e);
        _note_native_schedule_failure(f"{type(e).__name__}: {e}");
        return None;
    }
    return codegen_backend_passes("native");
}

def get_bootstrap_code_gen -> PassSchedule {
    return [NativeImportFactsPass, JcirGenPass];
}

def get_py_code_gen(
    native: bool = True, provided: (set[AnalysisFact] | None) = None
) -> PassSchedule {
    if _codegen_tier_reason() {
        return get_bootstrap_code_gen();
    }
    token = _codegen_sched_loading.set(True);
    try {
        active_host().load_modules(list(CODEGEN_SCHED_DEPS));
        import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
        import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
        import from jaclang.compiler.passes.freeze_structure_pass {
            FreezeStructurePass
        }
        passes: PassSchedule = [RcFactsPass, EsastGenPass];
        if native {
            schedule = native_codegen();
            if schedule is not None {
                for step in schedule {
                    passes.append(step);
                }
                _note_native_schedule_failure("");
            }
        }
        passes.extend(get_bootstrap_code_gen());
        passes.append(FreezeStructurePass);
        return validate_schedule(
            passes,
            preprovided=providers_of_product(CompilationProduct.ANALYSIS)
                if provided is None
                else provided,
            origin='codegen schedule'
        );
    } except ImportError as e {
        active_host().schedule_import_failed(e);
        if native {
            _note_native_schedule_failure(f"{type(e).__name__}: {e}");
        }
        return get_bootstrap_code_gen();
    } finally {
        _codegen_sched_loading.reset(token);
    }
}

def client_product_schedule -> PassSchedule {
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    return [EsastGenPass];
}

with entry {
    register_product_schedule(CompilationProduct.CLIENT, client_product_schedule);
}
