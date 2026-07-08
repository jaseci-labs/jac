import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

def py2jac(filename: str) -> int;

def jac2py(filename: str) -> int;

def jac2js(filename: str) -> int;

@registry.command(
    name="c2jac",
    help="Convert C code to Jac (writes Jac to stdout; best-effort sites are flagged inline in the output)",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            help="Path to a .c source (preprocessed with pcpp) or an already-preprocessed .i file"
        ),
        Arg.create(
            "incdir",
            kind=ArgKind.APPEND,
            short="I",
            help="Add a directory to the #include search path (repeatable)"
        ),
        Arg.create(
            "define",
            kind=ArgKind.APPEND,
            short="D",
            help="Define a macro, NAME or NAME=VALUE (repeatable)"
        ),
        Arg.create(
            "undef",
            kind=ArgKind.APPEND,
            short="U",
            help="Undefine a macro NAME (repeatable)"
        ),
        Arg.create(
            "force-include",
            kind=ArgKind.APPEND,
            help="Force-include a header before the main source (gcc -include; repeatable)"
        ),
        Arg.create(
            "nostdinc",
            kind=ArgKind.FLAG,
            help="Do not add pycparser's bundled fake libc headers to the include path"
        ),

    ],
    examples=[
        ("jac c2jac myprogram.i", "Convert an already-preprocessed C file to Jac"),
        ("jac c2jac lib.c -I include -DDEBUG=1", "Preprocess (pcpp) then convert"),

    ],
    group="transform"
)
def c2jac(
    filename: str,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False
) -> int;
