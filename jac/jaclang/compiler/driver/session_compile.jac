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

    def assemble_python(program: JacProgram, module: uni.Module) {}
    def assemble_native(program: JacProgram, module: uni.Module, checking: bool) {}
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module abst;
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
    try {
        return hooks.compile_attempt(file_path, program, use_str, options);
    } except Exception as err {
        hooks.check_crash(err, file_path);
        raise;
    }
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

def drop_native_bindings(mod: uni.Module, resolved: str) {
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
