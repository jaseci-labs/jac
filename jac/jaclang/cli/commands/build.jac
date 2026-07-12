import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind }

glob registry = get_registry();

@registry.command(
    name="build",
    help="Build a sealed .jab artifact (type-checks first)",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            default="",
            help="Entry .jac file (default: [project] entry-point from jac.toml)"
        ),
        Arg.create(
            "as",
            dest="projection",
            default="jab",
            choices=["jab", "sealed", "binary", "wheel", "npm", "source", "native"],
            help=(
                "What to emit: 'jab' (single-file sealed app bundle, default), "
                "'sealed' (unpacked image dir), 'binary' (self-contained "
                "executable), 'wheel' (PyPI), 'npm' (tarball), 'source' "
                "(ejected FastAPI+JS tree), 'native' (AOT native binary)"
            )
        ),
        Arg.create(
            "output",
            default="dist",
            help="Output directory for the built artifact",
            short="o"
        ),
        Arg.create(
            "no_typecheck",
            typ=bool,
            default=False,
            help="Skip the whole-program type-check gate (escape hatch)"
        ),
        Arg.create(
            "check_only", typ=bool, default=False, help="Run the gate and emit nothing"
        ),
        Arg.create(
            "client",
            typ=str,
            default="",
            help=(
                "Build a client shell instead of the artifact: web, "
                "pwa, mobile, desktop (desktop builds a native "
                "webview app)."
            ),
            choices=["web", "pwa", "mobile"],
            short=""
        ),
        Arg.create(
            "platform",
            typ=str,
            default=None,
            help="Platform for desktop/mobile shells (windows, macos, linux, all, android, ios)",
            choices=["windows", "macos", "linux", "all", "android", "ios"],
            short="p"
        ),

    ],
    examples=[
        ("jac build", "Gate + build a single .jab into dist/"),
        ("jac build --as binary", "Gate + build a self-contained executable"),
        ("jac build --as wheel", "Gate + build a PyPI wheel"),
        ("jac build --check_only", "Run the whole-program gate only"),
        ("jac build --no_typecheck", "Build without the gate (escape hatch)"),
        ("jac build --client mobile", "Build the mobile client shell"),

    ],
    group="build"
)
def build(
    filename: str = "",
    projection: str = "jab",
    output: str = "dist",
    no_typecheck: bool = False,
    check_only: bool = False,
    client: str = "",
    platform: str | None = None
) -> int;
