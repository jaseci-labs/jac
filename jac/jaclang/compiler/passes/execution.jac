import time;

def new_context(
    pass_type: type[CompilerPass],
    module: UniNode,
    prog: (JacProgram | None) = None,
    cancel_token: (CancelToken | None) = None,
    cancel_requested: bool = False,
    policy: (DiagnosticPolicy | None) = None,
    errors_had: (list[Alert] | None) = None,
    warnings_had: (list[Alert] | None) = None
) -> CompileContext;

def walk_pass(walk: CompilerPass) -> CompilerPass;

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
) -> W;

impl run_walker[W: CompilerPass](
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
    ledger = prog.analysis if prog is not None else None;
    outer = ledger.running if ledger is not None else None;
    if ledger is not None {
        ledger.running = ctx;
    }
    walk = walker_type(module=module, ctx=ctx);
    if completed is not None {
        ctx.errors_had.extend(completed.errors_had);
        ctx.warnings_had.extend(completed.warnings_had);
        ctx.time_taken = completed.time_taken;
        return walk;
    }
    walk_pass(walk);
    if ledger is not None {
        ledger.running = outer;
    }
    return walk;
}
