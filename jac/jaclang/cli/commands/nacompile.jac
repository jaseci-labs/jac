"""Native compile command: compile .na.jac files to standalone binaries.

Produces a runnable native executable from a .na.jac file using llvmlite's
code generator and a pure Python linker. No external compiler or linker
required. Supports ELF (Linux) and Mach-O (macOS) with automatic platform
detection. Includes ad-hoc code signing for arm64 macOS.
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Compile a .na.jac file to a standalone native binary."""
@registry.command(
    name="nacompile",
    help="Compile a .na.jac file to a standalone native binary",
    args=[
        Arg.create("filename", kind=ArgKind.POSITIONAL, help="Path to .na.jac file"),
        Arg.create(
            "output",
            kind=ArgKind.OPTION,
            short="o",
            default="",
            help="Output binary path (defaults to filename without extension)"
        ),

    ],
    examples=[
        ("jac nacompile program.na.jac", "Compile to ./program"),
        ("jac nacompile program.na.jac -o mybin", "Compile to ./mybin"),

    ],
    group="transform"
)
def nacompile(filename: str, output: str = "") -> int;
