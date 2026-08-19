"""`hasattr` at module scope: no owning callable, so the module must refuse.

Reflection reads an attribute chosen at runtime. Native lowers `has` fields to
fixed struct offsets and keeps no name table beside them, so there is nothing
to reflect over. `print(hasattr(f, "x"))` used to lower to no call and no
argument at all -- the program printed a blank line where Python prints
`True`.
"""

obj Foo {
    has x: int = 1;
}


with entry {
    f = Foo();
    print(hasattr(f, "x"));
}
