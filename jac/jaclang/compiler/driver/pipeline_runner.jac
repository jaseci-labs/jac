import from jaclang.compiler.passes.context { PassSchedule }
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    CompilationProduct,
    UtilityProduct
}
import type from jaclang.compiler.driver.compile_options { CancelToken }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.driver.toolchain {
    _codegen_sched_loading,
    native_pipeline_available
}
import from jaclang.compiler.driver.pipeline {
    providers_of_product,
    register_product_schedule,
    schedule_tier_reason,
    validate_schedule
}
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.driver.context_passes { NativeImportFactsPass }
import from jaclang.compiler.driver.source_failures { fail_loud_on_compiler_source }
import from jaclang.compiler.backends.py.jcir_bc_gen_pass { JcirBytecodeGenPass }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import time;
import from collections.abc { Callable }
import from jaclang.compiler.driver.pipeline_types { CompilationPhase }
import from jaclang.compiler.driver.module_analysis {
    ANALYSIS_PHASES,
    ModuleAnalysis,
    analyze_module,
    cancelled,
    record_phase
}

obj ModuleCompilation {
    has compiler: JacCompiler,
        analysis: ModuleAnalysis;

    def native_checks {
        import from jaclang.compiler.driver.pipeline {
            require_product,
            product_ready,
            CompilationProduct
        }
        if (
            self.analysis.options.no_cgen
            and (
                self.analysis.options.native_parity
                or self.analysis.options.native_required_for(self.analysis.path)
            )
            and not self.analysis.options.symtab_ir_only
            and not self.analysis.parse_failed
            and not self.analysis.blocked
            and product_ready(
                self.analysis.program, self.analysis.module, CompilationProduct.ANALYSIS
            )
        ) {
            import from jaclang.compiler.frontend.module_facts {
                ModuleFacts as _PtyMcp
            }
            if self.analysis.native
                or _PtyMcp.has_native_context_stmts(self.analysis.module) {
                lowered = require_product(
                    self.analysis.program,
                    self.analysis.module,
                    CompilationProduct.NATIVE_IR,
                    cancel_token=self.analysis.options.cancel_token
                );
                if lowered
                    and self.analysis.options.native_required_for(self.analysis.path) {
                    import copy;
                    import from jaclang.compiler.backends.native.na_compile_pass {
                        NativeCompilePass
                    }
                    previous = self.analysis.program.options;
                    checked = copy.copy(previous);
                    checked.aot_mode = True;
                    checked.skip_native_engine = False;
                    self.analysis.program.options = checked;
                    try {
                        self.analysis.program.run_schedule(
                            self.analysis.module, [NativeCompilePass]
                        );
                    } finally {
                        self.analysis.program.options = previous;
                    }
                }
            }
        }
    }

    def client_dependencies {
        if (
            not self.analysis.parse_failed
            and not self.analysis.blocked
            and not self.analysis.options.symtab_ir_only
            and not self.analysis.options.no_cgen
        ) {
            import os as _cb_os;
            cb_seen: set[str] = set();
            cb_worklist: list[uni.Module | None] = [self.analysis.module];
            cb_paths: list[str] = [];

            cb_opts = CompileOptions(
                no_cgen=True, cancel_token=self.analysis.options.cancel_token
            );
            cb_reg = self.analysis.program.iface_registry();
            while cb_worklist or cb_paths {
                if cb_worklist {
                    cb_cur = cb_worklist.pop();
                    if cb_cur is None {
                        continue;
                    }
                    for cb_imp in cb_cur.get_all_sub_nodes(uni.Import) {
                        if not cb_imp.from_loc {
                            continue;
                        }

                        if cb_imp.is_virtual_jac {
                            continue;
                        }
                        try {
                            cb_src = cb_imp.from_loc.resolve_relative_path();
                        } except Exception {
                            continue;
                        }
                        cb_is_client_dep = isinstance(cb_src, str)
                            and cb_imp.code_context == CodeContext.CLIENT
                            and cb_src.endswith('.jac');
                        if not cb_is_client_dep {
                            continue;
                        }
                        cb_paths.append(_cb_os.path.abspath(cb_src));
                    }
                    continue;
                }
                cb_next = cb_paths.pop();
                if cb_next in cb_seen {
                    continue;
                }
                cb_seen.add(cb_next);

                cb_mod = self.analysis.program.find_module(cb_next);
                cb_has_facts = (
                    cb_mod is not None
                    and cb_mod.gen
                    and cb_mod.gen.interop_manifest
                    and bool(cb_mod.gen.interop_manifest.bindings)
                );

                cb_known_bad = self.analysis.program.has_failed_parse(cb_next);
                if not cb_has_facts and not cb_known_bad {
                    cb_served: (list[str] | None) = None;
                    try {
                        cb_served = cb_reg.client_boundary_facts(cb_next);
                    } except Exception {
                        cb_served = None;
                    }
                    if cb_served is not None {
                        for cb_edge in cb_served {
                            cb_paths.append(_cb_os.path.abspath(cb_edge));
                        }
                        continue;
                    }
                    cb_mod = self.compiler.compile(
                        file_path=cb_next,
                        target_program=self.analysis.program,
                        options=cb_opts
                    );
                }
                cb_worklist.append(cb_mod);
            }
            self.analysis.program.options = self.analysis.options;
        }
    }

    def interface {
        import from jaclang.compiler.driver.jir { is_compiler_tree_path }
        closure = self.compiler._closure_opts or self.analysis.options;
        if not self.analysis.parse_failed
            and not self.analysis.blocked
            and self.analysis.source is None
            and (
                (
                    self.analysis.options.no_cgen
                    and not self.analysis.options.symtab_ir_only
                )
                or (
                    closure.no_cgen
                    and not closure.symtab_ir_only
                    and not (
                        self.analysis.program.internal
                        and is_compiler_tree_path(self.analysis.path)
                    )
                )
            ) {
            import from jaclang.compiler.driver.pipeline {
                require_product,
                CompilationProduct
            }
            require_product(
                self.analysis.program,
                self.analysis.module,
                CompilationProduct.INTERFACE,
                cancel_token=self.analysis.options.cancel_token
            );
        }
    }

    def codegen {
        import from jaclang.compiler.driver.pipeline {
            require_product,
            product_ready,
            CompilationProduct
        }
        if (
            not self.analysis.parse_failed
            and not self.analysis.blocked
            and not self.analysis.options.no_cgen
            and not self.analysis.options.symtab_ir_only
        ) {
            self.analysis.program.options = self.analysis.options;
            if not self.analysis.full_head {
                self.analysis.program.run_schedule(
                    mod=self.analysis.module,
                    passes=get_bootstrap_code_gen(),
                    cancel_token=self.analysis.options.cancel_token
                );
                return;
            }

            import from jaclang.compiler.frontend.module_facts { ModuleFacts }
            needs_native = self.analysis.native
                or ModuleFacts.has_native_context_stmts(self.analysis.module);
            if self.analysis.full_head
                and needs_native
                and not product_ready(
                    self.analysis.program,
                    self.analysis.module,
                    CompilationProduct.ANALYSIS
                ) {
                if not require_product(
                    self.analysis.program,
                    self.analysis.module,
                    CompilationProduct.ANALYSIS,
                    cancel_token=self.analysis.options.cancel_token
                ) {
                    self.analysis.blocked = True;
                    return;
                }
            }
            self.analysis.program.run_schedule(
                mod=self.analysis.module,
                passes=get_py_code_gen(
                    native=needs_native,
                    provided=self.analysis.program.analysis.analyses_run.provided(
                        self.analysis.module
                    )
                )
                    if self.analysis.full_head
                    else get_bootstrap_code_gen(),
                cancel_token=self.analysis.options.cancel_token
            );
            if self.analysis.module.decided_codespace == 'native' {
                _scrubbed = self.scrub_native_artifacts_on_error(
                    self.analysis.program, self.analysis.module
                );
                if self.analysis.options.aot_mode and not _scrubbed {
                    self.report_missing_native_ir(
                        self.analysis.program, self.analysis.module
                    );
                }
            }
        }
    }

    def scrub_native_artifacts_on_error(program: JacProgram, mod: uni.Module) -> bool {
        mod_path = mod.loc.mod_path if mod?.loc else '';
        if not mod_path {
            return False;
        }
        if not program.module_scoped_errors(mod_path) {
            return False;
        }
        gen = mod.gen;
        gen.py_bytecode = None;
        gen.llvm_ir = None;
        gen.native_engine = None;
        gen.native_bitcode = None;
        gen.native_object = None;
        gen.native_iface = None;
        gen.native_layout = None;
        return True;
    }

    def report_missing_native_ir(program: JacProgram, mod: uni.Module) -> None {
        import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
        import from jaclang.compiler.driver.pass_driver { deliver_alerts }
        if mod?.gen is None or mod.gen.llvm_ir is not None {
            return;
        }
        mod_path = mod.loc.mod_path if mod?.loc else '';
        if not mod_path or program.count_module_errors(mod_path) > 0 {
            return;
        }
        import from jaclang.compiler.frontend.diagnostics { E5092 }
        import from jaclang.compiler.frontend.module_facts { ModuleFacts }
        import from jaclang.compiler.passes.context { Alert }
        reason = native_schedule_failure();
        if not reason {
            (_avail, _why) = native_pipeline_available();
            if not _avail {
                reason = _why;
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
        from_pass: any = JcirGenPass;
        try {
            import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
            from_pass = NaIRGenPass;
        } except Exception {}
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
}

obj HostStep {
    has phase: CompilationPhase,
        execute: Callable[[ModuleCompilation], None];
}

def host_steps -> list[HostStep] {
    return [
        HostStep(CompilationPhase.NATIVE_CHECKS, ModuleCompilation.native_checks),
        HostStep(
            CompilationPhase.CLIENT_DEPENDENCIES, ModuleCompilation.client_dependencies
        ),
        HostStep(CompilationPhase.INTERFACE, ModuleCompilation.interface),
        HostStep(CompilationPhase.CODEGEN, ModuleCompilation.codegen)
    ];
}

def module_pipeline -> list[CompilationPhase] {
    return list(ANALYSIS_PHASES) + [step.phase for step in host_steps()];
}

def compile_module(
    compiler: JacCompiler,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> uni.Module {
    analysis = active_host().native_analyze(program, path, options, source);
    if analysis is None {
        analysis = analyze_module(program, path, options, source);
    }
    task = ModuleCompilation(compiler, analysis);
    for step in host_steps() {
        if cancelled(options) {
            break;
        }
        started = time.perf_counter();
        try {
            step.execute(task);
        } finally {
            record_phase(program, step.phase, started);
        }
    }
    return analysis.module;
}

def wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]] {
    import from jaclang.compiler.backends.native.wasm_build {
        _project_gc_settings,
        _assert_ir_rc_free,
        app_declared_imports
    }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    (gc_mode, enf_mods, enf_grand) = _project_gc_settings();
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        before = len(program.errors_had);
        options = CompileOptions(
            aot_mode=True,
            default_codespace='native',
            na_gc_mode=gc_mode,
            memory_enforce=enf_mods,
            memory_exempt=enf_grand,
            native_target="wasm32-unknown-unknown"
        );
        na_coverage_begin();
        try {
            ir = program.compile(file_path=os.path.abspath(file_path), options=options);
        } finally {
            coverage = na_coverage_end();
        }
        if len(program.errors_had) > before {
            first = program.errors_had[before].pretty_print();
            more = len(program.errors_had) - before - 1;
            suffix = f" (+{more} more)" if more > 0 else "";
            raise RuntimeError(f"{first}{suffix}");
        }
        if (ir is None) or (ir.gen.llvm_ir is None) {
            rec = coverage.get(os.path.realpath(os.path.abspath(file_path)));
            reason = "the module did not lower to native IR"
                + " (no demotion recorded; it likely compiled as a"
                + " non-native codespace)";
            if rec {
                code = f" [{rec['code']}]" if rec['code'] else '';
                detail = f": {rec['detail']}" if rec['detail'] else '';
                reason = f"{rec['outcome']}{code}{detail}";
            }
            raise RuntimeError(
                f"native lowering produced no IR for '{file_path}': {reason}"
            );
        }
        import from jaclang.compiler.backends.native.link_plan {
            build_link_plan,
            wasm_program_ir
        }
        plan = build_link_plan(program, [ir.loc.mod_path], options);
        llvm_ir_str = wasm_program_ir(plan);
        app_ir_str = str(ir.gen.llvm_ir);
        app_imports = app_declared_imports(ir, plan);
    } finally {
        pop_native_target(prev);
    }
    if gc_mode == "none" {
        _assert_ir_rc_free(app_ir_str, file_path);
    }
    return (llvm_ir_str, app_imports);
}

def wasm_artifact(program: JacProgram, file_path: str, exports: list[str]) -> bytes {
    import from jaclang.compiler.backends.native.wasm_build { emit_wasm_from_ir }
    (llvm_ir, app_imports) = wasm_ir(program, file_path);
    return emit_wasm_from_ir(llvm_ir, exports, app_imports=app_imports);
}


def native_application(
    program: JacProgram,
    file_path: str,
    target: str = '',
    memory: str = '',
    debug: bool = False,
    no_ir_cache: bool = False
) -> tuple[uni.Module, CompileOptions] {
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    previous = push_native_target(target) if target else None;
    try {
        options = CompileOptions(
            aot_mode=True,
            default_codespace='native',
            memory_profile=memory or None,
            native_target=target or None,
            native_debug=True if debug else None,
            no_ir_cache=debug or no_ir_cache
        );
        module = program.compile(file_path=os.path.abspath(file_path), options=options);
        return (module, options);
    } finally {
        if target {
            pop_native_target(previous);
        }
    }
}

glob CODEGEN_SCHED_DEPS: tuple[str, ...] = (
         'jaclang.compiler.passes.rc_facts_pass',
         'jaclang.compiler.backends.es',
         'jaclang.compiler.passes.freeze_structure_pass'
     ),
     NATIVE_CODEGEN_DEPS: tuple[str, ...] = ('jaclang.compiler.backends.native', ),
     _native_sched_failure: dict[str, str] = {};

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

def _py_codegen_tail -> PassSchedule {
    return [NativeImportFactsPass, JcirGenPass, JcirBytecodeGenPass];
}

def get_bootstrap_code_gen -> PassSchedule {
    return _py_codegen_tail();
}

def get_py_code_gen(
    native: bool = True, provided: (set[AnalysisFact] | None) = None
) -> PassSchedule {
    if _codegen_tier_reason() {
        return _py_codegen_tail();
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        active_host().load_modules(list(CODEGEN_SCHED_DEPS));
        import from jaclang.compiler.backends.es { EsastGenPass }
        import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }

        passes: PassSchedule = [RcFactsPass, EsastGenPass];
        if native {
            active_host().load_modules(list(NATIVE_CODEGEN_DEPS));
            import from jaclang.compiler.backends.native {
                NaIRGenPass,
                NativeCompilePass
            }
            passes.extend([NaIRGenPass, NativeCompilePass]);
            _note_native_schedule_failure(None);
        }
        passes.extend(_py_codegen_tail());
        import from jaclang.compiler.passes.freeze_structure_pass {
            FreezeStructurePass
        }
        passes.append(FreezeStructurePass);
        return validate_schedule(
            passes,
            preprovided=providers_of_product(CompilationProduct.ANALYSIS)
                if provided is None
                else provided,
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

def build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes {
    return wasm_artifact(program, path, exports);
}

def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
    artifact = program._get_compiler().get_client_artifact(
        os.path.realpath(path), program
    );
    if artifact is None {
        return (None, None);
    }
    return (artifact.manifest.page_export, artifact.manifest.layout_export);
}

def compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> uni.Module {
    import copy;
    import from pathlib { Path }
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    import from jaclang.compiler.frontend.unitree { Import, ModulePath }
    import from jaclang.compiler.backends.py.artifact_imports { package_sources }
    import from jaclang.jac0core.ext_registry { is_annex }
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
    entry_module: uni.Module | None = None;
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
        previous = context.options;
        codegen_options = copy.copy(bound);
        codegen_options.skip_native_engine = True;
        try {
            module = program.compile(path, options=codegen_options);
        } finally {
            context.options = previous;
        }
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

def client_product_schedule -> PassSchedule {
    import from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
    return [EsastGenPass];
}

def native_ir_product_schedule -> PassSchedule {
    import from jaclang.compiler.passes.rc_facts_pass { RcFactsPass }
    import from jaclang.compiler.backends.native { NaIRGenPass }
    return [NativeImportFactsPass, RcFactsPass, NaIRGenPass];
}

with entry {
    register_product_schedule(CompilationProduct.CLIENT, client_product_schedule);
    register_product_schedule(CompilationProduct.NATIVE_IR, native_ir_product_schedule);
}

def get_format_sched(auto_lint: bool = False) -> PassSchedule {
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

def get_lint_sched -> PassSchedule {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
}

def run_utility(
    product: UtilityProduct,
    ir: any,
    program: JacProgram,
    cancel_token: (CancelToken | None) = None
) -> any {
    import from jaclang.compiler.driver.pass_driver { run_pass }
    step: type;
    if product == UtilityProduct.PYTHON_AST {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
        step = PyastBuildPass;
    } elif product == UtilityProduct.PYTHON_SYMBOLS {
        step = SymTabBuildPass;
    } elif product == UtilityProduct.GRAMMAR {
        import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
        step = GrammarExtractPass;
    } elif product == UtilityProduct.CFG_DOT {
        import from jaclang.compiler.tools.cfg_dot { CoalesceBBPass }
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
