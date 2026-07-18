import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

def py2jac(filename: str) -> int;

def jac2py(filename: str) -> int;

def jac2js(filename: str) -> int;

def jac2c(filename: str) -> int;

def c2jac(
    filename: str,
    incdir: list | None = None,
    define: list | None = None,
    undef: list | None = None,
    force_include: list | None = None,
    nostdinc: bool = False,
    strict_c: bool = False
) -> int;

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
