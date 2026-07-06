import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();


@registry.command(
    name="db",
    help="Inspect, rescue, and manage Jac persistence databases",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="inspect",
            help="Action: inspect, fsck, quarantine, alias, recover, recover-all, schema"
        ),
        Arg.create(
            "sub",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Sub-action (for alias/quarantine) or row id (for recover)"
        ),
        Arg.create(
            "arg1",
            kind=ArgKind.POSITIONAL,
            default="",
            help="First argument (alias old_name, row id, etc.)"
        ),
        Arg.create(
            "arg2",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Second argument (alias new_name, etc.)"
        ),
        Arg.create(
            "limit", typ=int, default=50, help="Row limit for list commands", short="n"
        ),
        Arg.create(
            "app",
            default="",
            help=(
                "Path to the .jac app file to import before dispatching. "
                "If omitted, the single .jac file in the current directory "
                "is used. The app must be importable so user-defined "
                "archetypes (and any @archetype_alias decorators) register "
                "before the command touches the backend."
            ),
            short="a"
        ),

    ],
    examples=[
        ("jac db inspect", "Summarize the DB for the .jac in cwd"),
        ("jac db inspect --app path/to/app.jac", "Summarize a specific app's DB"),
        ("jac db fsck", "Scan for dangling refs / orphans (read-only)"),
        ("jac db fsck repair", "Heal dangling refs and collect orphans"),
        ("jac db quarantine list", "List quarantined anchors"),
        ("jac db quarantine show <row-id>", "Show one quarantined row in full"),
        ("jac db alias list", "List DB-resident aliases"),
        ("jac db alias add old.mod.OldName new.mod.NewName", "Register a rescue alias"),
        ("jac db alias remove old.mod.OldName", "Remove a rescue alias"),
        ("jac db recover <row-id>", "Try to un-quarantine one row"),
        ("jac db recover-all", "Try to un-quarantine every row; report counts"),
        ("jac db schema rules", "List registered __jac_schema__ drift rules"),

    ],
    group="db"
)
def db(
    action: str = "inspect",
    sub: str = "",
    arg1: str = "",
    arg2: str = "",
    limit: int = 50,
    app: str = ""
) -> int;
