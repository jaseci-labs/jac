"""Command executor with hook support.

The executor runs commands and manages:
- Pre-execution hooks from plugins
- Post-execution hooks from plugins
- Error handling and return codes
- Hook context passing between hooks and handlers
"""

import from typing { Any, Callable }
import from jaclang.cli.command { CommandSpec, HookContext }

"""Result from executing a command."""
obj ExecutionResult {
    has return_code: int = 0,
        error: Exception | None = None,
        context: HookContext | None = None;
}

"""Executor for running CLI commands with plugin hook support.

Handles the full command lifecycle:
1. Create hook context with parsed arguments
2. Run all pre-execution hooks in order
3. Execute the command handler
4. Run all post-execution hooks in order
5. Return final exit code
"""
obj CommandExecutor {
    def execute(spec: CommandSpec, args: dict[str, Any]) -> ExecutionResult;
    def run_pre_hooks(spec: CommandSpec, context: HookContext) -> bool;
    def run_post_hooks(
        spec: CommandSpec, context: HookContext, return_code: int
    ) -> int;

    def run_handler(spec: CommandSpec, args: dict[str, Any]) -> int;
}

# Global singleton instance
glob _executor: CommandExecutor | None = None;

"""Get the global command executor."""
def get_executor -> CommandExecutor;
