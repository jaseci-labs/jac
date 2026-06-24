"""Native compile command: compile .na.jac files to standalone binaries.

Produces a runnable native executable from a .na.jac file using the in-tree
code generator and a pure Python linker. No external compiler or linker
required. Supports ELF (Linux) and Mach-O (macOS) with automatic platform
detection. Includes ad-hoc code signing for arm64 macOS.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Compile a .jac or .na.jac file to a standalone native binary."""
@registry.command(
    name="nacompile",
    help="Compile a Jac file to a standalone native binary",
    args=[
        Arg.create(
            "filename", kind=ArgKind.POSITIONAL, help="Path to .jac or .na.jac file"
        ),
        Arg.create(
            "output",
            kind=ArgKind.OPTION,
            short="o",
            default="",
            help="Output binary path (defaults to filename without extension)"
        ),
        Arg.create(
            "scrub",
            kind=ArgKind.FLAG,
            help="Scrub build: wipe cached IR and recompile everything from scratch"
        ),
        Arg.create(
            "target",
            kind=ArgKind.OPTION,
            short="t",
            default="",
            help="Code target: native host (default) or 'wasm32' for a browser .wasm module"
        ),
        Arg.create(
            "shared",
            kind=ArgKind.FLAG,
            short="",  # suppress auto `-s` (taken by --scrub); long form only
            help="Build a C-ABI shared library (.so/.dylib/.dll) exporting `:pub` symbols instead of an executable"
        ),
        Arg.create(
            "debug",
            kind=ArgKind.FLAG,
            short="g",  # conventional `-g`, mirrors cc/clang
            help="Emit DWARF debug info + symbol table so the binary is debuggable with gdb/lldb"
        ),

    ],
    examples=[
        ("jac nacompile program.na.jac", "Compile to ./program"),
        ("jac nacompile program.jac", "Auto-promote and compile to ./program"),
        ("jac nacompile program.na.jac -o mybin", "Compile to ./mybin"),
        ("jac nacompile program.na.jac --scrub", "Clean rebuild (wipe IR cache)"),
        (
            "jac nacompile program.na.jac -g",
            "Compile with DWARF debug info (gdb ./program works)"
        ),
        (
            "jac nacompile game.na.jac --target wasm32 -o game.wasm",
            "Compile to a wasm module"
        ),
        (
            "jac nacompile mathlib.na.jac --shared",
            "Build ./libmathlib.so exporting its `:pub` functions over the C ABI"
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
    debug: bool = False
) -> int;
