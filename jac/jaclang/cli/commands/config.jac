"""Config commands: config, plugins.

Commands for managing Jac configuration and plugins.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Manage Jac configuration."""
@registry.command(
    name="config",
    help="Manage Jac configuration",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="show",
            help="Action: show, get, set, reset, list"
        ),
        Arg.create(
            "key", kind=ArgKind.POSITIONAL, default="", help="Configuration key"
        ),
        Arg.create("value", kind=ArgKind.POSITIONAL, default="", help="Value to set"),
        Arg.create("group", default="", help="Config group filter", short="g"),
        Arg.create(
            "output",
            default="table",
            help="Output format: table, json, toml",
            short="o"
        ),

    ],
    examples=[
        ("jac config show", "Show all configuration"),
        ("jac config get run.cache", "Get specific setting"),
        ("jac config set run.cache false", "Set a value"),
        ("jac config reset run.cache", "Reset to default"),
        ("jac config list", "List available settings"),
        ("jac config show --group run", "Show settings in a group"),

    ],
    group="config"
)
def config(
    action: str = "show",
    key: str = "",
    value: str = "",
    group: str = "",
    output: str = "table"
) -> int;

"""Manage Jac plugins."""
@registry.command(
    name="plugins",
    help="Manage Jac plugins",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="list",
            help="Action: list, info, enable, disable"
        ),
        Arg.create("names", kind=ArgKind.MULTI, default=[], help="Plugin names"),
        Arg.create(
            "verbose", typ=bool, default=False, help="Verbose output", short="v"
        ),

    ],
    examples=[
        ("jac plugins", "List installed plugins"),
        ("jac plugins list --verbose", "Detailed plugin list"),
        ("jac plugins info jac-client", "Show plugin details"),

    ],
    group="config"
)
def plugins(action: str = "list", names: list = [], verbose: bool = False) -> int;
