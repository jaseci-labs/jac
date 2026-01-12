"""Core types for CLI command definitions.

This module provides the foundational types for declaring CLI commands
with structured metadata that enables auto-documentation and plugin extension.
"""

import from typing { Any, Callable }

"""Kind of command-line argument."""
enum ArgKind {
    POSITIONAL = 1,  # jac run <filename>
    OPTION = 2,  # jac run --session foo
    FLAG = 3,  # jac run --verbose (bool, no value)
    MULTI = 4,  # jac check file1.jac file2.jac
    REMAINDER = 5,  # jac enter main args...
}

"""Priority levels for command registration."""
enum CommandPriority {
    CORE = 100,  # Built-in commands
    PLUGIN = 200,  # Plugin-provided commands
    USER = 300,  # User-defined commands (highest priority)
}

"""Definition of a command-line argument with full metadata.

Provides structured argument definitions that enable:
- Auto-generated help documentation
- Type-safe argument parsing
- Plugin argument extension
"""
obj Arg {
    has name: str,  # Parameter name
        kind: ArgKind = ArgKind.OPTION,  # Argument kind
        typ: Any = str,  # Python type for conversion
        default: Any = None,  # Default value
        help: str = "",  # Help text for this argument
        short: str | None = None,  # Short flag, e.g., "-s" for "--session"
        choices: list[Any] | None = None,  # Valid choices
        required: bool = False,  # Whether argument is required
        dest: str | None = None,  # Override destination variable name
        metavar: str | None = None,  # Display name in help
        source: str = "jaclang";  # Source plugin that added this arg

    """Create argument with auto-generated short flag."""
    static def create(
        name: str,
        kind: ArgKind = ArgKind.OPTION,
        typ: Any = str,
        default: Any = None,
        help: str = "",
        short: str | None = None,
        choices: list[Any] | None = None,
        required: bool = False,
        metavar: str | None = None
    ) -> Arg;
}

"""Complete specification for a CLI command.

Contains all metadata needed to:
- Generate help documentation
- Build argparse configuration
- Execute the command with hooks
"""
obj CommandSpec {
    has name: str,  # Command name
        help: str,  # One-line description
        description: str = "",  # Detailed description (multi-line)
        args: list[Arg] = [],  # Base arguments
        examples: list[tuple[str, str]] = [],  # (command, description) pairs
        group: str = "general",  # Command group for help menu
        priority: CommandPriority = CommandPriority.CORE,
        source: str = "jaclang",  # Source package/plugin
        handler: Callable | None = None,  # Implementation function
        # Plugin extensions (populated at runtime)
        extra_args: list[Arg] = [],  # Arguments added by plugins
        pre_hooks: list[tuple[Callable, str]] = [],  # (hook, source) pairs
        post_hooks: list[tuple[Callable, str]] = [];  # (hook, source) pairs

    """Get all arguments (base + plugin-extended)."""
    def get_all_args -> list[Arg];

    """Add an extension argument from a plugin."""
    def add_extension_arg(arg: Arg, source: str) -> None;

    """Add a pre-execution hook from a plugin."""
    def add_pre_hook(hook: Callable, source: str) -> None;

    """Add a post-execution hook from a plugin."""
    def add_post_hook(hook: Callable, source: str) -> None;
}

"""Hook context passed to pre/post hooks.

Provides a mutable context for:
- Accessing command arguments
- Passing data between pre and post hooks
- Storing plugin-specific state
"""
obj HookContext {
    has command_name: str,  # Name of the command being executed
        args: dict[str, Any],  # Parsed command arguments
        data: dict[str, Any] = {};  # Mutable context for hook communication

    """Get an argument value with optional default."""
    def get_arg(name: str, default: Any = None) -> Any;

    """Set a value in the hook data context."""
    def set_data(key: str, value: Any) -> None;

    """Get a value from the hook data context."""
    def get_data(key: str, default: Any = None) -> Any;
}
