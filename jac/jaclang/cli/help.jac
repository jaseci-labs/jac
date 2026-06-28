"""Help formatter for CLI commands.

Generates well-formatted help output with:
- Command grouping by category
- Argument documentation with types and defaults
- Example usage
- Plugin attribution for extended arguments
"""

import from jaclang.cli.command { CommandSpec }

"""Groups for organizing commands in help output.

Provides a registry of command groups with display names and ordering
for consistent help menu formatting.
"""
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
    def get_ordered_groups -> list[str];
}

"""Format help output for commands.

Provides methods for formatting:
- Main help with grouped command list
- Individual command help with examples
- Argument lists with plugin attribution
"""
obj HelpFormatter {
    has groups: CommandGroups = CommandGroups();

    def format_main_help(
        commands: list[CommandSpec], prog: str = "jac", version: str | None = None
    ) -> str;
}

# Global singleton instance
glob _formatter: HelpFormatter | None = None;

"""Get the global HelpFormatter instance."""
def get_help_formatter -> HelpFormatter;
