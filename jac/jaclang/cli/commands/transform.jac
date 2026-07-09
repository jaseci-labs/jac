import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

def py2jac(filename: str) -> int;

def jac2py(filename: str) -> int;

def jac2js(filename: str) -> int;

@registry.command(
    name="c2jac",
    help="Convert C code to Jac (writes Jac to stdout, sidecar report to <file>.c2jac.report.json)",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            help="Path to a preprocessed .c/.i file (no #include/#define; run `gcc -E -P` first)"
        ),

    ],
    examples=[("jac c2jac myprogram.i", "Convert a preprocessed C file to Jac"), ],
    group="transform"
)
def c2jac(filename: str) -> int;

@registry.command(
    name="js",
    help="[Deprecated] Alias for 'jac2js'. Convert Jac code to JavaScript",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[
        ("jac js myprogram.jac", "Deprecated; prefer 'jac jac2js myprogram.jac'"),

    ],
    group="transform"
)
def js(filename: str) -> int;
