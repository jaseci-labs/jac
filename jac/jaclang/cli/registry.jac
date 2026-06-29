import argparse;
import from typing { Callable }
import from jaclang.cli.command {
    Arg,
    ArgKind,
    CommandSpec,
    CommandPriority,
    HookContext
}

obj CommandRegistry {
    has commands: dict[str, CommandSpec] = {},
        _pending_extensions: dict[str, list[tuple]] = {},
        _finalized: bool = False,
        parser: argparse.ArgumentParser | None = None,
        sub_parsers: any = None;

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
    def _build_subparser(
        subparsers: any, spec: CommandSpec
    ) -> argparse.ArgumentParser;

    def _add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None;
}

glob _registry: CommandRegistry | None = None;

def get_registry -> CommandRegistry;
