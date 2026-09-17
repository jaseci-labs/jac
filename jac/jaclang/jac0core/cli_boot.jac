"""Launcher boot seam: the path existing jac binaries import at startup.

A built `jac` binary bakes `from jaclang.jac0core.cli_boot import
start_cli` into its boot source, so this import path is a frozen
contract with every launcher already in the field; it cannot move with
the source tree. The real module lives at `jaclang.cli.cli_boot`
(#8681); binaries built from this tree onward import that directly (see
`jaclang/dist/payload/assemble.jac`), and this seam serves launchers
built before the reorg. Both modules are seed-tier so the boot fast
paths (`jac --version`, `jac --help`) stay off the full compiler.
"""
import from jaclang.cli.cli_boot { start_cli }

glob __all__ = ["start_cli"];
