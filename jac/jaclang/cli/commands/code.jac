import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="code",
    help="Query code structure via the compiler (grep's structural successor)",
    args=[
        Arg.create(
            "action",
            kind=ArgKind.POSITIONAL,
            default="",
            help="symbol | uses | map | walkers | slice | diag"
        ),
        Arg.create(
            "target",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Symbol name, node type, archetype-kind filter, or file path"
        ),
        Arg.create(
            "text",
            kind=ArgKind.FLAG,
            typ=bool,
            default=False,
            help="Human-readable text instead of the default JSON"
        ),
        Arg.create(
            "depth",
            typ=int,
            default=1,
            help="Type-dependency depth for `slice` (default 1)",
            short="d"
        ),

    ],
    examples=[
        ("jac code symbol User", "Definition(s) of a symbol plus where it is used"),
        ("jac code uses make_user", "Every read/write of a symbol, def/use-precise"),
        ("jac code map", "Structural overview: nodes, walkers, edges, objs"),
        ("jac code map walker", "Only walker archetypes"),
        ("jac code walkers User", "Walkers whose entry points traverse a node type"),
        ("jac code slice Profile --depth 2", "Typed neighbourhood for prompt assembly"),
        ("jac code diag", "Structured compiler errors and warnings"),
        ("jac code symbol User --text", "Same query, human-readable output"),

    ],
    group="analysis"
)
def code(
    action: str = "", target: str = "", text: bool = False, depth: int = 1
) -> int;
