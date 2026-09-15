import time;
import from contextlib { ExitStack }
import from jaclang.compiler.frontend.unitree { UniNode }
import from jaclang.compiler.passes.context {
    Alert,
    CompileContext,
    DiagnosticPolicy,
    PassResult
}

def run_walker(
    walker_type: type[Walker],
    module: UniNode,
    cancel_token: any = None,
    cancel_requested: bool = False,
    policy: DiagnosticPolicy | None = None,
    errors_had: list[Alert] | None = None,
    warnings_had: list[Alert] | None = None,
    completed: PassResult | None = None,
    **kwargs: any
) -> any {
    ctx = CompileContext(
        current_node=module,
        from_pass=walker_type,
        pass_name=walker_type.__name__,
        cancel_token=cancel_token,
        cancel_requested=cancel_requested,
        policy=policy,
        errors_had=errors_had if errors_had is not None else [],
        warnings_had=warnings_had if warnings_had is not None else [],
        resources=ExitStack()
    );
    walk = walker_type(module=module, ctx=ctx, **kwargs);
    if completed is not None {
        ctx.errors_had.extend(completed.errors_had);
        ctx.warnings_had.extend(completed.warnings_had);
        ctx.time_taken = completed.time_taken;
        return walk;
    }
    started = time.perf_counter();
    try {
        with ctx.resources {
            if not ctx.is_canceled() {
                module spawn walk;
            }
        }
    } finally {
        ctx.time_taken = time.perf_counter() - started;
    }
    return walk;
}
