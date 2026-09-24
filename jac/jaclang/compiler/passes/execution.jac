import time;
import from jaclang.compiler.frontend.unitree { Module, UniNode }
import from jaclang.compiler.passes.context {
    Alert,
    CompileContext,
    CompilerPass,
    DiagnosticPolicy,
    PassResult
}
import from jaclang.compiler.driver.compile_options { CancelToken }
import type from jaclang.compiler.driver.program { JacProgram }

def new_context(
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

def walk_pass(walk: CompilerPass) -> CompilerPass {
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

def run_walker[W: CompilerPass](
    walker_type: type[W],
    module: Module,
    prog: (JacProgram | None) = None,
    cancel_token: (CancelToken | None) = None,
    cancel_requested: bool = False,
    policy: (DiagnosticPolicy | None) = None,
    errors_had: (list[Alert] | None) = None,
    warnings_had: (list[Alert] | None) = None,
    completed: (PassResult | None) = None
) -> W {
    ctx = new_context(
        walker_type,
        module,
        prog=prog,
        cancel_token=cancel_token,
        cancel_requested=cancel_requested,
        policy=policy,
        errors_had=errors_had,
        warnings_had=warnings_had
    );
    walk = walker_type(module=module, ctx=ctx);
    if completed is not None {
        ctx.errors_had.extend(completed.errors_had);
        ctx.warnings_had.extend(completed.warnings_had);
        ctx.time_taken = completed.time_taken;
        return walk;
    }
    walk_pass(walk);
    return walk;
}
