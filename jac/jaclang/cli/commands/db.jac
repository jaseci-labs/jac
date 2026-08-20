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
            `default="status",
            help="Action: status, serve, stop, inspect, sql, fetch, list, drop, prune"
        ),
        Arg.create(
            "query",
            kind=ArgKind.POSITIONAL,
            `default="",
            help="SQL text (for `jac db sql`) or database name (for `jac db drop`)"
        ),
        Arg.create(
            "data_dir",
            `default="",
            help=(
                "Postgres data directory. Defaults to the shared embedded "
                "cluster ($JAC_CACHE_HOME/pg/main, i.e. ~/.cache/jac/pg/main) "
                "or, for `serve`, JAC_PGDATA / /var/lib/jac/pgdata."
            ),
            short="d"
        ),
        Arg.create(
            "port", typ=int, `default=5432, help="TCP port for `serve`", short="p"
        ),
        Arg.create(
            "yes",
            typ=bool,
            `default=False,
            help="Actually drop databases; `drop` and `prune` only report without it",
            short="y"
        ),
        Arg.create(
            "empty",
            typ=bool,
            `default=False,
            help=(
                "With `prune`: also drop databases with no recorded owner that "
                "hold no data beyond the system root"
            ),
            short=""
        ),

    ],
    examples=[
        ("jac db status", "Show the project store's server state and row counts"),
        ("jac db inspect", "Summarize anchors by kind and archetype"),
        ("jac db sql \"SELECT count(*) FROM anchors\"", "Run one SQL statement"),
        ("jac db list", "List every jac database in the shared cluster"),
        ("jac db prune", "Report databases whose project is gone (drops nothing)"),
        ("jac db prune -y", "Drop them"),
        ("jac db drop jac_app_1a2b3c4d -y", "Drop one database by name"),
        ("jac db serve", "Run Postgres in the foreground (pod / container mode)"),
        ("jac db stop", "Stop the shared embedded server"),
        (
            "jac db fetch",
            "Pre-download the embedded Postgres distribution (air-gapped / image builds)"
        ),

    ],
    group="db"
)
def db(
    action: str = "status",
    query: str = "",
    data_dir: str = "",
    port: int = 5432,
    yes: bool = False,
    empty: bool = False
) -> int;
