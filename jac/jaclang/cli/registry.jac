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

    def init -> None;
    def command(
        name: str,
        help: str,
        args: list[Arg] | None = None,
        examples: list[tuple[str, str]] | None = None,
        group: str = "general",
        priority: CommandPriority = CommandPriority.CORE,
        source: str = "jaclang"
    ) -> Callable[[Callable], Callable];

    def extend_command(
        command_name: str,
        args: list[Arg] | None = None,
        pre_hook: Callable[[HookContext], None] | None = None,
        post_hook: Callable[[HookContext, int], int] | None = None,
        source: str = "unknown"
    ) -> None;

    def get(name: str) -> CommandSpec | None;
    def has_command(name: str) -> bool;
    def get_all(group: str | None = None) -> list[CommandSpec];
    def get_groups -> list[str];
    def finalize -> argparse.ArgumentParser;
    def _apply_pending_extensions(name: str) -> None;
    def _build_subparser(subparsers: Any, spec: CommandSpec) -> argparse.ArgumentParser;
    def _add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None;
}

# Global singleton instance
glob _registry: CommandRegistry | None = None;

"""Get the global command registry."""
def get_registry -> CommandRegistry;
