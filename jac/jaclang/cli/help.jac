"""Help formatter for CLI commands.

Generates well-formatted help output with:
- Command grouping by category
- Argument documentation with types and defaults
- Example usage
- Plugin attribution for extended arguments
"""

import from typing { Any }
import from jaclang.cli.command { CommandSpec, Arg }

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

    """Get display name for a group."""
    def get_display_name(group: str) -> str;

    """Get group order for sorting (lower = earlier)."""
    def get_order(group: str) -> int;

    """Register a new group (for plugins)."""
    def register_group(name: str, display_name: str, order: int | None = None) -> None;

    """Get all groups in display order."""
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

    """Format the main help message with grouped commands."""
    def format_main_help(
        commands: list[CommandSpec], prog: str = "jac", version: str | None = None
    ) -> str;

    """Format help for a single command."""
    def format_command_help(spec: CommandSpec) -> str;

    """Format argument list for a command."""
    def format_arguments(args: list[Arg], extra_args: list[Arg] | None = None) -> str;

    """Format examples for a command."""
    def format_examples(examples: list[tuple[str, str]]) -> str;

    """Format a usage line for a command."""
    def format_usage(spec: CommandSpec, prog: str = "jac") -> str;
}

# Global singleton instance
glob _groups: CommandGroups | None = None,
     _formatter: HelpFormatter | None = None;

"""Get the global CommandGroups instance."""
def get_command_groups -> CommandGroups;

"""Get the global HelpFormatter instance."""
def get_help_formatter -> HelpFormatter;
