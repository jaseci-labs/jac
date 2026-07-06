import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="eject",
    help="Eject a Jac project to a runnable FastAPI + JavaScript app",
    args=[
        Arg.create(
            "source",
            kind=ArgKind.POSITIONAL,
            default=".",
            help="Project directory to eject (default: current directory)"
        ),
        Arg.create(
            "output",
            default="",
            help="Output directory (default: <project>/ejected)",
            short="o"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Overwrite output directory if it already exists",
            short="f"
        ),

    ],
    examples=[
        ("jac eject", "Eject the current project to ./ejected/"),
        ("jac eject . -o /tmp/myapp", "Eject current project to /tmp/myapp"),
        ("jac eject myapp --force", "Eject myapp/, overwriting existing output"),

    ],
    group="project"
)
def eject(source: str = ".", output: str = "", force: bool = False) -> int;
