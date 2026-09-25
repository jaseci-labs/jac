import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host { active_host }

obj SessionContext {
    has caller: JacProgram,
        target: JacProgram,
        options: CompileOptions,
        errors_mark: int = 0,
        warnings_mark: int = 0;

    def merge_alerts {
        if self.target is self.caller or self.target.internal {
            return;
        }
        self.caller.errors_had.extend(self.target.errors_had[self.errors_mark:]);
        self.caller.warnings_had.extend(self.target.warnings_had[self.warnings_mark:]);
    }
}

obj CompileFrame {
    has nested: bool = False;
}

obj AttemptMark {
    has program: JacProgram,
        errors: int = 0,
        warnings: int = 0;
}

obj SessionHooks {
    def enter_compile(ctx: SessionContext) -> CompileFrame {
        return CompileFrame(nested=True);
    }

    def leave_compile(ctx: SessionContext, frame: CompileFrame) {}
    def finish_compile(frame: CompileFrame) {}
    def check_crash(crash: Exception, file_path: str) {}
    def closure_options -> (CompileOptions | None) {
        return None;
    }

    def compile(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        return compile_in_session(self, file_path, target_program, use_str, options);
    }

    def compile_attempt(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        return compile_once(self, file_path, target_program, use_str, options);
    }

    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module {
        raise NotImplementedError("a compile session needs a module runner");
    }
}

def select_context(
    file_path: str, program: JacProgram, options: CompileOptions
) -> SessionContext {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    target = program;
    if not program.internal {
        options = bind_options(file_path, program, options);
        if program._natives is None or program._natives.session is None {
            target = context_program(program, options);
        }
    }
    return SessionContext(
        caller=program,
        target=target,
        options=options,
        errors_mark=len(target.errors_had),
        warnings_mark=len(target.warnings_had)
    );
}

def annex_parent(
    file_path: str, program: JacProgram, use_str: (str | None), options: CompileOptions
) -> (str | None) {
    if use_str is not None or not options.resolve_annex_parent {
        return None;
    }
    host = active_host();
    if not host.path_facts(file_path).is_annex {
        return None;
    }
    base_path = host.base_file(file_path);
    if base_path and base_path not in program.mod.hub {
        return base_path;
    }
    return None;
}

def inherit_session_options(
    program: JacProgram, options: CompileOptions, closure: (CompileOptions | None)
) -> CompileOptions {
    previous = program.options;
    if previous is not None
        and not (options.nogc_enforce_all or options.memory_enforce) {
        options.nogc_enforce_all = previous.nogc_enforce_all;
        options.memory_enforce = previous.memory_enforce;
        options.memory_exempt = previous.memory_exempt;
    }
    if previous is not None and not options.default_codespace {
        options.default_codespace = previous.default_codespace;
    }
    if closure is not None and closure is not options and closure.need_full_ast {
        options.need_full_ast = True;
    }
    program.options = options;
    if options.default_codespace {
        import from jaclang.compiler.frontend.codeinfo {
            set_effective_default_codespace
        }
        set_effective_default_codespace(options.default_codespace);
    }
    return options;
}

def mark_attempt(program: JacProgram) -> AttemptMark {
    return AttemptMark(
        program=program,
        errors=len(program.errors_had),
        warnings=len(program.warnings_had)
    );
}

