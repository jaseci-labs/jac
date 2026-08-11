import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();


@registry.command(
    name="db",
    help="Manage the project's Postgres store (embedded or external)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="status",
            help="Action: status, serve, stop, inspect, sql"
        ),
        Arg.create(
            "query",
            kind=ArgKind.POSITIONAL,
            default="",
            help="SQL text (for `jac db sql`)"
        ),
        Arg.create(
            "data_dir",
            default="",
            help=(
                "Postgres data directory. Defaults to the project store "
                "(<base>/.jac/data/<name>-pg) or, for `serve`, "
                "JAC_PGDATA / /var/lib/jac/pgdata."
            ),
            short="d"
        ),
        Arg.create(
            "port", typ=int, default=5432, help="TCP port for `serve`", short="p"
        ),

    ],
    examples=[
        ("jac db status", "Show the project store's server state and row counts"),
        ("jac db inspect", "Summarize anchors by kind and archetype"),
        ("jac db sql \"SELECT count(*) FROM anchors\"", "Run one SQL statement"),
        ("jac db serve", "Run Postgres in the foreground (pod / container mode)"),
        ("jac db stop", "Stop the project's embedded server"),

    ],
    group="db"
)
def db(
    action: str = "status", query: str = "", data_dir: str = "", port: int = 5432
) -> int;
