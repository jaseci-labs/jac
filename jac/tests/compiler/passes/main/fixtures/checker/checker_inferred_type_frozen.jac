"""Strict inferred-local typing.

An unannotated local variable is *frozen* to the type inferred at its
first binding. Reassigning a value of an incompatible type is a type
error (E1001) — exactly as if the inferred type had been written out as
an explicit annotation.

The one exception is the `None`-sentinel pattern (`x = None; ...; x = v`):
when the first binding infers `NoneType`, the variable's type is allowed
to evolve, matching TypeScript's strict-mode evolving locals.
"""

with entry {
    # Frozen to `int` by the first binding — reassigning a `str` is an error.
    a = 90;
    a = "some str";  # <-- Error

    # Reassignment within the frozen type is fine.
    b = 1;
    b = 2;  # <-- Ok

    # None-sentinel: the inferred type evolves, so reassignment is allowed.
    found = None;
    found = 42;  # <-- Ok
}