def demote_native_failure(
    mark: AttemptMark,
    file_path: str,
    options: CompileOptions,
    mod: (uni.Module | None),
    crash: (Exception | None)
) -> bool {
    program = mark.program;
    resolved = os.path.realpath(file_path);
    probe = mod if mod is not None else program.mod.hub.get(resolved);
    inferred_native = not options.aot_mode
        and not options.force_codespace
        and probe is not None
        and probe.decided_codespace == 'native';
    failed = crash is not None or len(program.errors_had) > mark.errors;
    if not (inferred_native and failed) {
        return False;
    }
    is_ice = crash is not None and len(program.errors_had) == mark.errors;
    if is_ice and crash is not None and os.environ.get('JAC_NATIVE_ICE_RAISE') {
        raise crash;
    }
    alerts = program.errors_had[mark.errors:];
    first_err = (
        alerts[0].pretty_print().split('\n')[0]
            if alerts
            else f"{type(crash).__name__}: {crash}"
    );
    code = (
        alerts[0].code.code
            if (alerts and alerts[0].code is not None)
            else type(crash).__name__
    );
    host = active_host();
    host.record_native_coverage(
        resolved, 'ice' if is_ice else 'demoted', code, first_err
    );
    host.record_native_verdict(program, resolved, code, first_err);
    del program.errors_had[mark.errors:];
    del program.warnings_had[mark.warnings:];
    try {
        program.invalidate_module(resolved);
    } except Exception {}
    try {
        import from jaclang.compiler.placement.placement_solver {
            invalidate_importers_es
        }
        import from jaclang.compiler.driver.na_coverage {
            _drop_demoted_native_bindings
        }
        for stale in invalidate_importers_es(program, resolved) {
            _drop_demoted_native_bindings(stale, resolved);
        }
    } except Exception as reset_exc {
        import logging;
        logging.getLogger(__name__).warning(
            f"native demotion of {resolved} could not reset its importers "
            f"({reset_exc}); stale client bindings may persist until a rebuild."
        );
    }
    import from jaclang.compiler.driver.na_coverage { na_demotion_note }
    (note, style) = na_demotion_note(file_path, first_err, is_ice);
    host.note(note, style);
    return True;
}

def compile_in_session(
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module {
    import from jaclang.compiler.driver.compilation_context {
        compilation_scope,
        owner_scope_options
    }
    import from jaclang.compiler.driver.pass_driver { compile_progress }
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        reset_native_unit_compile,
        set_effective_default_codespace,
        set_native_unit_compile
    }
    ctx = select_context(file_path, program, options);
    target = ctx.target;
    with compilation_scope(owner_scope_options(target, ctx.options)) {
        with compile_progress.track(str(file_path)) {
            frame = hooks.enter_compile(ctx);
            previous_codespace = get_effective_default_codespace_override();
            native_token = set_native_unit_compile(bool(ctx.options.native_unit));
            outer_options: (CompileOptions | None) = None;
            entered = False;
            try {
                target.scratch.compile_depth += 1;
                entered = True;
                if frame.nested {
                    outer_options = target.options;
                }
                return compile_attempts(hooks, file_path, target, use_str, ctx.options);
            } finally {
                ctx.merge_alerts();
                reset_native_unit_compile(native_token);
                set_effective_default_codespace(previous_codespace);
                hooks.leave_compile(ctx, frame);
                if outer_options is not None {
                    target.options = outer_options;
                }
                if entered {
                    target.scratch.compile_depth -= 1;
                    if target.scratch.compile_depth <= 0 {
                        target.scratch.compile_depth = 0;
                        try {
                            target.release_check_caches();
                        } except Exception {}
                    }
                }
                hooks.finish_compile(frame);
            }
        }
    }
}

def compile_attempts(
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module {
    mark = mark_attempt(program);
    mod: (uni.Module | None) = None;
    crash: (Exception | None) = None;
    try {
        mod = hooks.compile_attempt(file_path, program, use_str, options);
    } except Exception as err {
        crash = err;
    }
    if crash is not None {
        hooks.check_crash(crash, file_path);
    }
    if not demote_native_failure(mark, file_path, options, mod, crash) {
        if crash is not None {
            raise crash;
        }
        assert mod is not None;
        return mod;
    }
    return hooks.compile_attempt(file_path, program, use_str, options);
}

def compile_once(
    hooks: SessionHooks,
    file_path: str,
    program: JacProgram,
    use_str: (str | None),
    options: CompileOptions
) -> uni.Module {
    if use_str is not None and not options.no_ir_cache {
        import copy;
        options = copy.copy(options);
        options.no_ir_cache = True;
    }
    parent = annex_parent(file_path, program, use_str, options);
    if parent is not None {
        return hooks.compile(parent, program, None, options);
    }
    options = inherit_session_options(program, options, hooks.closure_options());
    return hooks.run_module(file_path, program, use_str, options);
}
