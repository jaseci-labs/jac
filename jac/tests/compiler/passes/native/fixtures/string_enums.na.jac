# Test fixture for string-valued enum support

enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

enum Direction {
    NORTH = "N",
    SOUTH = "S",
    EAST = "E",
    WEST = "W"
}

# Integer enum still works
enum Priority {
    LOW = 0,
    MEDIUM = 1,
    HIGH = 2
}

def color_ordinal_red() -> int {
    return Color.RED;
}

def color_ordinal_blue() -> int {
    return Color.BLUE;
}

def color_cmp(c: int) -> int {
    if c == Color.RED {
        return 10;
    } elif c == Color.GREEN {
        return 20;
    } elif c == Color.BLUE {
        return 30;
    }
    return 0;
}

def color_value(c: Color) -> str {
    return c.value;
}

def color_name(c: Color) -> str {
    return c.name;
}

def direction_value(d: Direction) -> str {
    return d.value;
}

def int_enum_still_works() -> int {
    return Priority.HIGH;
}

with entry {
    _x: int = 1;
}
