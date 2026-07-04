import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="py2jac",
    help="Convert Python code to Jac",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .py file"), ],
    examples=[("jac py2jac script.py", "Convert a Python file to Jac"), ],
    group="transform"
)
def py2jac(filename: str) -> int;

@registry.command(
    name="jac2py",
    help="Convert Jac code to Python",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2py myprogram.jac", "Convert a Jac file to Python"), ],
    group="transform"
)
def jac2py(filename: str) -> int;

@registry.command(
    name="jac2js",
    help="Convert Jac code to JavaScript",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2js myprogram.jac", "Convert a Jac file to JavaScript"), ],
    group="transform"
)
def jac2js(filename: str) -> int;

@registry.command(
    name="jac2c",
    help="Convert Jac code to C source",
    args=[Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .jac file"), ],
    examples=[("jac jac2c myprogram.jac", "Convert a Jac file to C"), ],
    group="transform"
)
def jac2c(filename: str) -> int;

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
        Arg.create(
            "strict-c",
            kind=ArgKind.FLAG,
            help="Treat every best-effort/unfaithful lowering as an error (exit non-zero) instead of a warning"
        ),

    ],
    examples=[
        ("jac c2jac myprogram.i", "Convert an already-preprocessed C file to Jac"),
        ("jac c2jac lib.c -I include -DDEBUG=1", "Preprocess (pcpp) then convert"),
        (
            "jac c2jac lib.i --strict-c",
            "Fail if any construct cannot be lifted faithfully"
        ),

    ],
    group="transform"
)
def c2jac(
    filename: str,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False,
    strict_c: bool = False
) -> int;

@registry.command(
    name="cbindgen",
    help="Generate a .na.jac FFI binding (import-from clib block) from a C header",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            help="Path to a C header/source (.h/.c, preprocessed with pcpp) or a preprocessed .i file"
        ),
        Arg.create(
            "lib",
            kind=ArgKind.OPTION,
            help="Target shared library: a logical name (z, crypto), a dotted name (libs.foo), or an explicit path"
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
        Arg.create(
            "allow",
            kind=ArgKind.APPEND,
            help="Only bind these symbols (comma-separated or repeatable allowlist)"
        ),
        Arg.create(
            "block",
            kind=ArgKind.APPEND,
            help="Never bind these symbols (comma-separated or repeatable blocklist)"
        ),
        Arg.create(
            "output",
            kind=ArgKind.OPTION,
            short="o",
            help="Write the generated .na.jac here instead of stdout"
        ),

    ],
    examples=[
        (
            "jac cbindgen zlib.h --lib z -I /usr/include",
            "Bind libz externs from a system header"
        ),
        (
            "jac cbindgen api.h --lib mylib --allow foo,bar",
            "Bind only the allowlisted symbols"
        ),

    ],
    group="transform"
)
def cbindgen(
    filename: str,
    lib: str | None = None,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False,
    allow: list | None = None,
    block: list | None = None,
    output: str | None = None
) -> int;

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
