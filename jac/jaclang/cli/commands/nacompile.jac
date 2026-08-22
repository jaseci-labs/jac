import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

@registry.command(
    name="nacompile",
    help="Compile a Jac file to a standalone native binary (prefer 'jac build --as native' for projects)",
    hidden=True,
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            help="Path to the .jac file to compile natively"
        ),
        Arg.create(
            "output",
            kind=ArgKind.OPTION,
            short="o",
            `default="",
            help="Output binary path (defaults to filename without extension)"
        ),
        Arg.create(
            "scrub",
            kind=ArgKind.FLAG,
            `default=False,
            help="Scrub build: wipe cached IR and recompile everything from scratch"
        ),
        Arg.create(
            "target",
            kind=ArgKind.OPTION,
            short="t",
            `default="",
            help="Code target: native host (default) or 'wasm32' for a browser .wasm module"
        ),
        Arg.create(
            "shared",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Build a C-ABI shared library (.so/.dylib/.dll) exporting `:pub` symbols instead of an executable"
        ),
        Arg.create(
            "debug",
            kind=ArgKind.FLAG,
            `default=False,
            short="g",
            help="Emit DWARF debug info + symbol table so the binary is debuggable with gdb/lldb"
        ),
        Arg.create(
            "gc",
            kind=ArgKind.OPTION,
            short="",
            `default="",
            help="Memory-management runtime to emit: 'cycles' (refcounting + cycle collector), 'rc' (refcounting only, no collector code), or 'none' (no refcounting call sites; memory is never reclaimed). Defaults to jac.toml [gc] default, else 'cycles'"
        ),
        Arg.create(
            "assert-no-rc",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Fail the build if the emitted IR contains any RC/collector machinery: __rc_* helpers, trace functions, roots-buffer globals, or entry-point GC env probes"
        ),
        Arg.create(
            "enforce-nogc",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Enforce zero-RC ownership coverage (E140x hard errors) on the compiled module, regardless of jac.toml [gc.enforce] patterns"
        ),
        Arg.create(
            "strict",
            kind=ArgKind.FLAG,
            `default=False,
            short="",
            help="Fail when any function in the program's native closure was demoted to Python-only (a demoted function cannot run in a self-contained binary); JAC_NA_DEBUG=1 prints why"
        ),

    ],
    examples=[
        ("jac nacompile program.jac", "Compile to ./program"),
        ("jac nacompile program.jac", "Auto-promote and compile to ./program"),
        ("jac nacompile program.jac -o mybin", "Compile to ./mybin"),
        ("jac nacompile program.jac --scrub", "Clean rebuild (wipe IR cache)"),
        (
            "jac nacompile program.jac -g",
            "Compile with DWARF debug info (gdb ./program works)"
        ),
        (
            "jac nacompile game.jac --target wasm32 -o game.wasm",
            "Compile to a wasm module"
        ),
        (
            "jac nacompile mathlib.jac --shared",
            "Build ./libmathlib.so exporting its `:pub` functions over the C ABI"
        ),
        (
            "jac nacompile service.jac --gc none --assert-no-rc",
            "Compile and prove the artifact contains no RC/collector machinery"
        ),
        (
            "jac nacompile launcher.jac --strict",
            "Compile and refuse any Python-only demotion in the native closure"
        ),

    ],
    group="transform"
)
def nacompile(
    filename: str,
    output: str = "",
    scrub: bool = False,
    target: str = "",
    shared: bool = False,
    debug: bool = False,
    gc: str = "",
    assert_no_rc: bool = False,
    enforce_nogc: bool = False,
    strict: bool = False
) -> int;
