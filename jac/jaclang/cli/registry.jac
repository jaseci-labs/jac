import from jaclang.cli.command { Arg, CommandSpec }

obj CommandRegistry {
    has commands: dict[str, CommandSpec] = {};

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
}

glob _registry: CommandRegistry | None = None;

def get_registry -> CommandRegistry;
