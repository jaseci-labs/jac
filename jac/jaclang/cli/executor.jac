import from typing { Callable }
import from jaclang.cli.command { CommandSpec, HookContext }

obj ExecutionResult {
    has return_code: int = 0,
        error: Exception | None = None,
        context: HookContext | None = None;
}

obj CommandExecutor {
    def execute(spec: CommandSpec, args: dict[str, any]) -> ExecutionResult;
    def run_pre_hooks(spec: CommandSpec, context: HookContext) -> bool;
    def run_post_hooks(
        spec: CommandSpec, context: HookContext, return_code: int
    ) -> int;

    def run_handler(spec: CommandSpec, args: dict[str, any]) -> int;
}

glob _executor: CommandExecutor | None = None;

def get_executor -> CommandExecutor;
