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
        if sys?.exc_info {
            traceback.print_exc();
        }
    }

    return ExecutionResult(return_code=return_code, error=error);
}

impl CommandExecutor.run_handler(spec: CommandSpec, args: dict[str, any]) -> int {
    import from jaclang.cli.command { CommandSpec }
    import from jaclang.cli.command_dispatch { dispatch_command }

    (handled, result) = dispatch_command(spec.name, args);
    if not handled {
        console.error(f"No handler registered for command '{spec.name}'");
        return 1;
    }

    if result is None {
        return 0;
    } elif isinstance(result, int) {
        return result;
    } elif isinstance(result, bool) {
        return 0 if result else 1;
    } else {
        return 0;
    }
}

impl get_executor -> CommandExecutor {
    import from jaclang.cli.executor { CommandExecutor }
    global _executor;
    if _executor is None {
        _executor = CommandExecutor();
    }
    return _executor;
}
