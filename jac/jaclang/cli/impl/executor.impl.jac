import sys;
import traceback;
import from jaclang.cli.console { console }

impl CommandExecutor.execute(
    spec: CommandSpec, args: dict[str, any]
) -> ExecutionResult {
    import from jaclang.cli.command { CommandSpec, HookContext }
    import from jaclang.cli.executor { ExecutionResult }

    context = HookContext(command_name=spec.name, args=args.copy(), data={});

    if not self.run_pre_hooks(spec, context) {
        cancel_code = context.get_data("cancel_return_code", 1);
        return ExecutionResult(
            return_code=int(cancel_code), error=None, context=context
        );
    }

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

    final_code = self.run_post_hooks(spec, context, return_code);
    return ExecutionResult(return_code=final_code, error=error, context=context);
}

impl CommandExecutor.run_pre_hooks(spec: CommandSpec, context: HookContext) -> bool {
    import from jaclang.cli.command { CommandSpec, HookContext }
    for (hook, source) in spec.pre_hooks {
        try {
            hook(context);

            if context.get_data("cancel_execution", False) {
                return False;
            }
        } except Exception as e {
            console.warning(f"Pre-hook from '{source}' failed: {e}");

            if context.get_data("cancel_on_hook_error", False) {
                return False;
            }
        }
    }
    return True;
}

impl CommandExecutor.run_post_hooks(
    spec: CommandSpec, context: HookContext, return_code: int
) -> int {
    import from jaclang.cli.command { CommandSpec, HookContext }
    current_code = return_code;
    for (hook, source) in spec.post_hooks {
        try {
            new_code = hook(context, current_code);
            if new_code is not None {
                current_code = new_code;
            }
        } except Exception as e {
            console.warning(f"Post-hook from '{source}' failed: {e}");
        }
    }
    return current_code;
}

impl CommandExecutor.run_handler(spec: CommandSpec, args: dict[str, any]) -> int {
    import inspect;
    import from jaclang.cli.command { CommandSpec }
    if spec.handler is None {
        console.error(f"No handler registered for command '{spec.name}'");
        return 1;
    }

    sig = inspect.signature(spec.handler);
    has_var_keyword = any(
        p.kind == inspect.Parameter.VAR_KEYWORD for p in sig.parameters.values()
    );
    if has_var_keyword {
        filtered_args = args;
    } else {
        filtered_args = {
            k: v
            for (k, v) in args.items()
            if k in sig.parameters
        };
    }
    result = spec.handler(**filtered_args);

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
