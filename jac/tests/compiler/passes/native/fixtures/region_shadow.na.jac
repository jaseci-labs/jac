"""A user archetype named Region shadows the builtin: constructing it must
build the user object, never intercept into arena setup."""

obj Region {
    has n: int = 0;
}

def shadowed -> int {
    r = Region(n=7);
    return r.n;
}
