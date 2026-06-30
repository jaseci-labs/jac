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
        ],
        tier_sections: dict[str, str] = {
            "core": "Common commands",
            "learn": "Learn & build with AI"
        },
        tier_order: list[str] = ["core", "learn"];

    def get_display_name(group: str) -> str;
    def get_ordered_groups -> list[str];
}

obj HelpFormatter {
    has groups: CommandGroups = CommandGroups();

    def format_main_help(
        commands: list[CommandSpec],
        prog: str = "jac",
        version: str | None = None,
        verbose: bool = False
    ) -> str;

    def format_curated_help(commands: list[CommandSpec], prog: str = "jac") -> str;
}

glob _groups: CommandGroups | None = None,
     _formatter: HelpFormatter | None = None;

def get_command_groups -> CommandGroups;

def get_help_formatter -> HelpFormatter;
