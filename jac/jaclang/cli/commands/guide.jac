import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="guide",
    help="Show bundled Jac guides and documentation",
    tier="learn",
    args=[
        Arg.create(
            "topic",
            kind=ArgKind.POSITIONAL,
            default="",
            help=(
                "Guide or doc to print, or a doc set (reference, quick-guide, "
                "tutorials, internals, community) to list; omit to show the "
                "full index"
            )
        ),
        Arg.create(
            "search",
            default="",
            help="Grep every bundled guide and doc (name:line: hits)",
            short="s"
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
        ("jac guide", "List every bundled guide and doc set"),
        ("jac guide jac-types", "Print the jac-types guide"),
        ("jac guide reference/diagnostics", "Print the bundled diagnostics reference"),
        ("jac guide reference", "List every doc in the reference set"),
        ("jac guide --search 'breaking changes'", "Grep all bundled content"),
        ("jac guide --json", "Full guide/doc index as JSON for tooling"),
        ("jac guide --export ~/.claude/skills", "Export guides as Agent Skills"),

    ],
    group="general"
)
def guide(
    topic: str = "", search: str = "", export: str = "", as_json: bool = False
) -> int;
