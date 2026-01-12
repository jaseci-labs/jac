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
    """Execute a command with its hooks.

    Args:
        spec: The command specification
        args: Parsed arguments as a dictionary

    Returns:
        ExecutionResult with return code and any error
    """
    def execute(spec: CommandSpec, args: dict[str, Any]) -> ExecutionResult;

    """Run all pre-execution hooks for a command.

    Args:
        spec: The command specification
        context: The hook context to pass to hooks

    Returns:
        True if all hooks succeeded, False if any hook cancelled execution
    """
    def run_pre_hooks(spec: CommandSpec, context: HookContext) -> bool;

    """Run all post-execution hooks for a command.

    Args:
        spec: The command specification
        context: The hook context to pass to hooks
        return_code: The return code from the handler

    Returns:
        Final return code (hooks may modify it)
    """
    def run_post_hooks(
        spec: CommandSpec, context: HookContext, return_code: int
    ) -> int;

    """Execute the command handler.

    Args:
        spec: The command specification
        args: Arguments to pass to the handler

    Returns:
        Return code from handler (0 for success)
    """
    def run_handler(spec: CommandSpec, args: dict[str, Any]) -> int;
}

# Global singleton instance
glob _executor: CommandExecutor | None = None;

"""Get the global command executor."""
def get_executor -> CommandExecutor;
