impl new_context(
    pass_type: type[CompilerPass],
    module: UniNode,
    prog: (JacProgram | None) = None,
    cancel_token: (CancelToken | None) = None,
    cancel_requested: bool = False,
    policy: (DiagnosticPolicy | None) = None,
    errors_had: (list[Alert] | None) = None,
    warnings_had: (list[Alert] | None) = None
) -> CompileContext {
    return CompileContext(
        current_node=module,
        from_pass=pass_type,
        pass_name=pass_type.__name__,
        cancel_token=cancel_token,
        cancel_requested=cancel_requested,
        policy=policy,
        errors_had=errors_had if errors_had is not None else [],
        warnings_had=warnings_had if warnings_had is not None else [],
        program=prog
    );
}

impl walk_pass(walk: CompilerPass) -> CompilerPass {
    started = time.perf_counter();
    try {
        if not walk.ctx.is_canceled() {
            walk.module spawn walk;
        }
    } finally {
        walk.release();
        walk.ctx.time_taken = time.perf_counter() - started;
    }
    return walk;
}
