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
