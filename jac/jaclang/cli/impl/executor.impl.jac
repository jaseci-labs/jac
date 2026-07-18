import sys;
import traceback;
import from jaclang.cli.console { console }

impl CommandExecutor.execute(
    spec: CommandSpec, args: dict[str, any]
) -> ExecutionResult {
    import from jaclang.cli.command { CommandSpec }
    import from jaclang.cli.executor { ExecutionResult }

    return_code = 0;
    error: Exception | None = None;
    try {
        return_code = self.run_handler(spec, args);
    } except Exception as e {
        error = e;
        return_code = 1;

        console.error(f"Error executing '{spec.name}': {e}");
        if sys?.exc_info() {
            traceback.print_exc();
        }
    }

    return ExecutionResult(return_code=return_code, error=error);
}

impl CommandExecutor.run_handler(spec: CommandSpec, args: dict[str, any]) -> int {
    import from jaclang.cli.command { CommandSpec }
    import from jaclang.cli.command_dispatch { dispatch_command }

    rc = dispatch_command(spec.name, args);
    if rc is None {
        console.error(f"No handler registered for command '{spec.name}'");
        return 1;
    }
    return rc;
}

impl get_executor -> CommandExecutor {
    import from jaclang.cli.executor { CommandExecutor }
    if _executor is None {
        _executor = CommandExecutor();
    }
    return _executor;
}
