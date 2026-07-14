import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="guide",
    help="Show curated Jac reference guides",
    tier="learn",
    args=[
        Arg.create(
            "topic",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Guide name to display (omit to list every guide)"
        ),
        Arg.create(
            "search", default="", help="List only guides matching a keyword", short="s"
        ),
        Arg.create(
            "export",
            default="",
            help="Export all guides as a Claude Code skills directory at this path",
            short="e"
        ),
        Arg(
            name="json",
            kind=ArgKind.OPTION,
            typ=bool,
            `default=False,
            help="Emit machine-readable JSON (for tools and agents)",
            short="j",
            dest="as_json"
        ),

    ],
    examples=[
        ("jac guide", "List every available guide"),
        ("jac guide jac-types", "Print the jac-types guide"),
        ("jac guide --search walker", "List guides mentioning 'walker'"),
        ("jac guide --json", "List guides as JSON for tooling"),
        ("jac guide --export ~/.claude/skills", "Export guides as Agent Skills"),

    ],
    group="general"
)
def guide(
    topic: str = "", search: str = "", export: str = "", as_json: bool = False
) -> int;
