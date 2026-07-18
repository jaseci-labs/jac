import argparse;
import from typing { Callable }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }

obj CommandRegistry {
    has commands: dict[str, CommandSpec] = {},
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
        tier: str = "",
        hidden: bool = False
    ) -> Callable[[Callable], Callable];

    def get(name: str) -> CommandSpec | None;
    def has_command(name: str) -> bool;
    def get_all(
        group: str | None = None, include_hidden: bool = False
    ) -> list[CommandSpec];

    def get_groups -> list[str];
    def finalize -> argparse.ArgumentParser;
    def _build_subparser(
        subparsers: any, spec: CommandSpec
    ) -> argparse.ArgumentParser;

    def _add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None;
}

glob _registry: CommandRegistry | None = None;

def get_registry -> CommandRegistry;

def register_feature_commands -> None;
