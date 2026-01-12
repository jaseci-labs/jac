"""Command registry with plugin extension support.

The registry is the central point for command registration and extension.
It supports:
- Registering new commands
- Extending existing commands with additional arguments
- Adding pre/post execution hooks
- Priority-based conflict resolution
"""

import argparse;
import from typing { Any, Callable }
import from jaclang.cli.command {
    Arg,
    ArgKind,
    CommandSpec,
    CommandPriority,
    HookContext
}

"""Central registry for CLI commands with extension support."""
obj CommandRegistry {
    has commands: dict[str, CommandSpec] = {},
        _pending_extensions: dict[str, list[tuple]] = {},
        _finalized: bool = False,
        parser: argparse.ArgumentParser | None = None,
        sub_parsers: Any = None;

    """Initialize the command registry."""
    def init -> None;

    """Register a new command with metadata.

    Use as a decorator:
        @registry.command(
            name="run",
            help="Run a Jac program",
            args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="File to run")],
            group="execution"
        )
        def run_handler(filename: str, **extra) -> int { ... }
    """
    def command(
        name: str,
        help: str,
        args: list[Arg] | None = None,
        examples: list[tuple[str, str]] | None = None,
        group: str = "general",
        priority: CommandPriority = CommandPriority.CORE,
        source: str = "jaclang"
    ) -> Callable[[Callable], Callable];

    """Extend an existing command with additional arguments or hooks.

    Plugin API for adding functionality to core commands:
        registry.extend_command(
            "run",
            args=[Arg.create("profile", help="Enable profiling")],
            pre_hook=setup_profiler,
            post_hook=dump_profile,
            source="jac-profiler"
        )
    """
    def extend_command(
        command_name: str,
        args: list[Arg] | None = None,
        pre_hook: Callable[[HookContext], None] | None = None,
        post_hook: Callable[[HookContext, int], int] | None = None,
        source: str = "unknown"
    ) -> None;

    """Get a command by name."""
    def get(name: str) -> CommandSpec | None;

    """Check if a command exists."""
    def has_command(name: str) -> bool;

    """Get all commands, optionally filtered by group."""
    def get_all(group: str | None = None) -> list[CommandSpec];

    """Get all command group names."""
    def get_groups -> list[str];

    """Finalize the registry and build argparse parser.

    This should be called after all plugins have registered their commands
    and extensions. After finalization, the registry is read-only.
    """
    def finalize -> argparse.ArgumentParser;

    """Apply any pending extensions to a command."""
    def _apply_pending_extensions(name: str) -> None;

    """Build argparse subparser for a command."""
    def _build_subparser(subparsers: Any, spec: CommandSpec) -> argparse.ArgumentParser;

    """Add an argument to an argparse parser."""
    def _add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None;
}

# Global singleton instance
glob _registry: CommandRegistry | None = None;

"""Get the global command registry."""
def get_registry -> CommandRegistry;
