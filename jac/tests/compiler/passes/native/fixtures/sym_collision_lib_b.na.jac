"""Fixture module B for symbol-collision detection regression test.

Both sym_collision_lib_a.na.jac and sym_collision_lib_b.na.jac define a
function named `collision_fn` with external linkage.  When
sym_collision_entry.na.jac imports from both, the native compiler must
detect the LLVM-level collision before calling link_in() and emit E5026
instead of silently producing a binary that crashes with SIGSEGV at runtime.
"""

"""Unique entry point for lib_b."""
def:pub fn_b() -> int {
    return 2;
}

"""This function collides with the same-named one in sym_collision_lib_a."""
def:pub collision_fn() -> int {
    return 222;
}
