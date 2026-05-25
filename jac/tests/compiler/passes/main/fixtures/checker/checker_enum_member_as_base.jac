"""Typed-base enum members are assignable to that base type.

`enum Color: int { RED = 1 }` — members ARE int instances. Returning /
passing them where the base type is expected must typecheck without
manually unwrapping via `.value`. Plain `enum X { ... }` (no typed
base) keeps the stricter behavior; see checker_enum_typed_base.jac.
"""

enum Color: int {
    RED = 1,
    GREEN = 2,
    BLUE = 3
}

enum Tag: str {
    ALPHA = "a",
    BETA = "b"
}

def ordinal_red() -> int {
    return Color.RED;
}

def ordinal_blue() -> int {
    return Color.BLUE;
}

def label_alpha() -> str {
    return Tag.ALPHA;
}

def assign_int_locally() -> int {
    x: int = Color.GREEN;
    return x;
}

def pass_int(v: int) -> int {
    return v;
}

def use_int_param() -> int {
    return pass_int(Color.RED);
}
