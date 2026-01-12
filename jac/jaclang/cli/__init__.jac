"""Jac CLI Package.

This package provides the command-line interface for the Jac language.

Main components:
- registry: CommandRegistry for registering and managing commands
- executor: CommandExecutor for executing commands with hook support
- help: HelpFormatter for generating help output
- command: Core types (Arg, ArgKind, CommandSpec, HookContext)
- commands/: Command definitions organized by group

Usage:
    from jaclang.cli.registry import get_registry
    from jaclang.cli.executor import get_executor
    from jaclang.cli.help import get_help_formatter

For the entry point:
    from jaclang.cli.cli import start_cli
"""

# Core types
import from jaclang.cli.command {
    Arg,
    ArgKind,
    CommandSpec,
    CommandPriority,
    HookContext
}

# Registry
import from jaclang.cli.registry { CommandRegistry, get_registry }

# Executor
import from jaclang.cli.executor {
    CommandExecutor,
    ExecutionResult,
    get_executor
}

# Help formatter
import from jaclang.cli.help {
    CommandGroups,
    HelpFormatter,
    get_command_groups,
    get_help_formatter
}

# Entry point
import from jaclang.cli.cli { start_cli }
