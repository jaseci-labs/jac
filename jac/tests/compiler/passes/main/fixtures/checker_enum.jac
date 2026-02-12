"""Tests for enum type checking."""

# Basic enum definition
enum Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3
}

# Enum with string values
enum Status {
    PENDING = "pending",
    ACTIVE = "active",
    COMPLETED = "completed"
}

# Enum with mixed implicit/explicit values
enum Priority {
    LOW,
    MEDIUM,
    HIGH
}

# Simple enum without methods (jaclang enums use impl blocks for methods)
enum Direction {
    NORTH = 0,
    SOUTH = 1,
    EAST = 2,
    WEST = 3
}

with entry {
    # Basic enum member access
    c: Color = Color.RED;

    # Enum member .name access - should be str
    name_ok: str = Color.RED.name;
    name_err: int = Color.RED.name;  # <-- Error: str assigned to int

    # Enum member ._name_ access - should be str
    name2_ok: str = Color.GREEN._name_;
    name2_err: int = Color.GREEN._name_;  # <-- Error: str assigned to int

    # Enum member .value access - should be int (default for Color)
    value_ok: int = Color.BLUE.value;
    value_err: str = Color.BLUE.value;  # <-- Error: int assigned to str

    # Enum member ._value_ access - should be int
    value2_ok: int = Color.RED._value_;
    value2_err: str = Color.RED._value_;  # <-- Error: int assigned to str

    # String enum value access
    status_val: str = Status.PENDING.value;
    status_val_err: int = Status.ACTIVE.value;  # <-- Error: str assigned to int

    # Assigning enum member to enum type variable
    my_color: Color = Color.GREEN;  # <-- Ok

    # Assigning wrong enum type should still work due to duck typing
    # (we're not implementing strict cross-enum checks yet)

    # Chained enum member access (Color.RED.GREEN)
    # Note: This feature requires additional work for proper EnumMemberType -> EnumMemberType chaining
    # chained: Color = Color.RED.GREEN;  # <-- Ok (chained access)
    # chained_name: str = Color.RED.BLUE.name;  # <-- Ok

    # Enum subscript access
    # Note: Subscript access has a known issue with instance/class type matching
    # subscript_color: Color = Color["RED"];  # <-- Ok

    # Direction enum access
    dir: Direction = Direction.NORTH;
    dir_val: int = dir.value;  # <-- Ok
}

# Test function with enum parameter
def process_color(c: Color) -> str {
    return c.name;
}

# Test function returning enum member
def get_default_color -> Color {
    return Color.RED;
}

with entry {
    # Test function calls with enums
    result: str = process_color(Color.BLUE);  # <-- Ok
    default_color: Color = get_default_color();  # <-- Ok

    # Error case: wrong type passed to function expecting enum
    wrong_type: str = process_color("not a color");  # <-- Error: str not Color
}
