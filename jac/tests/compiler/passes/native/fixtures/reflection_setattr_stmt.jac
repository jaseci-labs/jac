"""`setattr` in statement position: the silent no-op.

An expression statement discards its value, so a reflection call that lowered
to nothing left no trace at all -- `setattr(f, "x", 5)` compiled clean, the
field kept its old value, and the program printed 1 where Python prints 5.

The call sits at module scope so the refusal is the module-wide one; the
body-scoped partition is pinned separately by `reflection_in_function.jac`.
"""

obj Foo {
    has x: int = 1;
}


with entry {
    f = Foo();
    setattr(f, "x", 5);
    print(f.x);
}
