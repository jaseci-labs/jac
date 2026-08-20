import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();


@registry.command(
    name="fix",
    help="Mechanical source migrations. 'jac fix placement' strips removed sv/cl/na placement markers, renames retired .sv.jac/.cl.jac/.na.jac files, preserves service topology as [scale.microservices.routes] entries, and pins any element whose inferred placement differs from its old marker via [placement.pins]",
    args=[
        Arg.create(
            "target",
            kind=ArgKind.POSITIONAL,
            help="Migration to run (currently: placement)"
        ),
        Arg.create(
            "paths",
            kind=ArgKind.MULTI_POSITIONAL,
            `default=["."],
            help="Files or directories to migrate (default: current directory)"
        ),
        Arg.create(
            "dry-run",
            typ=bool,
            `default=False,
            short="",
            help="Report what would change without writing anything"
        ),
        Arg.create(
            "strip-only",
            typ=bool,
            `default=False,
            short="",
            help="Only strip markers and rename files; skip placement verification and jac.toml pin/route recording (for fixture trees)"
        ),

    ],
    examples=[
        ("jac fix placement", "Migrate the current project off sv/cl/na markers"),
        ("jac fix placement src/", "Migrate one directory"),
        ("jac fix placement --dry-run", "Preview the migration"),

    ],
    group="analysis"
)
def fix(
    target: str, paths: list, dry_run: bool = False, strip_only: bool = False
) -> int;
