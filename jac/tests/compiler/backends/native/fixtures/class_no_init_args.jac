"""A `class` with `has` fields and no initializer takes no arguments."""

class Plain {
    has b: int = 2;
}

with entry {
    p = Plain(b=5);
    print(p.b);
}
