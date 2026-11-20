"""Fixture: the same builtin name in a genuine reference slot.

The twin of `kwarg_key_builtin.jac`: here `store` really is read from scope,
so the module-level import has to appear. Without this pair a guard that
suppressed the import everywhere would read as a pass.
"""

def keeper -> object {
    return store;
}
