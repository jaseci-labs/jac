"""Tests for typed-base enum syntax: `enum X: T { ... }`.

Verifies that the type checker treats members of `enum X: int { ... }` as
int instances (no .value needed), members of `enum X: str` as str
instances, and members of the mixin form `enum X: T` as T instances.
Plain `enum X { ... }` retains the prior behavior — its members are
NOT int and any attempt to use them where an int is expected is an error.
"""

import from enum { Enum }

# Typed: int-backed
enum Color: int {
    RED = 0,
    GREEN = 1,
    BLUE = 2
}

# Typed: str-backed
enum Tag: str {
    OPEN = "open",
    CLOSE = "close"
}

# Custom-mixin form. `Coord` doubles as the value type AND the parent
# class — members ARE Coord instances, accessible without `.value`.
class Coord {
    has x: int = 0;
}

enum Direction: Coord {
    NORTH = Coord(),
    SOUTH = Coord()
}

# Plain (no `: T`) — members are Enum, NOT int.
enum Plain {
    A = 1,
    B = 2
}

with entry {
    # OK: IntEnum members are int instances.
    ints: list[int] = [Color.RED, Color.GREEN, Color.BLUE];
    int_val: int = Color.RED;

    # OK: StrEnum members are str instances.
    strs: list[str] = [Tag.OPEN, Tag.CLOSE];
    str_val: str = Tag.OPEN;

    # OK: iteration variable resolves to the enum-instance type, so
    # .name (str) and .value (int / str / Coord) chain correctly.
    name_lower: str = Color.RED.name.lower();
    val_int: int = Color.RED.value;
    val_str: str = Tag.OPEN.value;

    # OK: comprehension over typed enum (regression for gap #52).
    type_names: list[str] = [c.name.lower() for c in Color];

    # ERROR: plain enum members are NOT int — must use .value.
    bad: list[int] = [Plain.A, Plain.B];
}
