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

obj AttemptCrash {
    has kind: str,
        text: str;
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
        if not active_host().native_session_active(program) {
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

def demotes_native_failure(
    mark: AttemptMark,
    file_path: str,
    options: CompileOptions,
    mod: (uni.Module | None),
    crashed: bool
) -> bool {
    program = mark.program;
    probe = mod
        if mod is not None
        else program.mod.hub.get(os.path.realpath(file_path));
    inferred_native = not options.aot_mode
        and not options.force_codespace
        and probe is not None
        and probe.decided_codespace == 'native';
    return inferred_native and (crashed or len(program.errors_had) > mark.errors);
}

def ice_raise_requested(mark: AttemptMark) -> bool {
    return len(mark.program.errors_had) == mark.errors
        and bool(os.environ.get('JAC_NATIVE_ICE_RAISE'));
}

def demote_native_failure(
    mark: AttemptMark, file_path: str, crash: (AttemptCrash | None)
) {
    program = mark.program;
    resolved = os.path.realpath(file_path);
    is_ice = crash is not None and len(program.errors_had) == mark.errors;
    alerts = program.errors_had[mark.errors:];
    crash_text = crash.text if crash is not None else "";
    crash_kind = crash.kind if crash is not None else "";
    first_err = alerts[0].pretty_print().split('\n')[0] if alerts else crash_text;
    code = alerts[0].code.code
        if (alerts and alerts[0].code is not None)
        else crash_kind;
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
        for stale in invalidate_importers_es(program, resolved) {
            drop_demoted_native_bindings(stale, resolved);
        }
    } except Exception as reset_exc {
        import logging;
        logging.getLogger(__name__).warning(
            f"native demotion of {resolved} could not reset its importers "
            f"({reset_exc}); stale client bindings may persist until a rebuild."
        );
    }
    (note, style) = na_demotion_note(file_path, first_err, is_ice);
    host.note(note, style);
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
    crash: (AttemptCrash | None) = None;
    try {
        mod = hooks.compile_attempt(file_path, program, use_str, options);
    } except Exception as err {
        hooks.check_crash(err, file_path);
        if not demotes_native_failure(mark, file_path, options, None, True)
            or ice_raise_requested(mark) {
            raise;
        }
        crash = AttemptCrash(
            kind=type(err).__name__, text=f"{type(err).__name__}: {err}"
        );
    }
    if crash is None and mod is not None {
        if not demotes_native_failure(mark, file_path, options, mod, False) {
            return mod;
        }
    }
    demote_native_failure(mark, file_path, crash);
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

def na_demotion_note(
    file_path: str, first_err: str, is_ice: bool
) -> tuple[(str, str)] {
    if is_ice {
        msg = (
            f"warning: {file_path} hit an internal compiler error during "
            + "native lowering and fell back to the server codespace "
            + f"({first_err}); this is a compiler bug -- please report it. "
            + "Set JAC_NATIVE_ICE_RAISE=1 to surface the full traceback."
        );
        return (msg, "yellow");
    }
    msg = (
        f"note: {file_path} preferred native but did not lower; "
        + f"compiled in the server codespace ({first_err})"
    );
    return (msg, "dim");
}

def drop_demoted_native_bindings(mod: uni.Module, resolved: str) {
    import from jaclang.compiler.frontend.codeinfo { InteropContext, InteropManifest }
    key = os.path.realpath(resolved);
    manifest = mod.gen.interop_manifest;
    if not isinstance(manifest, InteropManifest) or not manifest.bindings {
        return;
    }
    stale = [
        name
        for (name, b) in manifest.bindings.items()
        if (
            b.source_context == InteropContext.NATIVE
            and b.source_module
            and os.path.realpath(b.source_module) == key
        )
    ];
    for name in stale {
        manifest.bindings.pop(name, None);
    }
}
