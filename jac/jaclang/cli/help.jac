import from jaclang.cli.command { CommandSpec, Arg }


obj CommandGroups {
    has groups: dict[str, str] = {
        "execution": "Program Execution",
        "analysis": "Code Analysis",
        "transform": "Code Transformation",
        "project": "Project Management",
        "tools": "Development Tools",
        "config": "Configuration",
        "general": "General"
    },
        group_order: list[str] = [
            "execution",
            "analysis",
            "transform",
            "project",
            "tools",
            "config",
            "general"
        ];

    def get_display_name(group: str) -> str;
    def get_order(group: str) -> int;
    def register_group(name: str, display_name: str, order: int | None = None) -> None;
    def get_ordered_groups -> list[str];
}


obj HelpFormatter {
    has groups: CommandGroups = CommandGroups();

    def format_main_help(
        commands: list[CommandSpec], prog: str = "jac", version: str | None = None
    ) -> str;

    def format_command_help(spec: CommandSpec) -> str;
    def format_arguments(args: list[Arg], extra_args: list[Arg] | None = None) -> str;
    def format_examples(examples: list[tuple[str, str]]) -> str;
    def format_usage(spec: CommandSpec, prog: str = "jac") -> str;
}

glob _groups: CommandGroups | None = None,
     _formatter: HelpFormatter | None = None;

def get_command_groups -> CommandGroups;

def get_help_formatter -> HelpFormatter;
