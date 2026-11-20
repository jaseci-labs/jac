"""Test that static methods on enum classes resolve correctly."""
import from enum { Enum, IntEnum }

class Color(Enum) {
    with entry {
        RED = 1;
        GREEN = 2;
    }

    static def from_int(val: int) -> int {
        return val;
    }
}

class Priority(IntEnum) {
    with entry {
        LOW = 0;
        HIGH = 1;
    }

    static def default_level() -> int {
        return 0;
    }
}

def test_enum_static_methods() -> int {
    x: int = Color.from_int(1);
    y: int = Priority.default_level();
    return x + y;
}
