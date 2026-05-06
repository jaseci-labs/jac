"""Runtime smoke test for typed-base enum syntax.

`enum X: int { ... }` desugars to `class X(IntEnum)`, `enum X: str`
to `class X(StrEnum)`, and `enum X: T { ... }` for custom T uses
Python's mixin pattern `class X(T, Enum)`.
"""

enum Color: int {
    RED = 0,
    GREEN = 1,
    BLUE = 2
}

enum Tag: str {
    OPEN = "open",
    CLOSE = "close"
}

class Box {
    has size: int = 0;
}

enum Crate: Box {
    SMALL = Box(),
    LARGE = Box()
}

enum Plain {
    FIRST = 1,
    SECOND = 2
}

with entry {
    print("int_member:", Color.RED == 0, isinstance(Color.RED, int), int(Color.RED));
    print("str_member:", Tag.OPEN == "open", isinstance(Tag.OPEN, str));
    print("mixin_member:", isinstance(Crate.SMALL, Box));
    print("plain_keeps_old:", Plain.FIRST == 1, isinstance(Plain.FIRST, int));
    # Iteration over typed enum (regression cover for gap #52).
    print("color_names:", [c.name for c in Color]);
    print("tag_values:", [t.value for t in Tag]);
}
