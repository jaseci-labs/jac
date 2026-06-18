"""isinstance over a tuple mixing a supported type with an unsupported one.

`int` resolves to a JacVal tag but `Foo` (a user archetype) has no native tag.
The whole call must raise a structured error rather than silently dropping the
`Foo` arm and emitting a check for `int` only (review of #6421).
"""

obj Foo {
    has v: int;
}

def chk(x: any) -> int {
    if isinstance(x, (int, Foo)) {
        return 1;
    }
    return 0;
}
