import os;
import time;
import from jaclang.compiler.driver.pipeline_types { AnalysisFact, CompilationPhase }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.frontend.host { active_host }

obj ModuleAnalysis {
    has program: JacProgram,
        path: str,
        options: CompileOptions,
        source: str | None = None,
        module: uni.Module postinit,
        module_path: str = "",
        parse_failed: bool = False,
        blocked: bool = False,
        full_head: bool = False,
        native: bool = False,
        placement_only: bool = False;

    def postinit {
        self.module = Module.make_stub();
    }

    def parse {
        existing = self.program.mod.hub.get(os.path.realpath(self.path));
        if self.source is None
            and not self.program.internal
            and existing is not None
            and not existing.stub_only
            and not existing.parse_failed
            and self.program.is_hub_entry_fresh(os.path.realpath(self.path))
            and id(existing) in self.program.analysis.completed_passes {
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

    def ir {
        import from jaclang.compiler.driver.pipeline {
            get_symtab_ir_sched,
            get_ir_gen_sched,
            providers_of
        }
        self.module_path = os.path.normpath(self.path);
        blocking_errs_pre_ir = self.program.count_module_blocking_errors(
            self.module_path
        );
        if self.options.symtab_ir_only {
            _head_sched = get_symtab_ir_sched();
        } else {
            _head_sched = get_ir_gen_sched(
                is_internal=self.program.internal, gen_mtir=not self.options.no_cgen
            );
        }

        self.full_head = AnalysisFact.CFG_SUCC in providers_of(_head_sched);
        self.program.run_schedule(
            mod=self.module, passes=_head_sched, cancel_token=self.options.cancel_token
        );

        blocking_errs_post_ir = self.program.count_module_blocking_errors(
            self.module_path
        );
        self.blocked = blocking_errs_post_ir > blocking_errs_pre_ir;
    }

    def placement {
        if not self.options.symtab_ir_only and not self.blocked {
            import from jaclang.compiler.placement.placement_solver {
                solve_program_placement,
                refresh_placement_module
            }
            refresh_placement_module(self.module, self.program);
            solve_program_placement(self.module, self.program);
        }
    }

    def analysis {
        import from jaclang.compiler.driver.pipeline {
            require_product,
            product_ready,
            CompilationProduct
        }
        import from jaclang.compiler.frontend.constant { CodeContext as _CodeCtx }
        self.native = self.module is not None
            and self.module.declares_codespace(_CodeCtx.NATIVE, path_hint=self.path);
        candidate = self.native
            or (
                self.module is not None
                and not self.parse_failed
                and not self.module.gen.placement_mode
                and self.program.infers_native_codespace(self.path)
            );

        if candidate {
            self.options.need_full_ast = True;
        }

        _is_decl_stub = str(self.path).endswith('.pyi')
            or str(self.path).endswith('.py')
            or (self.module is not None and self.module.stub_only)
            or (self.module is not None and self.module.is_raised_from_py);
        host = active_host();
        _annex_of_base = host.path_facts(self.path).is_annex
            and host.base_file(str(self.path)) is not None;
        _unasked = self.options.skip_analysis
            or (self.program.internal and host.import_in_flight(self.path));
        _analyze = self.full_head
            and not _is_decl_stub
            and not _annex_of_base
            and (candidate or not _unasked);
        self.placement_only = _analyze and _unasked and not self.native;

        if _analyze
            and not product_ready(
                self.program, self.module, CompilationProduct.ANALYSIS
            ) {
            if not require_product(
                self.program,
                self.module,
                CompilationProduct.ANALYSIS,
                cancel_token=self.options.cancel_token
            ) {
                self.blocked = True;
            }
        }

        if not self.blocked
            and self.program.count_module_errors(self.module_path) > 0 {
            self.blocked = True;
        }
        self.native = self.module is not None
            and self.module.declares_codespace(_CodeCtx.NATIVE, path_hint=self.path);
    }

    def run_phase(phase: CompilationPhase) {
        if phase == CompilationPhase.PARSE {
            self.parse();
        } elif phase == CompilationPhase.IR {
            self.ir();
        } elif phase == CompilationPhase.PLACEMENT {
            self.placement();
        } elif phase == CompilationPhase.ANALYSIS {
            self.analysis();
        } elif phase == CompilationPhase.BOUNDARIES {
            self.boundaries();
        }
    }

    def boundaries {
        import from jaclang.compiler.driver.pipeline { get_boundary_analysis_sched }
        if (
            not self.parse_failed
            and not self.blocked
            and not self.options.symtab_ir_only
        ) {
            self.program.run_schedule(
                mod=self.module,
                passes=get_boundary_analysis_sched(),
                cancel_token=self.options.cancel_token
            );
        }
    }
}

glob ANALYSIS_PHASES: list[CompilationPhase] = [
         CompilationPhase.PARSE,
         CompilationPhase.IR,
         CompilationPhase.PLACEMENT,
         CompilationPhase.ANALYSIS,
         CompilationPhase.BOUNDARIES
     ];

def record_phase(program: JacProgram, phase: CompilationPhase, started: float) {
    name = phase.name;
    program.analysis.phase_time[name] = (
        program.analysis.phase_time.get(name, 0.0) + time.perf_counter() - started
    );
}

def cancelled(options: CompileOptions) -> bool {
    return options.cancel_token is not None and options.cancel_token.is_set();
}

def run_analysis_phases(
    program: JacProgram, path: str, options: CompileOptions, source: str | None
) -> ModuleAnalysis {
    program.analysis.capability_notes.pop(os.path.realpath(path), None);
    task = ModuleAnalysis(program, path, options, source);
    for phase in ANALYSIS_PHASES {
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
    return task;
}

def keep_hub_order(program: JacProgram, order: list[str]) {
    hub = program.mod.hub;
    held = [key for key in order if key in hub];
    if list(hub.keys())[:len(held)] == held {
        return;
    }
    entries = dict(hub);
    hub.clear();
    for key in held {
        hub[key] = entries.pop(key);
    }
    hub.update(entries);
}

def carry_comptime_deps(judged: (uni.Module | None), placed: (uni.Module | None)) {
    if judged is None or placed is None or judged is placed {
        return;
    }
    for dep in judged.ct_file_deps {
        if dep not in placed.ct_file_deps {
            placed.ct_file_deps.append(dep);
        }
    }
    for dep in judged.ct_body_deps {
        if dep not in placed.ct_body_deps {
            placed.ct_body_deps.append(dep);
        }
    }
    for row in judged.ct_def_deps {
        if row not in placed.ct_def_deps {
            placed.ct_def_deps.append(row);
        }
    }
}

def analyze_module(
    program: JacProgram, path: str, options: CompileOptions, source: str | None = None
) -> ModuleAnalysis {
    import from jaclang.compiler.placement.placement_facts { server_plan }
    errors_mark = len(program.errors_had);
    warnings_mark = len(program.warnings_had);
    task = run_analysis_phases(program, path, options, source);
    plan = task.module.gen.placement_plan
        if task.module is not None and not task.parse_failed
        else "";
    failed = len(program.errors_had) > errors_mark;
    if failed and task.placement_only and not cancelled(options) {
        del program.errors_had[errors_mark:];
        plan = server_plan(task.module);
    } elif not plan or failed or cancelled(options) {
        return task;
    }
    host = active_host();
    host.record_placement_plan(path, plan);
    judged = task.module;
    order = list(program.mod.hub.keys());
    try {
        del program.warnings_had[warnings_mark:];
        program.invalidate_module(os.path.realpath(path));
        task = run_analysis_phases(program, path, options, source);
    } finally {
        host.record_placement_plan(path, "");
    }
    keep_hub_order(program, order);
    carry_comptime_deps(judged, task.module);
    if task.module is not None
        and not task.parse_failed
        and not task.module.gen.placement_mode {
        raise RuntimeError(
            f"the placement plan for {path} was not applied to its second "
            f"analysis ({plan})"
        );
    }
    return task;
}
