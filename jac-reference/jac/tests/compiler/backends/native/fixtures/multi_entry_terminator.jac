"""Regression fixture for issue #6660: a terminating first `with entry` block.

When concatenating multiple `with entry` blocks into one `jac_entry`, the body
loop stops appending the moment a block leaves the current LLVM block
terminated (e.g. a top-level `raise`, which lowers to a call to
`__jac_exc_raise` followed by `unreachable`). This mirrors the Python target,
where a module-level `raise` propagates and the textually-later top-level code
never runs.

Here the first block prints a marker and then raises; the second block must
NOT run. The ELF test asserts the process exits non-zero (the uncaught raise
calls `abort()`) and that "SHOULD_NOT_RUN" never reaches stdout. Note: the
abort() path does not flush stdio, so the "BEFORE_RAISE" marker may or may not
appear — only the *absence* of the second block's output is asserted, which is
the invariant this fixture pins.
"""

with entry {
    print("BEFORE_RAISE");
    raise Exception("boom");
}

with entry {
    print("SHOULD_NOT_RUN");
}
