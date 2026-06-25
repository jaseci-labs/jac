"""Regression fixture for issue #6660: two module-level `with entry` blocks.

The native backend used to emit one `jac_entry` function per `with entry`
block, so a second block re-registered the name and crashed IR generation with
`llvmlite.ir._utils.DuplicatedNameError: jac_entry`. The Python target
concatenates all module-level `with entry` blocks in source order into a single
execution sequence; the native target must do the same.

Both blocks are concatenated, in source order, into one `jac_entry`. Output is
exactly "FIRST SECOND" (print emits no trailing newline). The block ordering is
what the ELF test asserts — "FIRST" must appear before "SECOND".
"""

with entry {
    print("FIRST ");
}

with entry {
    print("SECOND");
}
